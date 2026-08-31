---
name: web-worktree-checks
description: "How to run the web repo's checks — backend Django tests (`t`), ruff, jest, ESLint, typecheck, prettier-eslint — from a git worktree of /workspaces/web instead of the main checkout, so a long run does not occupy the tree being edited. Use right after creating a worktree of web (git worktree add, EnterWorktree, or an agent worktree under .claude/worktrees/), and whenever running tests, linters or formatters with a cwd outside /workspaces/web. Covers only what differs from the main checkout: frontend deps must be installed in the worktree, `fe`/`fet` are not worktree-aware, and formatter writes land in the worktree."
allowed-tools: Bash, Read, Edit, Grep, Glob
---

# Running web's checks from a worktree

Everything here is a **delta from the main checkout**. Anything not listed below
behaves identically — run it the way you normally would, with the worktree as cwd.

Let `$WT` be the worktree root and `$MAIN` be `/workspaces/web`.

## Backend: no change needed

`t <app_or_path>` and `m <command>` already follow the worktree. `dc run
--no-deps` (which `t` uses) re-roots onto `git rev-parse --show-toplevel`, and
`docker-compose.worktree.yml` maps back the two generated paths a fresh worktree
lacks — `.snagsby/` and `static/`.

Just `cd $WT` first. Paths you pass are relative to the worktree.

## ruff: use the main venv's binary

`venv/` is gitignored, so a worktree has none. ruff is a standalone binary and
reads config from the cwd, so the main checkout's copy is the correct one — and
it is the version `.pre-commit-config.yaml` pins:

```bash
cd $WT && $MAIN/venv/bin/ruff check src/aplaceforrover/<app>
cd $WT && $MAIN/venv/bin/ruff format --check src/aplaceforrover/<app>
```

## Frontend: install deps once, and never use `fe`/`fet`

**One-time, per worktree.** The store is shared and already populated, so this
hardlinks rather than downloads:

```bash
pnpm -C $WT/src/frontend install --frozen-lockfile --prefer-offline
```

If it fails on `codeload.github.com` 403s (several workspace deps are git-hosted
forks, and the org egress policy has blocked them before), retry with `--offline`
to force store-only resolution.

**Never symlink or `--link-dir` main's `node_modules` in.** pnpm links workspace
packages as *relative* symlinks (`node_modules/@rover/kibble -> ../../kibble`),
so once `node_modules` itself points into main, Node's realpath resolution sends
every `@rover/*` import to **main's** source. Tests pass while the worktree's
changes are never loaded. (`evals/drift-monitoring` does use `--link-dir` — that
is fine for a harness that only needs commands to run, wrong for checking code.)

**`fe` and `fet` are not worktree-aware.** They hardcode `getCurrDir` /
`$CODESPACE_VSCODE_FOLDER`, so they always run the main checkout wherever you
call them from. Drive pnpm directly with `-C`:

```bash
pnpm -C $WT/src/frontend run test <test file>
pnpm -C $WT/src/frontend run typecheck
pnpm -C $WT/src/frontend run lint:nofix:at_path <paths>   # report only
pnpm -C $WT/src/frontend run lint:nofix:modified          # this branch's changes
pnpm -C $WT/src/frontend run lint:at_path <paths>         # with --fix
```

`lint:*` prints `UnhandledPromiseRejection ... reason "1"` on failure. Cosmetic —
the exit code is still correct.

## Formatters write to the worktree, not to what you are editing

`ruff format` and `pnpm exec prettier-eslint --prettier-last --write` (the
formatter behind `fe format`; `cli/commands/formatting/actions.ts` is the source
of truth for its flags) both work in a worktree, but they fix the worktree's
copy of the file. If you are editing in main, carry the diff back:

```bash
git -C $WT diff --binary | git -C $MAIN apply --check -   # verify first
git -C $WT diff --binary | git -C $MAIN apply -
```

If `--check` fails the two trees have diverged; inspect `git -C $WT diff` rather
than force-applying. The worktree still holds the changes afterwards — discard
them there with `git -C $WT checkout -- .`.

Prefer `--check` / `--list-different` / `lint:nofix:*` when the worktree exists
only to report on code being edited elsewhere.
