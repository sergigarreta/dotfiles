---
name: jira-branch-naming
description: "Naming a git branch for a Jira ticket — the branch name is the ticket key alone (DEV-156481), never the key plus the ticket title. Use whenever creating or renaming a branch: `git checkout -b`, `git switch -c`, `git branch <name>`, `git branch -m`, or a request like \"make a branch for DEV-…\" / \"start work on DEV-…\". Also covers branches with no ticket, and when several branches are needed for one ticket."
allowed-tools: Bash
---

# Jira branch naming

## The rule

The branch name is the ticket key and nothing else — namespace and number.

```bash
git checkout -b DEV-156481        # yes
```

```bash
git checkout -b DEV-156481-locked-rates-only-when-cheaper       # no — title slug
git checkout -b sergi.garreta/DEV-156481                        # no — user prefix
```

No title slug, no `sergi.garreta/` prefix, no suffix.

## Why

GitHub's Jira integration links the branch to the ticket off the key alone, so
nothing else in the name earns its keep. The title already lives in Jira and in
the PR title; repeating it makes every ref long to type and leaves it stale the
moment the ticket is retitled.

## Deriving the name

Take the key from the ticket the work is for. Never build a slug from the
ticket summary. If no key is known yet, ask for it rather than inventing a
descriptive name — a branch that should have carried a key and doesn't is worse
than a moment's delay.

## Branches with no ticket

The rule bites only when a key is present. Keyless work keeps whatever
descriptive name reads well — `DEV-noticket-codespaces-pr-permissions`,
`worktree-codespaces-pr-permissions`.

## Several branches for one ticket

Splitting a ticket across branches is fine, and then a suffix names the *scope*
of the split — never the ticket title:

```bash
git checkout -b DEV-153786-backend
git checkout -b DEV-153786-gallery
```

Only when more than one branch genuinely exists. A single branch takes the bare
key.

## Related

Creating or checking out a ticket's branch is a "work starts" moment for
`owner-retention-ticket-lifecycle` — assign the ticket and move it to
In Progress at the same time.
