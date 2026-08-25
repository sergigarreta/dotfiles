---
name: owner-retention-ticket-create
description: Create or update Owner Retention team Jira tickets (story, task, bug, defect, spike). Writes deliberately minimal ticket text — Links plus one sentence — and never a duplicate implementation plan.
---

# Owner Retention Ticket Creation

File or update a Jira ticket for the **Owner Retention** team via the Atlassian MCP. Goal: one round-trip, correct metadata, working SmartLinks, no follow-up edits.

Scope: Owner Retention-team work in the **DEV** project (stories, tasks, bugs, defects), SmartLinks, and Acceptance Criteria checklists. Not for: other teams, or status questions on an existing ticket. To assign a ticket or move it through the workflow, use the `owner-retention-ticket-lifecycle` skill instead.

## The minimalism rule — read this first

**Ticket text is an index, not a document.** The ticket exists so a human can find the real artifacts (epic, spec, Figma, PR) and know in one sentence what changes. Everything else lives where it belongs: the plan in the branch and PR, the design in Figma, the reasoning in the spec.

Hard limits for a story, task, or spike description:

| Part | Limit |
| ---- | ----- |
| `## Links` bullets | One per real artifact. No placeholder bullets. |
| Body prose | **One sentence**, two at the absolute most. Present tense, states the change. |
| Acceptance Criteria (`customfield_12103`) | **1–3** tickable outcomes. Never more without the user asking. |

**Do not write** a `## Background` heading, a `## Development` section, a file-path list, a numbered implementation plan, a "Context" preamble, a restatement of the epic, or a summary of what the linked spec says. If you find yourself explaining *how*, stop — that belongs in the PR.

Bugs and defects are the one exception: they keep Steps / Expected / Actual, because a repro is not reconstructable from a link. Keep each of those sections to the minimum that reproduces the problem.

When the user hands you a long brief, your job is to **compress it to a link plus a sentence**, not to transcribe it. If the brief has no linkable home, say so and offer to put it in the ticket — the user's call, not yours.

### Target shape

```
## Links

- Epic: <inlineCard DEV-147289>
- Spec: <inlineCard Confluence page>
- Design: <inlineCard Figma frame>

Sitter rows in My Sitters open the sitter relationship screen instead of the profile.
```

Acceptance Criteria field:

```
[ ] Tapping a sitter row opens the relationship screen
[ ] Existing deep links to the profile still resolve
```

That is a complete, well-formed Owner Retention ticket. Resist adding to it.

## Constants for the Rover instance

Hard-code these — they're stable and looking them up every time wastes a tool call.

| Constant          | Value                                     | Why it matters |
| ----------------- | ----------------------------------------- | -------------- |
| Cloud ID          | `86993857-e7f0-4c29-b941-88d3e688b686`    | Required by every `mcp__gateway__atlassian_*` call. |
| Site              | `https://roverdotcom.atlassian.net`       | Base for all SmartLink URLs. |
| Project           | `DEV` (id `10000`)                        | Where Owner Retention tickets live. |
| Component         | `Owner Retention` (id `17596`)            | System `components` field. |
| Team UUID         | `ec63b0dd-b1fc-47c0-a646-56363181aaf2`    | Owner Retention team in the Atlassian Teams field. |

Issuetypes: `Story` (id `10001`, the default for product work), `Task` (id `3`, engineering chore / tooling / infra, only when the user names it), `Bug` (id `1`, customer-facing defect), `Defect` (id `10529`, non-customer-facing or internally-found), `Spike` (investigation).

If the Cloud ID ever fails to resolve, refresh it via `getAccessibleAtlassianResources` and update this file.

## MCP server selection

Use the gateway Atlassian tools (`mcp__gateway__atlassian_*`). On an auth error, run `mcp__gateway__authenticate` (or connect via `/mcp`) and retry. If the gateway is not connected, ask the user before triggering an interactive auth flow.

## Required fields

For every ticket:

- [ ] **Component** — `Owner Retention` (system `components` field)
- [ ] **Team** — `customfield_11400`, the bare UUID string
- [ ] **Description** — ADF, following the minimalism rule above

Stories, tasks & spikes additionally:

- [ ] **Acceptance Criteria** — `customfield_12103`, ADF `taskList`, 1–3 items

