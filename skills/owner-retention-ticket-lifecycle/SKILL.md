---
name: owner-retention-ticket-lifecycle
description: Keep a DEV Jira ticket's assignee and status in sync with the work actually happening. Use when starting work on a ticket or branch, when opening or marking a PR ready for review, or when the user asks to assign, pick up, start, park, or move a ticket. Also fires implicitly — assign and Start Progress on the first real edit for a ticket, and move to In Code Review when a PR goes up.
---

# Owner Retention Ticket Lifecycle

Move a `DEV` ticket through the workflow so its board state matches reality, without the user having to remember. Assigning and transitioning only — for writing ticket content use `owner-retention-ticket-create`.

## The two moments that matter

| Moment | Action |
| ------ | ------ |
| **Work starts** — you make the first substantive edit for a ticket, or check out / create its branch | Assign to the user, transition to **In Progress** |
| **PR ready for review** — a non-draft PR exists for the branch, or a draft is marked ready | Transition to **In Code Review** (status becomes `Awaiting Response`) |

A **draft** PR is not ready for review. Opening a draft moves nothing; wait for `gh pr ready` or a non-draft create.

Everything else (QA, Waiting to Ship, Resolved) happens only when the user asks.

## Consent rule

**Act without asking when the ticket is unassigned or already assigned to the user.** Do it, then report in one line.

**Ask first when the ticket is assigned to someone else.** That person may be the reviewer looking at it, or may have picked it up — reassigning silently would steal it. Say who holds it and what you'd do:

> `DEV-153786` is assigned to Alex Rivera (status: In Progress). Reassign to you and keep it In Progress?

Same rule for transitions: a status move on someone else's ticket needs a yes first. An explicit user instruction ("assign DEV-1234 to me") *is* that yes — don't re-ask.

Never act on a ticket outside the `DEV` project without the user naming it.

## Constants

| Constant | Value |
| -------- | ----- |
| Cloud ID | `86993857-e7f0-4c29-b941-88d3e688b686` |
| Site | `https://roverdotcom.atlassian.net` |
| Project | `DEV` |
| The user's Jira accountId | `712020:63029ab2-4ae3-4b83-9b52-a036e8b4fa8a` (Sergi Garreta) |

Re-derive the accountId with `mcp__gateway__atlassian_atlassianUserInfo` if that value is ever rejected, and update this file.

## Resolving the ticket key

In order; first hit wins:

1. The key the user typed (`DEV-153786`).
2. The current branch — first `[A-Z]+-\d+` match in `git branch --show-current`. `DEV-153786-combined` → `DEV-153786`.
3. Commit subjects since the base branch — `git log origin/master..HEAD --oneline`, looking for `[DEV-153786]`.
4. The PR title, if a PR exists.

If a branch yields **several** keys (a combined branch, a stack), name them all and ask which to move rather than moving all of them.

If nothing yields a key, do nothing — say there's no ticket to move. Never guess a key.

## Transition ids are not stable — always resolve by name

**Transition ids differ per source status.** `In Code Review` is id `741` from `In Progress` but id `841` from `Backlog`. Hardcoding an id will silently move the ticket to the wrong status or fail.

Every transition is therefore two calls:

```
mcp__gateway__atlassian_getTransitionsForJiraIssue(cloudId, issueIdOrKey)
  → find the entry whose `name` matches, with `isAvailable: true`
mcp__gateway__atlassian_transitionJiraIssue(cloudId, issueIdOrKey, transition: { id: "<that id>" })
```

If the name isn't in the list, the workflow doesn't allow that move from the current status. Report the current status and the available transition names — don't try to route through an intermediate status on your own.

## The DEV workflow

Transition **names** (stable) and the statuses they land on:

