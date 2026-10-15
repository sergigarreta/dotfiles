---
name: statsig-key-usage
description: "Rules for any use of a Statsig Console API key or the Statsig write API: SERGI_STATSIG_CONSOLE_API_KEY, the web app's STATSIG_CONSOLE_API_KEY (snagsby), STATSIG_CONSOLE_KEY, any request to statsigapi.net/console, StatsigOverrideClient / StatsigTestClient, `m dev_statsig_admin`, bin/create_statsig_flag.sh, or gateway Statsig MCP write tools. The keys are for testing only: overrides and segment IDs on development and staging. Never production, never creating or editing gates/experiments/configs/rules, never starting, launching, shipping or ending an experiment. Load before writing, running or suggesting any such call."
---

# Statsig Console keys: testing only

A Statsig Console API key with write access can change the whole project,
production included, so the limits below keep a test helper from changing what
real users see. They apply to every Statsig key and every path to the Console
API, not just the codespace segment script.

## Allowed

Only on the **development** and **staging** tiers:

- Any `GET` (reading gates, experiments, configs, segments, overrides).
- Gate overrides: `PATCH` / `DELETE gates/{id}/overrides` with
  `environmentOverrides` entries whose `environment` is `development` or
  `staging`. Top-level `passingUserIDs` / `failingUserIDs` apply to **every
  environment, production included**, so never send them.
- Experiment overrides: `PATCH` / `DELETE experiments/{id}/overrides` with
  `userIDOverrides` entries whose `environment` is `development` or `staging`.
  A missing or `null` `environment` means all environments, so never omit it.
- Adding or removing IDs in an ID-list segment used for testing
  (`segments/{id}/id_list`).
- `statsig-register-codespace.sh`: appending a value to the existing
  `environment_id` condition of `sergi_garreta_codespaces`. Its rule is
  development-only. Do not change the rule's structure, environments or pass
  percentage.

Prefer the web app's `StatsigOverrideClient`, which rejects non-prod tiers in
`resolve_non_prod_environment_tier`, over a hand-written `curl`.

## Never

- Anything that targets or could reach **production**, including an override
  without an explicit non-prod `environment`.
- Creating, updating or deleting gates, experiments, layers, dynamic configs,
  holdouts, metrics, param stores, segments or keys (`POST gates`,
  `POST experiments`, `PATCH gates/{id}`, `.../rules`, `DELETE gates/{id}` and
  so on). This includes `bin/create_statsig_flag.sh`.
- Writing or editing rules, targeting conditions, pass percentages or allocation
  on any gate, experiment, config or segment (other than the
  `sergi_garreta_codespaces` append above).
- Starting, launching, restarting, shipping, making a decision on, abandoning
  or resetting an experiment; enabling, disabling or launching a gate.

If a task needs any of these, stop and tell the user it has to be done in the
Statsig Console by someone who owns the experiment. Do not look for another
endpoint, key or tool that would do it.

## Before every write call

1. The method and path are on the allowed list.
2. Every override entry names `environment: "development"` or `"staging"`.
3. The call does not create an entity or replace a rules array.
4. Ask the user first unless they asked for this exact override or segment
   change. Read-only `GET`s also need the user's go-ahead before running with a
   key: say which endpoints and why.

## Handling the keys

Never print, echo, log, `env`-dump or interpolate a key into a command line,
URL or file. Check presence with an emptiness test only
(`[ -n "${VAR:-}" ] && echo present`), and pass it to `curl` through process
substitution, as `statsig-register-codespace.sh` does.