Bugs & defects additionally:

- [ ] **Priority** — mandatory. Infer and propose it; never create a bug without one. See [references/bug-triage.md](references/bug-triage.md).

## Title format

`[Scope tag] Short imperative description` — under ~80 chars. Scope tags signal the surface touched: `[FE]`, `[BE]`, `[FE/BE]`, `[EE]` (eng excellence / tooling / infra). Composite tags aid scanning: `[Carousel][FE]`, `[Search][BE]`.

Examples: `[FE] Add bundle-aware copy to search rate card`, `[BE] Fork journal_order recognition for bundle orders`.

For bugs, prepend the scope tag the same way plus a platform tag — `[Web]`, `[iOS]`, `[Android]`.

## Bugs & Defects

Pick the issuetype by who hits the problem:

- **`Bug`** (id `1`) — customer-facing: a regression or error a user actually hits.
- **`Defect`** (id `10529`) — non-customer-facing / internally-found: layout polish, tooling, internal-only breakage, dev/prod parity, QA findings not yet shipped.

Both share identical rules; only `issuetype` changes. Description layout:

```
## Steps to Reproduce

1. Shortest path to the symptom. Environment (prod / staging / branch URL) and the
   account or admin link as an inlineCard.

## Expected Result

## Actual Result

## Technical Findings   (only if you actually have a suspected cause)
```

Acceptance Criteria is omitted — Expected Result carries the acceptance signal. Drop any section you'd have to pad to fill.

Priority, SLA `duedate`, and sprint proposal: [references/bug-triage.md](references/bug-triage.md).

## SmartLinks

A Jira SmartLink is a rich inline card showing the linked artifact's title, status, and avatar.

**The trap:** sending the description as **markdown** with `<custom data-type="smartlink">` tags (what the Jira UI gives you when you copy a description containing an inline card) stores the tag as literal text. The markdown round-trip view masks this — the field looks identical whether storage is a real card or a literal string.

**The fix:** send ADF with explicit `inlineCard` nodes via `contentFormat: "adf"`.

```jsonc
{ "type": "inlineCard", "attrs": { "url": "https://roverdotcom.atlassian.net/browse/DEV-147289" } }
```

The same node works for Jira issues, Confluence pages, Figma files, GitHub PRs, and Slack messages — Jira's resolver picks the renderer from the URL host.

**Figma URLs:** strip trailing dev-mode params (`mode=dev`, `m=dev`) so viewers aren't forced into Dev Mode.

**Verifying:** even with `responseContentFormat: "adf"`, the MCP read-back serializes the description to markdown, where inline cards appear as `<custom>` tags. That is *not* proof of literal text — confirm in the Jira UI.

## Field-ID cheat sheet

Source of truth: `getJiraIssueTypeMetaWithFields(projectIdOrKey="DEV", issuetypeId="10001", requiredFieldsOnly=false)`. Every row applies unchanged to Story, Task, Bug and Defect.

| Field | ID | Write shape | Notes |
| ----- | -- | ----------- | ----- |
| Components | `components` | `[{"id": "17596"}]` | Owner Retention. |
| Team | `customfield_11400` | **plain string** `"ec63b0dd-b1fc-47c0-a646-56363181aaf2"` | Bare UUID. NOT `{"id": ...}` — the object form double-wraps and fails with `Team id 'JsonData{data={id=...}}' is not valid`. |
| Acceptance Criteria | `customfield_12103` | ADF doc with a `taskList` | Schema declares `string`/`textarea` and **lies**. Plain markdown errors with "Operation value must be an Atlassian Document". |
| Description | `description` | ADF doc | `inlineCard` nodes for cross-references. |
| Priority | `priority` | `{"name": "Major"}` | Required for Bug/Defect. `Blocker` / `Critical` / `Major` / `Minor` / `Trivial`. |
| Due date (SLA) | `duedate` | `"2026-06-02"` | Bug SLA. Usually auto-set by automation when priority is set. |
| Sprint | `customfield_10007` | **bare number** `4257` | NOT an array — `[4257]` is rejected with `The Sprint (id) must be a number`. The array-of-objects is the read-back shape only. Setting it on create works. |
| Epic Link | `customfield_10008` | `"DEV-147289"` | Parent epic for a Story or Task. |
| Story Points | `customfield_10004` | `3` | |
| Code Reviewer | `customfield_10101` | `{"accountId": "..."}` | |
| Parent Link | `customfield_11200` | issue key | Cross-hierarchy parenting. |
| Start date | `customfield_11937` | `"2026-05-19"` | |
| End date | `customfield_12144` | `"2026-05-26"` | |

