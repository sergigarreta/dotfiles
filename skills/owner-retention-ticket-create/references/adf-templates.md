# ADF templates for Owner Retention tickets

Read this when you're about to build the `description` or `customfield_12103` (Acceptance Criteria) payload for `createJiraIssue` / `editJiraIssue`. The shapes here are what Jira actually accepts via the MCP tool; the markdown round-trip path is a trap (see the SmartLinks section in SKILL.md).

This file gives the ADF *shapes*. The **amount** of content is governed by the minimalism rule in SKILL.md: a story description is a `Links` list plus one sentence. Nothing here licenses more.

## Contents

- Description ADF — story/task/spike layout (Links + one sentence)
- Description ADF — bug layout (Steps / Expected / Actual / Findings)
- Acceptance Criteria ADF — `taskList`
- Full `createJiraIssue` payload examples (story/task and bug)
- Common ADF marks

## Description ADF — story/task/spike layout

A `Links` heading, a `bulletList` of `inlineCard`s, then **one paragraph**. No `Background` heading, no `Development` section — see the minimalism rule in SKILL.md. Every cross-reference URL is an `inlineCard` node; plain HTTPS in text doesn't auto-resolve.

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
                                { "type": "text", "text": "Spec: " },
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
                {
                    "type": "listItem",
                    "content": [
                        {
                            "type": "paragraph",
                            "content": [
                                { "type": "text", "text": "Design: " },
                                {
                                    "type": "inlineCard",
                                    "attrs": {
                                        "url": "https://www.figma.com/design/.../Name?node-id=123-456",
                                    },
                                },
                            ],
                        },
                    ],
                },
            ],
        },

        {
            "type": "paragraph",
            "content": [
                {
                    "type": "text",
                    "text": "One sentence stating the change. Present tense.",
                },
            ],
        },
    ],
}
```

If a file path genuinely disambiguates the one sentence, inline it with a `code` mark — but a path list is not a substitute for a sentence, and never becomes a `Development` section.

## Description ADF — bug layout

Same node types, different headings: `Steps to Reproduce`, `Expected Result`, `Actual Result`, `Technical Findings` (only when you have a real suspected cause). Use `orderedList` for the steps and `inlineCard` for Slack threads, Zendesk tickets, Sentry issues, admin URLs, Figma frames.

Skeleton:

```jsonc
{
    "type": "doc",
    "version": 1,
    "content": [
        { "type": "heading", "attrs": { "level": 2 }, "content": [{ "type": "text", "text": "Steps to Reproduce" }] },
        { "type": "orderedList", "content": [ /* listItem → paragraph → text + inlineCards */ ] },
        { "type": "heading", "attrs": { "level": 2 }, "content": [{ "type": "text", "text": "Expected Result" }] },
        { "type": "paragraph", "content": [{ "type": "text", "text": "..." }] },
        { "type": "heading", "attrs": { "level": 2 }, "content": [{ "type": "text", "text": "Actual Result" }] },
        { "type": "paragraph", "content": [{ "type": "text", "text": "..." }] },
        { "type": "heading", "attrs": { "level": 2 }, "content": [{ "type": "text", "text": "Technical Findings" }] },
        { "type": "paragraph", "content": [{ "type": "text", "text": "Suspected cause, ruled-out hypotheses, file paths, log links via inlineCard." }] },
    ],
}
```

## Acceptance Criteria ADF — `taskList`

Goes in `customfield_12103`. **1-3 items.** Send with `contentFormat: "adf"`. Plain markdown errors with `Operation value must be an Atlassian Document`.

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
                        { "type": "text", "text": "Outcome 1 — phrase as something a reviewer ticks off." },
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

## Full `createJiraIssue` payload — story / task

```jsonc
{
    "cloudId": "86993857-e7f0-4c29-b941-88d3e688b686",
    "contentFormat": "adf",
    "projectKey": "DEV",
    "issuetype": { "name": "Story" }, // or "Task" for an engineering chore
    "summary": "[FE] Short description",
    "components": [{ "id": "17596" }],
    "customfield_11400": "ec63b0dd-b1fc-47c0-a646-56363181aaf2",
    "customfield_10008": "DEV-147289",
    "description": { /* ADF doc — Links + one sentence */ },
    "customfield_12103": { /* ADF doc with taskList — 1-3 items */ },
}
```

> **Team field (`customfield_11400`):** send the bare UUID **string**, not `{"id": ...}`. Same for Story, Task and Bug — the field schema is identical (`type: team`). Via the `mcp__gateway__atlassian_*` server's `additional_fields`, the object form double-wraps and fails with `Team id 'JsonData{data={id=...}}' is not valid`.

## Full `createJiraIssue` payload — bug

```jsonc
{
    "cloudId": "86993857-e7f0-4c29-b941-88d3e688b686",
    "contentFormat": "adf",
    "projectKey": "DEV",
    "issuetype": { "name": "Bug" },
    "summary": "[Web] Service settings Save button silently fails",
    "components": [{ "id": "17596" }],
    "customfield_11400": "ec63b0dd-b1fc-47c0-a646-56363181aaf2",
    "priority": { "name": "Major" },
    "description": { /* ADF doc — bug layout */ },
}
```

For an update, swap to `editJiraIssue` with the same `fields` shape and `contentFormat: "adf"`.

## Common ADF marks

- `{"type":"code"}` — inline code
- `{"type":"strong"}` — bold
- `{"type":"em"}` — italics
