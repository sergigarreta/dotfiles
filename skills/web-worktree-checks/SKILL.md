---
name: web-worktree-checks
description: "Running web's checks (`t`, `m`, ruff, jest, ESLint, typecheck, prettier, makemessages, lingui:extract) from a git worktree of /workspaces/web. Use after creating a web worktree (git worktree add, EnterWorktree, .claude/worktrees/) and whenever running tests, linters or formatters with cwd outside /workspaces/web."
allowed-tools: Bash, Read, Edit, Grep, Glob
---
# web checks from a worktree

Deltas from main checkout only. Unlisted: run as usual, cwd = worktree.
`$WT` = worktree root, `$MAIN` = `/workspaces/web`.

## Backend

`t <app_or_path>`: works. `cd $WT` first; paths relative to worktree.

**`m` silently runs main's source, writes main's tree.** Only `dc run --no-deps` re-roots onto worktree. Use:

```bash
cd $WT && dc run --rm --no-deps web ./manage.py <command> [args]
```

`up`/`down`/`restart`/`logs` and `run` with deps pinned to main by design.

Check mounted checkout (service mounts subtrees, not repo root):

```bash
cd $WT && dc run --rm --no-deps web ls /web/src/aplaceforrover/<file only this branch has>
```

## ruff

Worktree no `venv/`. Use main's binary (pre-commit-pinned version):

```bash
cd $WT && $MAIN/venv/bin/ruff check src/aplaceforrover/<app>
cd $WT && $MAIN/venv/bin/ruff format --check src/aplaceforrover/<app>
```

## Frontend

Once per worktree (shared store, hardlinks only):

```bash
pnpm -C $WT/src/frontend install --frozen-lockfile --prefer-offline
```

`codeload.github.com` 403: retry `--offline`.

**Never symlink or `--link-dir` main's `node_modules`.** `@rover/*` links relative, imports resolve to main's source: tests pass, worktree changes never load.

**Never `fe`/`fet`**: hardcoded to main checkout. Use pnpm `-C`:

```bash
pnpm -C $WT/src/frontend run test <test file>
pnpm -C $WT/src/frontend run typecheck
pnpm -C $WT/src/frontend run lint:nofix:at_path <paths>   # report only
pnpm -C $WT/src/frontend run lint:nofix:modified          # branch changes
pnpm -C $WT/src/frontend run lint:at_path <paths>         # --fix
```

`This project is configured to use <x> of pnpm`: corepack won't switch. Pin `packageManager` from `src/frontend/package.json`:

```bash
cd $WT/src/frontend && corepack pnpm@<pinned version> run <script>
```

`lint:*` failure prints `UnhandledPromiseRejection ... reason "1"`: cosmetic, exit code correct.

## On demand

- Translations (`makemessages`, `lingui:extract`, `.po` conflicts): never `m makemessages` or `bin/makemessages.sh`. Read [references/translations.md](references/translations.md).
- Formatters fix worktree's copy, not main's: read [references/formatters.md](references/formatters.md).