### The editmeta quirk

`editmeta.fields` lists only `summary`, `issuetype`, `description`, `assignee`. It looks like everything else is read-only. It isn't — `editJiraIssue` accepts `components`, `customfield_11400`, `customfield_12103`, etc. Always use `getJiraIssueTypeMetaWithFields` as the source of truth, never `editmeta`.

## Workflow

1. **Pick the issuetype.** Defect described (regression, error, layout/ordering issue, QA finding)? `Bug` if customer-facing, `Defect` otherwise. Otherwise `Story` — or `Task` when the user names an engineering chore.

2. **Collect inputs.** Title (or enough to write one), every link to embed, assignee and sprint if known (don't guess). For stories: the parent epic, the one-sentence change, and 1–3 acceptance outcomes. For bugs: repro, expected vs. actual, environment/account/platform, and a priority.

3. **Compress.** Before building the payload, re-read the minimalism rule. Cut anything that restates a linked artifact.

4. **Build the ADF description** — see [references/adf-templates.md](references/adf-templates.md). Every cross-reference URL is an `inlineCard`. Never markdown `<custom>` tags.

5. **Build the ADF Acceptance Criteria** as a `taskList` (stories/tasks/spikes only).

6. **Create or update in a single call** — `createJiraIssue`, or `editJiraIssue` for a backfill. Payload examples in [references/adf-templates.md](references/adf-templates.md).

7. **Report back**: issue key + URL. For bugs also the priority, the `duedate` Jira actually returned (re-read via `getJiraIssue`; don't trust your input), and the sprint note. Ask the user to eyeball the Jira UI for card rendering and AC checkboxes.

Creating a ticket you're about to work on? Hand off to `owner-retention-ticket-lifecycle` to assign it and start progress.

## Errors you'll actually hit

- **"Operation value must be an Atlassian Document"** — you sent markdown or a plain string to an ADF field. Switch to `contentFormat: "adf"` and wrap in `{"type":"doc","version":1,"content":[...]}`.
- **Markdown autolink corruption** — raw URLs adjacent to `<custom>` tags get rewritten into `[label](url)`, sometimes splitting words. Use ADF + `inlineCard`.
- **`editmeta` says a field is read-only** — try the write anyway; trust the meta only if Jira rejects it.
- **SmartLink renders as raw text** — you sent `<custom data-type="smartlink">` via markdown.
- **`Team id 'JsonData{data={id=...}}' is not valid`** — you wrapped the team UUID in an object. Send the bare string.
- **`Number value expected as the Sprint id`** — you sent `[4257]`. Send `4257`.

## Pre-flight checklist

Every ticket:

- [ ] Body prose is **one sentence**. No `Background`, no `Development`, no file-path list.
- [ ] Nothing in the description restates what a linked artifact already says.
- [ ] Title is `[Scope] description`, under ~80 chars.
- [ ] `components` includes `{"id": "17596"}`.
- [ ] `customfield_11400` is the bare Owner Retention UUID string.
- [ ] `description` is an ADF doc and `contentFormat: "adf"` is set on the call.
- [ ] Every cross-reference is an `inlineCard`, not a bare URL or a `<custom>` tag.
- [ ] Figma URLs have dev-mode params stripped.
- [ ] `customfield_10007` (Sprint), if set, is a bare number.

Stories, tasks & spikes:

- [ ] `customfield_12103` is an ADF `taskList` with **1–3** items.
- [ ] AC items are outcomes a reviewer ticks off, never implementation steps.
- [ ] Epic link (`customfield_10008`) set if the work sits under an epic.

Bugs & defects:

- [ ] `issuetype` is `Bug` (customer-facing) or `Defect` (internal).
- [ ] `priority` is inferred from the issue, not invented.
- [ ] Steps / Expected / Actual present; no padded sections.
- [ ] Plan to surface the resulting `duedate` and sprint note.
