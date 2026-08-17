---
name: owner-retention-ticket-create
description: Create or update Owner Retention team Jira tickets (story, task, bug, defect, spike).
---

# Owner Retention Ticket Creation

File or update a Jira ticket for the **Owner Retention** team via the Atlassian MCP. Goal: one round-trip, correct metadata, working SmartLinks, no follow-up edits.

Scope: Owner Retention-team work in the **DEV** project (stories, tasks, bugs, defects), SmartLinks (Jira/Confluence/Figma/GitHub), and Acceptance Criteria checklists. Not for: other teams, the bug-triage Severity/SLA process (see [the Bug Triage page](https://roverdotcom.atlassian.net/wiki/spaces/TECH/pages/300843041/Bug+Triage+Priority+and+Severity+Definitions+SLAs)), or status questions on an existing ticket.

## Constants for the Rover instance

Hard-code these — they're stable and looking them up every time wastes a tool call.

| Constant          | Value                                     | Why it matters                                                                                       |
| ----------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Cloud ID          | `86993857-e7f0-4c29-b941-88d3e688b686`    | Required by every `mcp__gateway__atlassian_*` call.                                                |
| Site              | `https://roverdotcom.atlassian.net`       | Base for all SmartLink URLs.                                                                         |
| Project           | `DEV` (id `10000`)                        | Where Owner Retention tickets live.                                                                     |
| Default issuetype | `Story` (id `10001`)                      | Owner Retention files product work as Story. Use `Task` (id `3`) for engineering chores / tooling when the user says so. For customer-facing defects use `Bug` (id `1`); for non-customer-facing / internally-found defects use `Defect` (id `10529`). Both follow the "Bugs & Defects" section. |
| Component         | `Owner Retention` (id `17596`)            | System `components` field.                                                                           |
| Team UUID         | `ec63b0dd-b1fc-47c0-a646-56363181aaf2` | Owner Retention team in the Atlassian Teams field.                                                      |

If the Cloud ID ever fails to resolve, refresh it via `getAccessibleAtlassianResources` and update this file.

## MCP server selection

This skill uses the gateway Atlassian tools (`mcp__gateway__atlassian_*`). If a call returns an auth error, run `mcp__gateway__atlassian_authenticate` (or connect the gateway via `/mcp`) and retry.

If the gateway is not connected, ask the user before triggering an interactive auth flow.

## Required fields for an Owner Retention ticket

### For all tickets (Story, Task, Bug, or Defect):
- [ ] **Component** — `Owner Retention` (system `components` field)
- [ ] **Team** — `Owner Retention` (`customfield_11400`)
- [ ] **Description** — For stories/tasks: Links → Background → Development. For bugs/defects: Steps to Reproduce, Expected Result, Actual Result, etc. Use SmartLinks for every cross-reference.

### For stories & tasks only:
- [ ] **Acceptance Criteria** — action list in `customfield_12103` (ADF `taskList`)

### For bugs & defects only:
- [ ] **Priority** — set per the triage rules below. If you can infer it from the description, propose a value; otherwise ask the user. Don't create a bug/defect without a priority.

See the Field-ID cheat sheet below for field shapes.

## The ticket layout

The team's house description has three top-level sections, in this order:

```
## Links

- Bulleted list of every related artifact: epic, sibling tickets, Confluence pages,
  Figma boards, GitHub PRs, Slack threads. Each one as an inlineCard SmartLink.

## Background

- What is this work and why is it being done? Reference the epic, the design doc,
  the incident, whatever motivates it. Cross-references go inline as SmartLinks.

## Development

- Where (file paths) and how (numbered steps). This is the implementer's plan,
  not the reviewer's checklist.
```

Acceptance Criteria does **not** go in the description body. It lives in its own field (`customfield_12103`) as a `taskList` so reviewers get tickable checkboxes.

**Level of detail rule of thumb:**

- _Background_ = what + why.
- _Development_ = where + how.
- _Acceptance Criteria field_ = outcomes a reviewer can tick off. Never re-state implementation steps here.

## Title format

`[Scope tag] Short imperative description` — under ~80 chars. Scope tags signal the surface touched: `[FE]` (frontend), `[BE]` (backend), `[FE/BE]` (both), `[EE]` (eng excellence / tooling / infra). Composite tags aid scanning: `[Carousel][FE]`, `[Search][BE]`. Examples: `[FE] Add bundle-aware copy to search rate card`, `[BE] Fork journal_order recognition for bundle orders`.

For bugs, prepend the scope tag the same way, plus platform tags `[Web]`, `[iOS]`, `[Android]`. Use `[Web]` for browser-only bugs (matches recent DEV usage).

## Bugs & Defects

Two issuetypes capture defects; pick by who hits the problem:

- **`Bug`** (id `1`) — a **customer-facing** problem: a regression or error a user actually hits.
- **`Defect`** (id `10529`) — a **non-customer-facing / internally-found** issue. Jira's own label is "Type to capture non-customer-facing issues": layout/ordering polish, tooling, internal-only breakage, dev/prod parity, QA-found issues not yet shipped to users.

**Both share identical rules** — only the `issuetype` value changes. Mandatory priority, SLA `duedate` automation, Steps/Expected/Actual layout, and sprint placement are the same for both (verified: a `Defect` set to `Major` auto-populates `duedate` like a `Bug`).

Follow the same rules as tasks (Component/Team = Owner Retention, SmartLinks via ADF `inlineCard`) with three differences:

1. **Issuetype** is `Bug` (id `1`) or `Defect` (id `10529`), not `Task`.
2. **Priority is mandatory.** Don't open a bug/defect without one. Either infer it from the description against the triage table below, or ask the user before creating the ticket.
3. **Description layout is different** — use the bug/defect description layout (see section "Bug description layout"), not Links / Background / Development. Acceptance Criteria (`customfield_12103`) is normally omitted; the Expected Result section serves that purpose.

### Priority and SLA

Source of truth: [Bug Triage Priority and Severity Definitions, & SLAs](https://roverdotcom.atlassian.net/wiki/spaces/TECH/pages/300843041/Bug+Triage+Priority+and+Severity+Definitions+SLAs). Summary of the current (Q3) rules:

| Priority   | Web SLA        | Mobile SLA               | When to use                                                                                                                       |
| ---------- | -------------- | ------------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| `Blocker`  | **3 days**     | Before release           | Customer-impacting (or imminently so) in a core workflow. Stays mis-priced, payouts failing, etc. Someone must be actively on it. |
| `Critical` | **7 days**     | Next release             | Degrading customer/internal experience. On-call pages, high CX-contact issues, blocking issues in non-core flows.                 |
| `Major`    | **14 days**    | Next two releases        | Isolated customer-impacting issues with workarounds. Limited-scope Sentry 5xx, flaky tests, non-blocking issues in non-core flow. |
| `Minor`    | **28 days**    | (rolls up with priority) | "Looks not right but works": typos, layout oddities, prod/dev parity that doesn't block testing.                                  |
| `Trivial`  | As prioritized | As prioritized           | Only frequent users would notice. Behind dev menus, non-blocking polish.                                                          |

**Checklist for bugs:**
- [ ] Every bug must have a priority

#### Inferring priority

If the user gives you a clear bug description, propose a priority before asking:

- Is a paid workflow broken (booking, payout, stay creation)? → `Blocker`.
- Is on-call paging, or is CX seeing a flood of contacts? → `Critical`.
- Is it scoped to a specific user state with a workaround? → `Major`.
- Is it cosmetic / copy / dev-parity? → `Minor` or `Trivial`.

State your inference and let the user override: _"This looks like a `Major` to me because the symptom is scoped to merged CIAF sitters with a workaround (full list visible on tap). Want a different priority?"_

### The SLA value — `duedate`

The bug SLA materializes as the system `duedate` field (an ISO date like `"2026-06-02"`). Automation sets it when priority is set: `duedate ≈ created_date + SLA-days` for the chosen priority (verified against recent DEV bugs — e.g. a `Major`/14-day bug created 2026-05-19 → `duedate 2026-06-02`).

After creating a bug, read the ticket back and surface the `duedate` value to the user — that's the SLA. If it didn't populate (automation skipped, priority wasn't accepted, etc.), set it explicitly via `editJiraIssue` with `fields: {"duedate": "YYYY-MM-DD"}`, computed as `created + SLA-days`.

### Bug description layout

Bugs don't use the Links → Background → Development layout. Use the team's standard bug shape — same sections, same order. Cross-references (Slack threads, Zendesk tickets, admin URLs, Figma frames) still go through `inlineCard` for SmartLink rendering.

```
## Steps to Reproduce

1. Numbered list. Include the environment (prod / staging / branch URL), the user
   account or admin link as a SmartLink, and any preconditions.

## Expected Result

What should happen. Keep it to outcomes a reviewer can check.

## Actual Result

What does happen. Include screenshots, error text, or Sentry links via inlineCards.

## Technical Findings   (optional but recommended)

Suspected cause, ruled-out hypotheses, file paths, log/trace links. This is the
equivalent of the task layout's "Development" section.

## Evidence / Links     (optional)

Slack thread, Zendesk ticket, Figma frame, Sentry issue — each as an inlineCard.
```

### After creating a bug — tell the user

Always close the loop with the user by surfacing:

1. **The created issue key and URL.**
2. **The chosen priority and resulting SLA date** (`duedate`). Re-read the ticket via `getJiraIssue` after creation; don't trust the input you sent. Jira automation may adjust the date, and surfacing the wrong number defeats the purpose of the reminder.
3. **A concrete proposed sprint to add the bug to**, plus a reminder that placing it is a separate manual step. See the "Proposing a sprint" section for the algorithm.

The triage doc requires every non-trivial bug to live in a sprint so it meets its SLA. The bot won't add it for them, but you can save a round-trip by naming the sprint that fits.

### Proposing a sprint

**When the user gives you a sprint, just set it.** Pass `customfield_10007` as the bare numeric sprint id (e.g. `4257`) on the `createJiraIssue` call — it persists, no manual step. The "propose + manual placement" flow below is the fallback for when you're only *recommending* a sprint the user hasn't named, not when one was supplied.

**Sprint shape.** Owner Retention sprints (board id `5`) are stored on tickets in `customfield_10007` as a list of sprint objects. Each entry has `id`, `name`, `state` (`closed` / `active` / `future`), `startDate`, `endDate`. Cadence is **exactly 14 days, every other Wednesday**. The name format is `Sprint YY-MM-DD` where the date is the Wednesday start (e.g., `Sprint 26-05-27` runs 2026-05-27 → 2026-06-10). Note: `startDate` in the API may be expressed in UTC so the day-of-week looks off — trust the **name** as the source of truth for the start date.

**Sprint selection algorithm:**
1. Find candidate sprints by searching recent Owner Retention tickets with `customfield_10007` populated. Note each sprint's `name`, `state`, `startDate`, and `endDate`.
2. Filter to sprints with `state` in (`active`, `future`). Never propose a `closed` sprint.
3. Pick the **latest** sprint whose `endDate` is on or before the bug's SLA `duedate`. This ensures the team has the full sprint window to land the fix.
4. If no `active`/`future` sprint satisfies that constraint (typical for short SLAs — Blocker = 3 days, Critical = 7 days), fall back to the **active** sprint.
5. Never roll forward into a sprint that ends after the SLA, or back into a closed sprint.

_Worked example._ Bug created `Major`, `duedate = 2026-06-02`. `Sprint 26-05-13` (May 13→27) ends ≤ June 2 ✓; `Sprint 26-05-27` (May 27→June 10) ends > June 2 ✗. Latest qualifying = `Sprint 26-05-13` (active) — propose it. Report sprint name, days from sprint start to SLA, and that the user must place it manually (bot won't auto-add). If you fell back to the active sprint because nothing qualified, say so plainly.

## SmartLinks

A Jira SmartLink is a rich inline card showing the linked artifact's title, status, and avatar.

**The trap:** if you send the description as **markdown** and embed `<custom data-type="smartlink">...</custom>` tags (which is what the Jira UI shows when you copy a description that contains an inline card), Jira stores the tag as literal text. It renders the raw `<custom>` tag, not a card. The markdown round-trip view masks this — the field looks the same whether the underlying storage is a real inline card or a literal `<custom>` string.

**The fix:** send the description as **ADF** (Atlassian Document Format, JSON) with explicit `inlineCard` nodes. The MCP tool exposes this via `contentFormat: "adf"`.

```jsonc
// Inside an ADF paragraph's content array:
{
    "type": "inlineCard",
    "attrs": { "url": "https://roverdotcom.atlassian.net/browse/DEV-147289" },
}
```

Same node works for **Jira issues, Confluence pages, Figma files, GitHub PRs, and Slack messages** — Jira's link resolver picks the renderer based on the URL host.

### Figma URLs

Strip trailing dev-mode params (`mode=dev`, variants like `m=dev`) so viewers aren't forced into Figma Dev Mode. E.g. `.../Name?node-id=123-456&mode=dev` → `.../Name?node-id=123-456`.

**Verifying the result:** even when you request `responseContentFormat: "adf"` on a read-back, the MCP tool currently serializes the description to markdown, where inline cards appear as `<custom data-type="smartlink">` tags. That serialization is not proof of literal text — to confirm SmartLinks rendered, open the ticket in the Jira UI. (See [DEV-148083](https://roverdotcom.atlassian.net/browse/DEV-148083) for a worked example with ten verified inline cards.)

## Field-ID cheat sheet

Source of truth: `getJiraIssueTypeMetaWithFields(projectIdOrKey="DEV", issuetypeId="10001", requiredFieldsOnly=false)`. Verified: Story exposes `components`, `customfield_11400`, `customfield_12103`, `customfield_10008`, `customfield_10007`, `customfield_10004` and `customfield_10101` with the same shapes as Task — every row below applies unchanged to both.

| Field               | ID                  | Schema                                         | Write shape                                         | Notes                                                                                                            |
| ------------------- | ------------------- | ---------------------------------------------- | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Components          | `components`        | system, array                                  | `[{"id": "17596"}]` or `{"add": {"id": "17596"}}`   | Owner Retention = id `17596`.                                                                                       |
| Team                | `customfield_11400` | `team` / `atlassian-team`                      | **Plain string** `"ec63b0dd-b1fc-47c0-a646-56363181aaf2"` (bare UUID) | Owner Retention UUID — note there is no `-67`-style suffix; send it exactly as shown. Send the UUID as a plain string, NOT `{"id": ...}`. Same for Story, Task and Bug (identical field schema). Via the `mcp__gateway__atlassian_*` server's `additional_fields`, the object form double-wraps and fails with `Team id 'JsonData{data={id=...}}' is not valid`. |
| Acceptance Criteria | `customfield_12103` | declared `string`/`textarea` — **schema lies** | ADF doc with a `taskList` of `taskItem` nodes       | Send with `contentFormat: "adf"`. Plain markdown errors with "Operation value must be an Atlassian Document".    |
| Description         | `description`       | system, ADF                                    | ADF doc                                             | Use `inlineCard` nodes for cross-references.                                                                     |
| Priority            | `priority`          | system, named object                           | `{"name": "Major"}`                                 | Required for Bug issuetype. Valid names: `Blocker`, `Critical`, `Major`, `Minor`, `Trivial`. |
| Due date (SLA)      | `duedate`           | system, date                                   | `"2026-06-02"`                                      | Bug SLA. Usually auto-set by automation when priority is set; set explicitly only as a backstop.                 |
| Sprint              | `customfield_10007` | array (on read) / number (on write)            | `4257` (bare number)                                | Applies to **all issuetypes** (Task, Bug, Defect, Story). **Write the bare numeric sprint id**, NOT an array. Via the `mcp__atlassian__*` server's `additional_fields`, the array form `[4257]` is rejected with `The Sprint (id) must be a number` / `Number value expected as the Sprint id`. The array-of-objects (`[{"id":4257,"name":"Sprint 26-06-10","state":"active",...}]`) is the **read-back** shape only. Setting it on create works — no separate manual add needed. (Triage policy additionally requires non-trivial bugs/defects to live in a sprint to meet their SLA.) |
| Epic Link           | `customfield_10008` | string                                         | `"DEV-147289"`                                      | Sets the parent epic for a Story or Task.                                                                        |
| Story Points        | `customfield_10004` | number                                         | `3`                                                 |                                                                                                                  |
| Code Reviewer       | `customfield_10101` | user                                           | `{"accountId": "..."}`                              |                                                                                                                  |
| Parent Link         | `customfield_11200` | string                                         | issue key                                           | Used for cross-hierarchy parenting.                                                                              |
| Start date          | `customfield_11937` | date                                           | `"2026-05-19"`                                      |                                                                                                                  |
| End date            | `customfield_12144` | date                                           | `"2026-05-26"`                                      |                                                                                                                  |

### The editmeta quirk

The Story and Task issuetypes' `editmeta.fields` map only lists `summary`, `issuetype`, `description`, `assignee`. It looks like everything else is read-only. It isn't — `editJiraIssue` happily accepts `components`, `customfield_11400`, `customfield_12103`, etc. via the underlying REST API. Always use `getJiraIssueTypeMetaWithFields` as the source of truth, never `editmeta`.

## Templates

### Description (ADF, with SmartLinks)

Build the description as an ADF document. For every Jira/Confluence/Figma/GitHub/Slack reference, use an `inlineCard` node. Plain HTTPS URLs in text don't auto-resolve — wrap them in `inlineCard`.

```jsonc
{
    "type": "doc",
    "version": 1,
    "content": [
        {
            "type": "heading",
            "attrs": { "level": 2 },
            "content": [{ "type": "text", "text": "Links" }],
        },
        {
            "type": "bulletList",
            "content": [
                {
                    "type": "listItem",
                    "content": [
                        {
                            "type": "paragraph",
                            "content": [
                                { "type": "text", "text": "Epic: " },
                                {
                                    "type": "inlineCard",
                                    "attrs": {
                                        "url": "https://roverdotcom.atlassian.net/browse/DEV-147289",
                                    },
                                },
                            ],
                        },
                    ],
                },
                {
                    "type": "listItem",
                    "content": [
                        {
                            "type": "paragraph",
                            "content": [
                                { "type": "text", "text": "Design doc: " },
                                {
                                    "type": "inlineCard",
                                    "attrs": {
                                        "url": "https://roverdotcom.atlassian.net/wiki/spaces/.../pages/.../...",
                                    },
                                },
                            ],
                        },
                    ],
                },
            ],
        },

        {
            "type": "heading",
            "attrs": { "level": 2 },
            "content": [{ "type": "text", "text": "Background" }],
        },
        {
            "type": "paragraph",
            "content": [
                {
                    "type": "text",
                    "text": "Short prose paragraph. Mention the epic ",
                },
                {
                    "type": "inlineCard",
                    "attrs": {
                        "url": "https://roverdotcom.atlassian.net/browse/DEV-147289",
                    },
                },
                { "type": "text", "text": " inline. Explain the why." },
            ],
        },

        {
            "type": "heading",
            "attrs": { "level": 2 },
            "content": [{ "type": "text", "text": "Development" }],
        },
        {
            "type": "orderedList",
            "content": [
                {
                    "type": "listItem",
                    "content": [
                        {
                            "type": "paragraph",
                            "content": [
                                { "type": "text", "text": "Step 1: touch " },
                                {
                                    "type": "text",
                                    "text": "src/frontend/.../File.tsx",
                                    "marks": [{ "type": "code" }],
                                },
                            ],
                        },
                    ],
                },
                {
                    "type": "listItem",
                    "content": [
                        {
                            "type": "paragraph",
                            "content": [
                                { "type": "text", "text": "Step 2: ..." },
                            ],
                        },
                    ],
                },
            ],
        },
    ],
}
```

Common ADF marks you'll use: `{"type":"code"}` for inline code, `{"type":"strong"}` for bold, `{"type":"em"}` for italics.

### Acceptance Criteria (ADF, taskList)

```jsonc
{
    "type": "doc",
    "version": 1,
    "content": [
        {
            "type": "taskList",
            "attrs": { "localId": "ac" },
            "content": [
                {
                    "type": "taskItem",
                    "attrs": { "localId": "ac-1", "state": "TODO" },
                    "content": [
                        {
                            "type": "text",
                            "text": "Outcome 1 — phrase as something a reviewer ticks off.",
                        },
                    ],
                },
                {
                    "type": "taskItem",
                    "attrs": { "localId": "ac-2", "state": "TODO" },
                    "content": [{ "type": "text", "text": "Outcome 2." }],
                },
            ],
        },
    ],
}
```

Give every `taskItem` a unique `localId`. `state` is `TODO` or `DONE`.

## The full workflow

1. **Decide: story, task, bug, or defect?** If the user is describing a defect (regression, error, unexpected behavior, layout/ordering issue, QA finding) follow the "Bugs & Defects" section in parallel with this workflow. Pick the issuetype by who hits it: customer-facing → `Bug` (id `1`); non-customer-facing / internally-found → `Defect` (id `10529`). Otherwise it's a `Story` (id `10001`) — the default for product work — or a `Task` (id `3`) when the user names one for an engineering chore / tooling / infra item.

2. **Collect inputs from the user.** Always:
    - Title (or enough info to write one in `[Scope] …` form).
    - Any links to embed as SmartLinks (epic, design doc, Figma, sibling tickets, PRs, Slack threads, Zendesk tickets).
    - Assignee + sprint if known. If unknown, skip — don't guess.

    For **stories and tasks** additionally:
    - Parent epic, if any (issue key).
    - Background prose: what + why.
    - Development plan: file paths and steps.
    - Acceptance criteria as outcomes.

    For **bugs** additionally:
    - Steps to reproduce, expected vs. actual result, environment / account / platform.
    - Technical findings (suspected cause, ruled-out hypotheses) if known.
    - **Priority.** Propose one based on the triage table in the "Priority and SLA" section; ask the user if you can't infer it confidently. Don't proceed without a priority.

3. **Build the ADF description** following the appropriate template (see "Description (ADF, with SmartLinks)" for stories/tasks or "Bug description layout" for bugs). Every cross-reference URL becomes an `inlineCard`. Do not use markdown `<custom>` tags.

4. **For stories and tasks only: build the ADF Acceptance Criteria** as a `taskList`. Bugs omit this field — the Expected Result section in the description carries the acceptance signal.

5. **Create (or update) the issue** with all required fields in a single call.

    Story example via `createJiraIssue` (use `{ "name": "Task" }` instead for an engineering chore — every other field is identical):

    ```jsonc
    {
        "cloudId": "86993857-e7f0-4c29-b941-88d3e688b686",
        "contentFormat": "adf",
        "projectKey": "DEV",
        "issuetype": { "name": "Story" },
        "summary": "[FE] Short description",
        "components": [{ "id": "17596" }],
        // Team: plain UUID string, NOT {"id": ...} — the object form double-wraps and fails.
        "customfield_11400": "ec63b0dd-b1fc-47c0-a646-56363181aaf2",
        "customfield_10008": "DEV-147289",
        "description": {
            /* ADF doc */
        },
        "customfield_12103": {
            /* ADF doc with taskList */
        },
    }
    ```

    Bug / Defect example via `createJiraIssue`. Use `{ "name": "Bug" }` for customer-facing, `{ "name": "Defect" }` for non-customer-facing / internally-found:

    ```jsonc
    {
        "cloudId": "86993857-e7f0-4c29-b941-88d3e688b686",
        "contentFormat": "adf",
        "projectKey": "DEV",
        "issuetype": { "name": "Defect" }, // or { "name": "Bug" } if customer-facing
        "summary": "[Web] Service settings Save button silently fails",
        "components": [{ "id": "17596" }],
        // Team: plain UUID string, NOT {"id": ...} — the object form double-wraps and fails.
        "customfield_11400": "ec63b0dd-b1fc-47c0-a646-56363181aaf2",
        "priority": { "name": "Major" },
        // Sprint: bare number, NOT [4257] — the array form is rejected.
        "customfield_10007": 4257,
        "description": {
            /* ADF doc with Steps / Expected / Actual / Findings */
        },
    }
    ```

    For an update (e.g. backfilling fields on an existing ticket), use `editJiraIssue` with the same `fields` shape and `contentFormat: "adf"`.

6. **Verify in the Jira UI.** The MCP read-back will show `<custom>` tags for inline cards; that's the markdown serializer, not the storage. Ask the user to open the ticket in their browser to confirm the inline cards render and the AC checkboxes are interactive. Reference: [DEV-148083](https://roverdotcom.atlassian.net/browse/DEV-148083).

7. **Return the result to the user.** Always include the issue key + URL. For bugs additionally include the priority, the `duedate` (SLA) returned by Jira, and the sprint reminder (see "After creating a bug — tell the user").

## Errors you'll actually hit

- **"Operation value must be an Atlassian Document"** — you sent markdown or a plain string to a field that needs ADF. Fix: switch to `contentFormat: "adf"` and wrap the payload in `{"type":"doc","version":1,"content":[...]}`.
- **Markdown autolink corruption** — when sending a description as markdown, raw URLs adjacent to `<custom>` tags can get rewritten into `[label](url)` form, sometimes splitting words. Fix: use ADF + `inlineCard` and stop trying to embed SmartLinks via markdown.
- **`editmeta` says a field is read-only** — it isn't necessarily. Try the write with `editJiraIssue`; if Jira rejects it, then trust the meta. Use `getJiraIssueTypeMetaWithFields` for the real list of writable fields.
- **SmartLink renders as raw text in the UI** — you sent `<custom data-type="smartlink">` via markdown. Switch to ADF `inlineCard`.

## Pre-flight checklist

Before calling `createJiraIssue` / `editJiraIssue`, confirm:

**For every ticket:**

- [ ] Title follows `[Scope] description` format, under ~80 chars.
- [ ] `components` includes `{"id": "17596"}`.
- [ ] `customfield_11400` is set to the Owner Retention team UUID.
- [ ] `description` is an ADF doc.
- [ ] Every cross-reference in the description is an `inlineCard`, not a bare URL or a `<custom>` tag.
- [ ] Every Figma SmartLink URL has dev-mode params removed (for example, strip trailing `mode=dev`).
- [ ] `customfield_10007` (Sprint), if set, is a **bare number** (e.g. `4257`), not an array — applies to any issuetype.
- [ ] `contentFormat: "adf"` is set on the call.

**For stories & tasks:**

- [ ] `issuetype` is `Story` (default) or `Task` (engineering chore the user named).
- [ ] Description uses Links / Background / Development sections.
- [ ] Epic link (`customfield_10008`) is set if the work is under an epic.
- [ ] `customfield_12103` is an ADF doc containing a `taskList` of `taskItem`s.
- [ ] AC items are outcomes, not implementation steps.

**For bugs & defects:**

- [ ] `issuetype` is `Bug` (customer-facing) or `Defect` (non-customer-facing / internally-found).
- [ ] `priority` is set to one of `Blocker` / `Critical` / `Major` / `Minor` / `Trivial` — and inferred from the issue, not invented.
- [ ] Description uses Steps to Reproduce / Expected / Actual sections.
- [ ] After creation, plan to surface the resulting `duedate` (SLA) and the sprint-placement reminder to the user.
