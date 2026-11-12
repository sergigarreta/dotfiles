#!/bin/bash
# Usage: heal.sh <repo> <roots-file>; restores objects missing under the roots from GitHub.
set -u
R=$1; ROOTS=$(cat "$2")
T=$(mktemp -d)/rescue.git
git init -q --bare "$T"
for round in $(seq 1 20); do
  miss=$(GIT_NO_LAZY_FETCH=1 git -C "$R" rev-list --objects --no-object-names --missing=print $ROOTS | sed -n 's/^?//p' | sort -u)
  n=$(echo -n "$miss" | grep -c . || true)
  echo "round $round: $n missing"
  [ "$n" -eq 0 ] && { rm -rf "$(dirname "$T")"; exit 0; }
  GIT_NO_LAZY_FETCH=1 git -C "$T" fetch -q --no-tags --filter=tree:0 https://github.com/roverdotcom/web $miss || \
    GIT_NO_LAZY_FETCH=1 git -C "$T" fetch -q --no-tags https://github.com/roverdotcom/web $miss
  for s in $miss; do
    t=$(GIT_NO_LAZY_FETCH=1 git -C "$T" cat-file -t "$s" 2>/dev/null) || { echo "not fetched $s"; continue; }
    w=$(GIT_NO_LAZY_FETCH=1 git -C "$T" cat-file "$t" "$s" | git -C "$R" hash-object -t "$t" -w --stdin)
    [ "$w" = "$s" ] || echo "BAD $s"
  done
done
echo "gave up after 20 rounds"; exit 1
