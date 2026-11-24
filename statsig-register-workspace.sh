#!/bin/bash

# Adds this machine's name to the Statsig segment sergi_garreta_codespaces, so
# gates targeted at that segment pass here. The backend sends settings.MACHINE_NAME
# (systems/statsig/utils.py) as the `environment_id` custom ID; lib/env.sh
# resolves the same value.
#
# Auth needs the SERGI_STATSIG_CONSOLE_API_KEY secret (a Console API key
# with write access). It can edit the whole Statsig project, so it is only ever
# read into a curl header through process substitution: never echoed, logged,
# put on a command line, or written to a file.
#
# Exits 0 on every failure so it cannot break codespace creation.

set -uo pipefail

. "$(dirname "$0")/lib/env.sh"

SEGMENT=sergi_garreta_codespaces
URL="https://statsigapi.net/console/v1/segments/$SEGMENT"

if [ -z "$MACHINE_ID" ]; then
  echo "No MACHINE_NAME — skipping Statsig segment registration." >&2
  exit 0
fi
if [ -z "${SERGI_STATSIG_CONSOLE_API_KEY:-}" ]; then
  echo "SERGI_STATSIG_CONSOLE_API_KEY not set — skipping Statsig segment registration. Add it as a Coder secret (coder secret create) and restart." >&2
  exit 0
fi

statsig() {
  curl -fsS --max-time 20 \
    -H @<(printf 'STATSIG-API-KEY: %s\n' "$SERGI_STATSIG_CONSOLE_API_KEY") \
    -H 'STATSIG-API-VERSION: 20240601' \
    -H 'Content-Type: application/json' \
    "$@"
}

if ! segment=$(statsig "$URL"); then
  echo "Could not read Statsig segment $SEGMENT — not registered." >&2
  exit 0
fi

if jq -e --arg name "$MACHINE_ID" \
  '[.data.rules[].conditions[] | select(.customID == "environment_id") | .targetValue[]] | index($name)' \
  <<<"$segment" >/dev/null; then
  echo "$MACHINE_ID already present in Statsig segment $SEGMENT."
  exit 0
fi

# The endpoint replaces the whole rules array, so send every rule back and only
# append to the first environment_id condition.
rules=$(jq --arg name "$MACHINE_ID" '
  .data.rules
  | ([paths(objects | select(.customID == "environment_id"))][0]) as $p
  | if $p == null then error("no environment_id condition") else setpath($p + ["targetValue"]; getpath($p).targetValue + [$name]) end
' <<<"$segment") || {
  echo "Statsig segment $SEGMENT has no environment_id condition — not registered." >&2
  exit 0
}

if statsig -X POST "$URL/conditional" --data-binary "$rules" >/dev/null; then
  echo "Added $MACHINE_ID to Statsig segment $SEGMENT."
else
  echo "Could not update Statsig segment $SEGMENT — not registered." >&2
fi
exit 0
