---
name: daily-standup
description: "Prepare notes for the daily standup / daily scrum meeting. Gathers what *you* did on the last working day from Jira and GitHub: status changes on Jira tickets assigned to you, and open pull requests you authored or reviewed. Use this whenever the user asks to 'prep my standup', 'what did I do yesterday', 'daily meeting notes', 'standup prep', 'daily scrum', or any morning-status-recap request — even if they don't name Jira or GitHub explicitly. Defaults to the previous working day (Friday when run on a Monday) but the user can override the date."
allowed-tools: Bash(date:*), Bash(gh:*), Bash(acli:*), Bash(.claude/skills/atlassian-cli/scripts/ensure-auth.sh:*)
---

# Daily Standup Prep

Goal: produce a tight, read-aloud-able recap of what the user did on the **last
working day**, pulled from Jira and GitHub. The output is for *them* to glance at
before standup — so favor signal over completeness, and group it so they can
speak it in order.

## 1. Determine the reporting day

Standup recaps cover the previous working day. Most days that is yesterday, but
on a **Monday** the previous working day is **Friday** — and the same logic
handles weekends (skip back to the most recent weekday).

If the user gave a date (e.g. "prep standup for June 3" or "...for last
Thursday"), use that instead — their override always wins.

Otherwise compute the most recent weekday strictly before today:

```bash
d=1
while :; do
  cand=$(date -d "-$d day" +%u)   # 1=Mon .. 7=Sun
  [ "$cand" -le 5 ] && break
  d=$((d + 1))
done
DAY=$(date -d "-$d day" +%F)      # YYYY-MM-DD, the reporting day
echo "Reporting day: $DAY"
```

State the reporting day in the final output so the user can sanity-check it.

## 2. Jira — status changes on my tickets

What we want: tickets **assigned to me** whose **status changed** during the
reporting day, and *what* the transition was (from → to). A ticket the user moved
across the board is the core of a standup.

Use the `atlassian-cli` skill (run its `ensure-auth.sh` first), then search with a
date-bounded JQL window. JQL's `DURING` takes a datetime range:

```bash
.claude/skills/atlassian-cli/scripts/ensure-auth.sh

acli jira workitem search \
  --jql "assignee = currentUser() AND status CHANGED DURING (\"$DAY 00:00\", \"$DAY 23:59\")" \
  --json
```

That returns the matching tickets but **not** the transition detail. To report
"In Progress → In Review", fetch each ticket's changelog and keep only history
entries from the reporting day. The REST API exposes it via `expand=changelog`
(this uses `curl`, which the atlassian-cli skill notes is **not** auto-approved —
the user will be prompted once):

```bash
curl -s -u "${ATLASSIAN_EMAIL}:${ATLASSIAN_AUTH_TOKEN}" \
  "${ATLASSIAN_URL}rest/api/3/issue/DEV-12345?expand=changelog&fields=summary,status" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
day = '$DAY'
for h in d.get('changelog', {}).get('histories', []):
    if not h.get('created', '').startswith(day):
        continue
    for item in h['items']:
        if item['field'] == 'status':
            print(f\"{item['fromString']} -> {item['toString']}\")
"
```

If the changelog fetch is declined or unavailable, fall back to reporting the
ticket's **current** status only — still useful, just less precise.

## 3. GitHub — open PRs I authored or reviewed

What we want: PRs **not closed** (open, includes drafts) that the user **authored**
or **reviewed**, with activity on the reporting day. Use the `github-cli` skill
conventions. `gh search prs` supports `--author`, `--reviewed-by`, `--state`, and
an `updated:` date qualifier — that date qualifier is how we scope to the
reporting day.

```bash
# Authored, still open, touched on the reporting day
gh search prs --author @me --state open --updated "$DAY" \
  --json number,title,url,repository,isDraft

# Reviewed by me, still open, touched on the reporting day
gh search prs --reviewed-by @me --state open --updated "$DAY" \
  --json number,title,url,repository
```

A PR you authored may also show under reviewed-by — **dedupe by PR number**, and
when a PR appears in both, list it only under *authored*. Mark drafts as
`(draft)`.

## 4. Output format

Use this structure. Omit a section's bullets and write `_(none)_` when empty —
don't drop the heading, so the user knows it was checked. Keep each bullet to one
line; lead with the ticket key / PR number so it scans fast.

```markdown
## Standup — last working day: <DAY>

### Jira (assigned to me)
- DEV-12345 <summary>: In Progress → In Review
- DEV-67890 <summary>: To Do → In Progress

### PRs authored (open)
- #94821 <title> — <repo>, (draft) if applicable

### PRs reviewed (open)
- #95515 <title> — <repo>
```

Keep it terse. This is a glance-and-speak artifact, not a report — no preamble, no
summary paragraph, just the three sections.
