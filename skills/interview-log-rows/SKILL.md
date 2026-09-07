---
name: interview-log-rows
description: "Build the rows the user is missing from the \"Interviews log\" tab of the BCN Tech Interviewers Google Sheet. Reconstructs each interview the user sat on from their Google Calendar (date, panel partner, Lever feedback link), checks the #loop-* Slack channels for calibration/debrief context, and emits a paste-ready table. Use for \"add my interviews to the interview log\", \"log last week's interviews\", \"which interviews am I missing from the sheet\"."
argument-hint: "[date range, e.g. 'last Friday' or 'since June']"
arguments: range
disable-model-invocation: true
allowed-tools: Bash(date:*), mcp__gateway__google-workspace_read_sheet_values, mcp__gateway__google-workspace_get_spreadsheet_info, mcp__gateway__google-workspace_get_events, mcp__gateway__slack_slack_search_channels, mcp__gateway__slack_slack_read_channel, mcp__gateway__slack_slack_search_public_and_private
---

# Interview log rows

Goal: hand the user a table they can paste straight into the interview log,
covering every interview they sat on in the requested window and no others.

## The spreadsheet

- **BCN Tech Interviewers** — `1u9i_b6l1R4a10dvECDhj5vQOJKizq7Cnlcajn0PR6yc`
- Tab **"Interviews log"**, gid `1874193337`

Columns, in order:

| Col | Header | Value |
|-----|--------|-------|
| A | `leve` (really the date) | `Jun 16`, `Jul 3` — month abbreviation + day, no year |
| B | Tenured interviewer | the panel partner (see below) |
| C | Shadow | |
| D | Reverse shadow | |
| E | Interview Type | `Coding`, `TPS (Kata)` or `System design` — never the literal word "Interview" |
| F | Interview feedback link | `https://hire.lever.co/interviews/<uuid>` |
| G | Post-Interview Calibration? | `Yes` / `No` |
| H | Notes | leave empty |

Read the tab first to confirm the layout has not drifted and to see which dates
are already logged — never add a row that is already there.

## 1. Find the interviews

Search the user's primary calendar over the window. The invites are titled
`Coding Interview Loop - <candidate> - <role>`, organized by
`recruiting_calendar@rover.com`:

```
get_events(query="Loop", time_min=..., time_max=..., detailed=true)
```

`detailed=true` matters — everything needed is in the description body:

- **Itinerary lines** give the pairing, e.g.
  `2:00PM (CEST) - 3:00PM (CEST): Sergi Garreta and Gabriel Thibeault Lüthy`.
  The other name in the user's slot is the panel partner.
- **`View resume and feedback:`** is followed by the
  `https://hire.lever.co/interviews/<uuid>` URL — that is column F. Do not use
  the `hire.lever.co/candidates/...` URL or the GoodTime `Resume - ...` URL.

Only include interviews that have **already happened**. Scheduled-but-future
loops are not logged.

## 2. Cross-check Slack, and drop phantoms

The user is in the private `#loop-*` channels (`slack_search_channels` with
`channel_types=public_channel,private_channel`, query `loop`). GoodTime posts a
schedule per candidate naming every interviewer pair.

Use these to catch the failure mode: **a GoodTime post can name the user for a
slot that was later rescheduled onto a different panel.** The calendar is the
source of truth — if a Slack-announced slot has no matching calendar event,
the user did not sit that interview. Exclude it and say why.

## 3. Calibration column

`Post-Interview Calibration?` is the *tenured-with-shadow* calibration, not the
full-panel **debrief**. The Slack channels only ever discuss debriefs, so there
is normally no evidence either way — leave column G blank for the user, and
report what Slack did say. Known standing arrangement: calibrations are not
scheduled centrally, the pair arranges them directly
(Marc Saborit, `#loop-e2-acceleration`, 2026-06-15: "please align yourselves
directly").

Debrief cancellations ("cancelling today's debrief given the scoring") are a
different meeting — mention them separately, never in column G.

## 4. Who is tenured, who is shadowing

The user's own role changes as they progress: shadow first, then reverse shadow,
then tenured. The calendar cannot tell these apart — both names just appear in
the itinerary. So:

- Put the **panel partner** in column B (Tenured interviewer).
- Put the **user** in column C or D depending on the phase they were in on that
  date, and if the phase boundary is not known, leave C and D empty and let the
  user fill them.
- Ask once for the cutover date rather than guessing per row.

## 5. Output

Default to printing a markdown table in chat for the user to copy — do **not**
write to the spreadsheet unless they ask. If they do ask, append below the last
populated row; never overwrite.

Put the user's **email address**, not their display name, in whichever of C/D
they occupy. Pasted plain text stays plain text, so tell them how to turn it
into a people chip afterwards:

- select the pasted column, then **Insert > Smart chips > Convert to people
  chip** (also on the right-click menu), or
- for a single cell, paste the address and press **Tab**.

Typing `@name` works when filling a cell by hand, but survives neither a paste
nor an API write.
