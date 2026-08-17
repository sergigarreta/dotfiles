# Bug triage — priority, SLA, sprint placement

Read this when the ticket you're filing is a `Bug`. It covers everything beyond the basic shape: how to choose a priority, what `duedate` materializes as, how to propose a sprint, and what to surface to the user after creation. Source of truth: [Bug Triage Priority and Severity Definitions, & SLAs](https://roverdotcom.atlassian.net/wiki/spaces/TECH/pages/300843041/Bug+Triage+Priority+and+Severity+Definitions+SLAs).

## Contents

- Priority and SLA table
- Inferring priority from a bug description
- The `duedate` field (how it materializes, worked examples, backstop)
- Proposing a sprint (algorithm + worked example)
- Closing the loop with the user

## Priority and SLA

| Priority   | Web SLA        | Mobile SLA               | When to use                                                                                                                       |
| ---------- | -------------- | ------------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| `Blocker`  | **3 days**     | Before release           | Customer-impacting (or imminently so) in a core workflow. Stays mis-priced, payouts failing, etc. Someone must be actively on it. |
| `Critical` | **7 days**     | Next release             | Degrading customer/internal experience. On-call pages, high CX-contact issues, blocking issues in non-core flows.                 |
| `Major`    | **14 days**    | Next two releases        | Isolated customer-impacting issues with workarounds. Limited-scope Sentry 5xx, flaky tests, non-blocking issues in non-core flow. |
| `Minor`    | **28 days**    | (rolls up with priority) | "Looks not right but works": typos, layout oddities, prod/dev parity that doesn't block testing.                                  |
| `Trivial`  | As prioritized | As prioritized           | Only frequent users would notice. Behind dev menus, non-blocking polish.                                                          |

Valid values for the `priority` field: `Blocker`, `Critical`, `Major`, `Minor`, `Trivial`. Don't create a bug without one.

## Inferring priority

When the user describes the bug clearly, propose a priority *before* asking — they can override. Heuristics:

- Paid workflow broken (booking, payout, stay creation)? → `Blocker`.
- On-call paging, or CX seeing a flood of contacts? → `Critical`.
- Scoped to a specific user state with a workaround? → `Major`.
- Cosmetic / copy / dev-parity? → `Minor` or `Trivial`.

Phrase it so the user can override cheaply: *"This looks like a `Major` to me because the symptom is scoped to merged CIAF sitters with a workaround (full list visible on tap). Want a different priority?"*

## The `duedate` field — SLA value

The bug SLA materializes as the system `duedate` field (ISO date string, e.g., `"2026-06-02"`). Jira automation sets it when the priority is set on the ticket: spot-checks of recent DEV bugs all show `duedate ≈ created_date + SLA-days for the chosen priority`.

Worked examples (all `priority: Major`, SLA 14 days):

| Ticket                                                            | Created    | `duedate`    |
| ----------------------------------------------------------------- | ---------- | ------------ |
| [DEV-148890](https://roverdotcom.atlassian.net/browse/DEV-148890) | 2026-05-19 | `2026-06-02` |
| [DEV-148887](https://roverdotcom.atlassian.net/browse/DEV-148887) | 2026-05-19 | `2026-06-02` |
| [DEV-148847](https://roverdotcom.atlassian.net/browse/DEV-148847) | 2026-05-18 | `2026-06-01` |
| [DEV-148846](https://roverdotcom.atlassian.net/browse/DEV-148846) | 2026-05-18 | `2026-06-01` |
| [DEV-148844](https://roverdotcom.atlassian.net/browse/DEV-148844) | 2026-05-18 | `2026-06-01` |

After creating a bug, **read the ticket back with `getJiraIssue`** and surface the `duedate` value — don't trust the input you sent. If automation skipped it (priority wasn't accepted, etc.), set it explicitly via `editJiraIssue` with `fields: {"duedate": "YYYY-MM-DD"}`, computed as `created + SLA-days`.

## Proposing a sprint

The triage doc requires every non-trivial bug to live in a sprint to meet its SLA. The bot won't add it; you can save a round-trip by naming the right one.

**Sprint shape.** Owner Retention sprints (board id `5`) live on tickets in `customfield_10007` as a list of sprint objects with `id`, `name`, `state` (`closed` / `active` / `future`), `startDate`, `endDate`. Cadence is **exactly 14 days, every other Wednesday**. Name format: `Sprint YY-MM-DD` where the date is the Wednesday start (e.g., `Sprint 26-05-27` runs 2026-05-27 → 2026-06-10). `startDate` in the API may be expressed in UTC so the day-of-week can look off — trust the **name** as the source of truth for the start date.

**Selection algorithm:**

1. Find candidate sprints by searching recent Owner Retention tickets with `customfield_10007` populated. Note each sprint's `name`, `state`, `startDate`, `endDate`.
2. Filter to sprints with `state` in (`active`, `future`). Never propose a `closed` sprint.
3. Pick the **latest** sprint whose `endDate` is on or before the bug's SLA `duedate`. That gives the team the full sprint window to land the fix.
4. If no `active`/`future` sprint satisfies that constraint (typical for short SLAs — Blocker = 3 days, Critical = 7 days), fall back to the **active** sprint and say so plainly.
5. Never roll forward into a sprint that ends after the SLA, or back into a closed sprint.

**What to tell the user.** Report the proposed sprint name and the number of days from its start to the SLA, so the user can see whether the placement is comfortable or tight. Be explicit that **you have not moved the bug** — they need to do it.

**Worked example.** Bug created today as `Major` with `duedate = 2026-06-02`. Active sprint is `Sprint 26-05-13` (May 13 → May 27). Next is `Sprint 26-05-27` (May 27 → June 10).

- `Sprint 26-05-13` ends May 27 ≤ June 2 ✓ — qualifies.
- `Sprint 26-05-27` ends June 10 > June 2 ✗ — disqualifies.
- Latest qualifying = `Sprint 26-05-13` (active). Propose it.

Phrase it like:

> "Created [DEV-XXXXX](https://roverdotcom.atlassian.net/browse/DEV-XXXXX) as `Major` with SLA `2026-06-02` (duedate). I'd propose adding it to **Sprint 26-05-13** (active) — 20 days from sprint start to SLA, and the sprint ends 6 days before the SLA hits. The triage policy requires non-trivial bugs to live in a sprint to meet their SLA; you'll need to drop it in manually since the bot won't auto-add it."

If you fell back to the active sprint because nothing qualified: *"Blocker SLA is 3 days out, so no upcoming sprint completes before the SLA. The only valid placement is the active sprint, Sprint 26-05-13."*

## Closing the loop with the user

After creating a bug, always surface:

1. **Issue key and URL.**
2. **Chosen priority and resulting SLA date (`duedate`)** — re-read via `getJiraIssue`; don't trust the input.
3. **Proposed sprint** plus the reminder that placing it is a manual step.
