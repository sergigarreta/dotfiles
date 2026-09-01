---
name: rover-fixture-create
description: "Creates a Rover dev-fixture user on a staging or local environment and returns a Create link plus an admin impersonation link. Use whenever someone asks to create a fixture, set up a test user, or get a fixture link for a scenario (\"US user in Alaska on staging-qa-testing\", \"Switzerland requester, no credit card\")."
allowed-tools: Bash(python3:*)
---

# rover-fixture-create

`scripts/create_fixture.py` does the whole flow in one call: builds the SPA **Create**
URL, POSTs the fixture to the API, resolves the created person's PK and prints the
admin impersonation link. It never prints the API response — that body embeds API keys
and JWTs for every created person. Run it from anywhere inside the `web` repo checkout
(it locates the serializer file relative to `$CLAUDE_PROJECT_DIR` or the cwd).

## Step 1 — Gather inputs

- **Scenario**: requester country (ISO-2), city, region/state code, postal code, plus
  any other option the user asks for.
- **Environment**: pass it straight through as `--base-url` — `staging-qa-testing`,
  `staging-<name>`, `local`, or a full URL. The script resolves it.

## Step 2 — Create the fixture

```bash
python3 ~/.claude/skills/rover-fixture-create/scripts/create_fixture.py \
  --base-url staging-qa-testing \
  --requester-country US --requester-city Auburn \
  --requester-region WA --requester-postal-code 98001
```

- Options beyond the CLI flags: `--extra '{"bookingStatus":"completed"}'` (camelCase).
- Several fixtures at once: repeatable `--scenario '{"label":"AK","requesterRegion":"AK"}'`
  — POSTed concurrently, one command. Do not loop.
- `--url-only` skips creation and prints the Create link only.

Output is already in the shape the user needs — Create link, admin link, person PK per
scenario. Paste it, do not re-derive it. A non-zero exit means the POST failed: report
the one-line reason and hand over the Create link alone.

## Step 3 — Fields and defaults (only when needed)

The script already fills every field the SPA form needs. Look further **only** when the
user asks for an option that has no CLI flag:

```bash
python3 ~/.claude/skills/rover-fixture-create/scripts/create_fixture.py \
  --list-fields requester   # provider | requester | booking | standard | applicant
```

That prints a compact `camelName type default choices` table parsed from
`src/aplaceforrover/fixtures/standard_options.py`. Prefer it over reading the file; read
`standard_options.py` only if you need a field's `help_text`.

If the generated links behave oddly, run `--check-defaults` — it reports drift between
the script's baked-in defaults and the serializer.

## Step 4 — Expected feature logic (only if asked)

If — and only if — the user names a feature or asks what should show/hide for the
scenario, delegate the trace to an `Explore` subagent ("find the gating conditions for
<feature>, answer in 5 lines or fewer") and add one line to the output. Never read
gating code in the main thread, and never ask the user to pick a feature when they only
asked for a link.

Example — Promo Carousel: Lemonade needs `requesterCountry == "US"` and a state outside
`LEMONADE_UNAVAILABLE_STATES` (`insurance/utils.py`); Ambassador needs
`supports_referral` for the country (`i18n/configuration.py`); logic in
`user_home/api/services/promo.py`.

## Notes

- The fixture API needs no auth on staging; admin links and impersonation need staff
  login, which QA teams have.
- The Create link and the API POST create **separate** users.
- Admin links use the integer PK (`?id=<pk>`), never opk or slug.