| Transition name | Lands on status | Category | Use |
| --------------- | --------------- | -------- | --- |
| `Start Progress` | `In Progress` | In Progress | Work has begun. |
| `In Code Review` | **`Awaiting Response`** | In Progress | PR is up and ready for review. Note the status name does not match the transition name — `Awaiting Response` *is* the team's code-review column. |
| `QA Testing` | `QA Testing` | In Progress | On request. |
| `Waiting to Ship` | `Waiting to Ship` | In Progress | Merged, not yet released. On request. |
| `Resolve Issue` | `Resolved` | Done | On request only. **`hasScreen: true`** — Jira may require a `resolution`; pass it in `fields` if the call is rejected. |
| `Stop Progress` | `Backlog` | To Do | Parking work. |
| `Blocked` | `Blocked` | In Progress | Started, then blocked. |
| `Blocked (cannot be started)` | `Blocked (not started)` | To Do | Blocked before starting. |
| `On Hold` | `Waiting` | In Progress | |
| `Planning` | `In Planning` | In Progress | |

The team's happy path: `Backlog` → `In Progress` → `Awaiting Response` → `QA Testing` → `Waiting to Ship` → `Resolved` / `Done`. This skill automates only the first two arrows.

## Procedures

### Start work

1. Resolve the key.
2. `getJiraIssue(cloudId, key, fields: ["summary", "status", "assignee"])`.
3. **Assignee gate.** Someone else? Ask (see Consent rule) and stop until answered. Unassigned or the user? Continue.
4. Assign if not already the user: `editJiraIssue(cloudId, key, fields: { "assignee": { "accountId": "712020:63029ab2-4ae3-4b83-9b52-a036e8b4fa8a" } })`.
5. Skip the transition if the status is already `In Progress`, or is any of `Awaiting Response` / `QA Testing` / `Waiting to Ship` / `Resolved` / `Done` — those are ahead of `In Progress`, and dragging the ticket backwards loses information. Say you left it where it was.
6. Otherwise resolve `Start Progress` by name and transition.
7. Report one line: `DEV-153786 — assigned to you, Backlog → In Progress.`

### PR ready for review

1. Resolve the key, preferring the branch the PR is on.
2. Confirm the PR is **not** a draft (`gh pr view --json isDraft,number,url`). A draft: do nothing, and say so.
3. `getJiraIssue` for `status` and `assignee`; apply the assignee gate.
4. Already `Awaiting Response` or further along? Do nothing, say so.
5. Resolve `In Code Review` by name and transition.
6. Report one line, including the PR number: `DEV-153786 — In Progress → Awaiting Response (PR #12345).`

Do **not** post a Jira comment linking the PR. GitHub's Jira integration links the branch and PR automatically once the key is in the branch name or PR title; a manual comment duplicates it.

### On request — any other move

Resolve the transition by name, transition, report. For `Resolve Issue`, if Jira rejects the call for a missing screen field, retry with the `resolution` the user named — never invent one.

## Batching

Several tickets at once (a combined branch, a sprint sweep): loop the same procedure per ticket and report one line each. The assignee gate applies **per ticket** — one ticket needing a question doesn't block the others; do those, then ask about the one.

## Errors you'll actually hit

- **`Transition id ... is not valid`** — you reused an id from a different source status. Re-read `getTransitionsForJiraIssue` for *this* ticket.
- **Transition name absent from the list** — not reachable from the current status. Report status + available names.
- **Transition rejected on a reopened ticket** — a stale `resolution` blocks it. Clear it: `editJiraIssue(fields: { "resolution": null })`, then retry.
- **Auth error on any `mcp__gateway__atlassian_*` call** — run `mcp__gateway__authenticate` or ask the user to run `/mcp`. Don't fall back to `acli` or `curl`.

## Checklist

- [ ] Ticket key came from the user, the branch, a commit, or the PR title — never guessed.
- [ ] Assignee checked **before** acting; a third-party assignee got a question, not a silent reassign.
- [ ] Transition id resolved by name from `getTransitionsForJiraIssue` on this ticket, this call.
- [ ] Ticket not dragged backwards from a status ahead of the target.
- [ ] Draft PRs did not trigger `In Code Review`.
- [ ] Reported the ticket key and the `from → to` statuses in one line.
