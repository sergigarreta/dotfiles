# Translations from a worktree

Both wrappers unusable from worktree.

- **`m makemessages`** runs against main (see SKILL.md), refuses without `--force` anyway.
- **`bin/makemessages.sh`** runs `git checkout --` on tree mid-script, extracts via `dc run` without `--no-deps` (hits main). Never run while resolving `.po` conflict: once (2026-08-31) next `git commit` came out single-parent, carrying master's whole tree. Trigger unconfirmed. Before and after committing merge:

```bash
git -C $WT rev-parse -q --verify MERGE_HEAD   # before commit: must print a SHA
git -C $WT rev-parse HEAD^2                   # after commit: must resolve
```

## Backend strings

Extract only from files branch touched (deleted files included, so their strings drop out):

```bash
cd $WT
FILES=$(git diff --name-only origin/master...HEAD -- src/aplaceforrover/ \
  | grep '\.py$' | sed 's/^/--file /' | tr '\n' ' ')
dc run --rm --no-deps web ./manage.py makemessages --force $FILES
```

`--force` required (Rover override blocks bare invocation). `--file` paths repo-root-relative, one per file. No `--file` re-extracts every locale dir: churn far beyond branch.

## Frontend strings

```bash
pnpm -C $WT/src/frontend run lingui:extract
```

## Review

Moved msgid keeps `msgstr`, so non-empty `-msgstr` lines must only be strings branch deleted:

```bash
git -C $WT diff -- 'src/aplaceforrover/**/*.po' | grep '^[+-]msgid' | sort | uniq -c
git -C $WT diff -- 'src/aplaceforrover/**/*.po' | grep '^-msgstr' | grep -v 'msgstr ""$'
```

## `.po` conflict

Generated files: never hand-merge. Take master's side, re-extract on top:

```bash
cd $WT && git merge origin/master
git checkout origin/master -- 'src/aplaceforrover/i18n/locale/*/LC_MESSAGES/django.po'
dc run --rm --no-deps web ./manage.py makemessages --force $FILES
git add -A src/aplaceforrover/i18n && git commit
```
