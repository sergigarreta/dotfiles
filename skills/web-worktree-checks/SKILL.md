---
name: web-worktree-checks
description: "How to run the web repo's checks — backend Django tests (`t`), ruff, jest, ESLint, typecheck, prettier-eslint — from a git worktree of /workspaces/web instead of the main checkout, so a long run does not occupy the tree being edited. Use right after creating a worktree of web (git worktree add, EnterWorktree, or an agent worktree under .claude/worktrees/), and whenever running tests, linters or formatters with a cwd outside /workspaces/web. Also covers extracting translations (`makemessages`, `lingui:extract`) from a worktree. Covers only what differs from the main checkout: `m` and `bin/makemessages.sh` are not worktree-aware, frontend deps must be installed in the worktree, `fe`/`fet` are not worktree-aware, and formatter writes land in the worktree."
allowed-tools: Bash, Read, Edit, Grep, Glob
---

# Running web's checks from a worktree

Everything here is a **delta from the main checkout**. Anything not listed below
behaves identically — run it the way you normally would, with the worktree as cwd.

Let `$WT` be the worktree root and `$MAIN` be `/workspaces/web`.

## Backend tests: no change needed. `m`: broken in a worktree

`t <app_or_path>` follows the worktree. `dc run --no-deps` (which `t` uses)
re-roots onto `git rev-parse --show-toplevel`, and `docker-compose.worktree.yml`
maps back the two generated paths a fresh worktree lacks — `.snagsby/` and
`static/`.

Just `cd $WT` first. Paths you pass are relative to the worktree.

**`m` does not follow the worktree.** `scripts/dc.sh` re-roots only when the
`run` carries `--no-deps`, and `m` is `dc run --rm web ./manage.py` — no
`--no-deps` — so from `$WT` it still executes **main's** source and writes to
main's tree. This is silent: the command succeeds, and the changes appear in
`git -C $MAIN status`. Spell the run out instead:

```bash
cd $WT && dc run --rm --no-deps web ./manage.py <command> [args]
```

Only `dc run --no-deps` re-roots, by design — a `run` with dependencies, and
every stack-lifecycle command (`up`, `down`, `restart`, `logs`), stays pinned to
main so a worktree cannot raise a second stack fighting for the same host ports.

Confirming which checkout is mounted needs a path the `web` service actually
mounts — it mounts subtrees (`./config`, `./src/aplaceforrover`, `./bin`, …), not
the repo root, so a marker file at the root is invisible either way:

```bash
cd $WT && dc run --rm --no-deps web ls /web/src/aplaceforrover/<a file only this branch has>
```

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

If it fails on the corepack version check, see the note further down and use
`corepack pnpm@<pinned version> install` instead. If it fails on `codeload.github.com` 403s (several workspace deps are git-hosted
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

`pnpm` under corepack will not switch versions, so a direct `pnpm` call can fail
with `This project is configured to use <x> of pnpm. Your current pnpm is <y>`.
Name the pinned version — it is `packageManager` in `src/frontend/package.json`:

```bash
cd $WT/src/frontend && corepack pnpm@<pinned version> run <script>
```

`lint:*` prints `UnhandledPromiseRejection ... reason "1"` on failure. Cosmetic —
the exit code is still correct.

## Translations: run the underlying commands, not the wrappers

Both wrappers are unusable from a worktree, for different reasons.

**`m makemessages` runs against main** (see above), and refuses anyway without
`--force`, pointing at `bin/makemessages.sh`.

**`bin/makemessages.sh` runs `git` against the tree mid-script** —
`bin/outdated_po_files.sh -i | xargs git checkout --`, to drop no-op catalog
churn — and it also runs its own extraction through `dc run` without
`--no-deps`, so it hits main. Do not run it while resolving a `.po` conflict.
Observed once on 2026-08-31: after it ran inside a conflicted merge, the
following `git commit` produced a **single-parent** commit carrying master's
whole tree instead of a merge commit, so the branch showed thousands of master
files as its own diff. Path-form `git checkout` alone does not clear
`MERGE_HEAD` (verified separately), so the exact trigger is unconfirmed — treat
it as a reason to avoid the wrapper here, and to check before committing a
merge:

```bash
git -C $WT rev-parse -q --verify MERGE_HEAD   # must print a SHA
# and after committing
git -C $WT rev-parse HEAD^2                   # must resolve
```

Extract backend strings with the management command directly, limiting the work
to the app locale dirs your branch touched:

```bash
cd $WT
FILES=$(git diff --name-only origin/master...HEAD -- src/aplaceforrover/ \
  | grep '\.py$' | sed 's/^/--file /' | tr '\n' ' ')
dc run --rm --no-deps web ./manage.py makemessages --force $FILES
```

`--force` is required (Rover's override blocks a bare invocation), and `--file`
takes paths relative to the repo root, repeated per file. Without any `--file`
it re-extracts every locale dir in the repo and produces churn far beyond the
branch. Deleted files count: pass them too, so the app's catalog is rebuilt
without their strings.

Frontend catalogs are a plain pnpm script — no `dc` involved, so the worktree is
whatever `-C` points at:

```bash
pnpm -C $WT/src/frontend run lingui:extract
```

Reviewing the result, per locale: a moved msgid keeps its `msgstr`, so non-empty
`-msgstr` lines should only ever be strings the branch genuinely deleted.

```bash
git -C $WT diff -- 'src/aplaceforrover/**/*.po' | grep '^[+-]msgid' | sort | uniq -c
git -C $WT diff -- 'src/aplaceforrover/**/*.po' | grep '^-msgstr' | grep -v 'msgstr ""$'
```

### Resolving a `.po` conflict

Catalogs are generated, so never hand-merge the hunks. Take one side wholesale
and re-extract on top — master's side, since it is the one already rebuilt for
whatever strings master added or removed:

```bash
cd $WT && git merge origin/master        # conflicts land in the .po files
git checkout origin/master -- 'src/aplaceforrover/i18n/locale/*/LC_MESSAGES/django.po'
dc run --rm --no-deps web ./manage.py makemessages --force $FILES
git add -A src/aplaceforrover/i18n && git commit
```

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
