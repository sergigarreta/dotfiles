# Formatter writes land in the worktree

`ruff format` and `pnpm exec prettier-eslint --prettier-last --write` (behind `fe format`; flags in `cli/commands/formatting/actions.ts`) fix worktree copy. Editing in main? Carry diff back:

```bash
git -C $WT diff --binary | git -C $MAIN apply --check -   # verify first
git -C $WT diff --binary | git -C $MAIN apply -
git -C $WT checkout -- .                                  # then discard in worktree
```

`--check` fails: trees diverged. Inspect `git -C $WT diff`, never force-apply.

Worktree only reporting on code edited elsewhere? Prefer `--check` / `--list-different` / `lint:nofix:*`.