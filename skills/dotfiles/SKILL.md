---
name: dotfiles
description: "Manage the personal dotfiles repo at ~/.config/coderv2/dotfiles (sergigarreta/dotfiles) — the source of install.sh, personal.py, the claude/ directory holding Claude Code settings and permission allowlist, and the personal Claude skills symlinked into ~/.claude/skills. Use when adding, editing or removing a personal skill, allowlisting a command so Claude stops asking permission for it, changing Claude Code settings or MCP/plugin setup, changing codespace setup/install steps, or committing and pushing dotfiles changes. Pushing needs the DOTFILES_REPO_TOKEN PAT, which must never be printed, echoed, or written to a file."
allowed-tools: Bash(git:*), Bash(ls:*), Bash(cat:*), Bash(mkdir:*), Bash(ln:*), Bash(rm:*), Bash(sed:*), Bash(grep:*), Bash(bash:*), Read, Write, Edit
---

# Managing the dotfiles repo

## Layout

| Path | What it is |
|------|-----------|
| `~/.config/coderv2/dotfiles` | the clone (call it `$DOTFILES`); remote `https://github.com/sergigarreta/dotfiles`, branch `roverspaces` (`main` is the GitHub Codespaces setup) |
| `lib/env.sh` | sourced by every script; resolves `DOTFILES_DIR`, `CLAUDE_HOME` (`$CLAUDE_CONFIG_DIR`) and `MACHINE_ID` |
| `install.sh` | runs on every workspace start; the top-level orchestrator (personal.py, Claude setup, wiki, push auth, Statsig) |
| `claude/settings.json` | **declarative** Claude Code user settings — model, env, `permissions.allow`. Edit this to change Claude config |
| `claude/merge-settings.jq` | deep-merge filter that applies the fragment above into `$CLAUDE_CONFIG_DIR/settings.json` |
| `claude/install.sh` | applies the settings fragment, links skills, installs plugins, registers MCP servers |
| `personal.py` | Django settings copied into `web/src/aplaceforrover/rover/settings/personal.py` |
| `statsig-register-workspace.sh` | run by `install.sh`; adds `$MACHINE_NAME` to the Statsig segment `sergi_garreta_codespaces` via the Console API |
| `skills/<name>/SKILL.md` | personal Claude skills, symlinked to `~/.claude/skills/<name>` by `claude/install.sh` |

`~/.claude/skills/<name>` are **symlinks into this repo**, so editing either path
edits the repo. `~/.claude/skills/llm-wiki` is the exception — it points into
`/workspaces/wiki` and is versioned in the wiki repo, not here.

Always work from a shell variable, never retype the path:

```bash
DOTFILES=~/.config/coderv2/dotfiles
```

## Changing Claude Code config

All of it lives under `claude/`. Prefer the declarative file over the script:

- **A setting or permission rule** → edit `claude/settings.json`. It is merged,
  not copied, into `$CLAUDE_CONFIG_DIR/settings.json`: objects merge key by key, arrays
  union, scalars overwrite. Unioned arrays are what keep the wiki's hooks and any
  rule the user added via `/permissions` from being dropped, and what make a
  re-run a no-op.
- **A plugin, MCP server, or other imperative step** → edit `claude/install.sh`.

Permission rules match the **literal Bash command string**, prefix-only — `:*`
allows any trailing args. So the alias matters, not what it expands to:
`m makemessages` and `./bin/makemessages.sh` are separate rules. There is no
mid-string wildcard, so each spelling a command is invoked by needs its own entry
(`bin/x.sh` and `./bin/x.sh` both).

Claude Code checks each segment of a compound command separately, so a pipeline
like `./bin/makemessages.sh 2>&1 | tail -15` needs `tail` allowed too before it
runs unprompted. Broad utility rules like `Bash(tail:*)` or `Bash(cd:*)` are for
the user to add via `/permissions` — the auto-mode classifier blocks Claude from
granting itself those.

Apply without a rebuild:

```bash
bash "$DOTFILES/claude/install.sh"
```

Settings take effect on the next session.

## Adding or editing a skill

1. Create `$DOTFILES/skills/<name>/SKILL.md` with YAML frontmatter — `name`
   (kebab-case, matching the directory), `description` (one line, written so the
   model can tell when it applies), and optionally `allowed-tools`,
   `argument-hint`, `model`, `effort`, `disable-model-invocation`. Look at
   `skills/daily-standup/SKILL.md` for the house style.
2. Symlink it so it is live in this session without re-running `install.sh`:

   ```bash
   ln -sfn "$DOTFILES/skills/<name>" "$HOME/.claude/skills/<name>"
   ```

   `install.sh` already loops over `skills/*/` and relinks everything, so no
   install.sh edit is needed for a new skill.
3. Removing a skill means deleting both the directory and
   `~/.claude/skills/<name>` (the loop only creates links, it never prunes).

Newly added or edited skills are picked up on the next Claude Code session.

## Editing install.sh

- Coder runs it with `set -e` on **every** workspace start, and it is also re-run by hand, so
  every step must be idempotent (guard with `if [ ! -d ... ]`, `jq` filters that
  drop an existing entry before re-adding it, `any(.label == ...)` checks).
- A missing secret must warn and continue, not abort the whole setup.
- Never write a secret into a file it creates. Tokens are supplied by
  environment-reading credential helpers (see below).

## Committing and pushing

Every change to this repo ends here. Editing a file is half the job: the repo is
the only thing that persists across Roverspaces, so commit and push before
reporting the work done.

The Roverspace's GitHub login (`gh auth git-credential`, from `~/.gitconfig`)
can push to `sergigarreta/dotfiles`, so **just run git normally**:

```bash
git -C "$DOTFILES" add -A
git -C "$DOTFILES" commit -m "<message>"
git -C "$DOTFILES" push
```

If `DOTFILES_REPO_TOKEN` is set (a Coder user secret), `install.sh` configures
this clone's URL-scoped credential helper to read it from the environment at call
time, so the token never lands in `.git/config` or the remote URL.

### Handling tokens — hard rules

- **Never print, echo, `env`-dump, log, or interpolate a token.** Do not embed
  one in a remote URL like `https://x-access-token:$TOKEN@github.com/...`; that
  value would be written to `.git/config` and shown in `git remote -v`.
- To check whether one exists, test emptiness only:
  `[ -n "${DOTFILES_REPO_TOKEN:-}" ] && echo present || echo missing`
- Never copy a token into another repo, a script, an MCP call, a Jira ticket,
  or a PR body.
- The same rules apply to `SERGI_STATSIG_CONSOLE_API_KEY`, the Statsig Console API key
  used by `statsig-register-workspace.sh`. It can edit the whole Statsig project.

### Secrets on Roverspaces

Secrets are Coder user secrets, set from any machine logged in with `coder login`
and injected on the next workspace start:

```bash
printf %s "$VALUE" | coder secret create <name> --env <ENV_VAR_NAME>
```

### If the push fails

1. `gh auth status` must show the Roverspace login. A 403 means that login (or
   `DOTFILES_REPO_TOKEN`, if set) lacks **Contents: read and write** on
   `sergigarreta/dotfiles`; the user has to fix it in GitHub.

## Applying changes

- Skill edits: live immediately via the symlink; effective next session.
- `install.sh` changes: `bash "$DOTFILES/install.sh"` re-runs it in place
  (idempotent), or they apply on the next workspace start.
- Claude config: `bash "$DOTFILES/claude/install.sh"` applies just that part
  without re-running the wiki clone or plugin installs above it.
- `personal.py` changes: re-run `install.sh`, or copy it to
  `/workspaces/web/src/aplaceforrover/rover/settings/personal.py` directly.

## Conventions

- Small, focused commits with an imperative subject line; no PR needed — commit
  straight to `roverspaces` and push.
- **Always commit and push as part of the task** — an edit left in the working
  tree does not survive a Roverspace rebuild, so an uncommitted change has not
  been delivered. Do not ask first, and do not stop at "edited, want me to
  push?"; finish the edit, commit it, push it, and report the pushed SHA.
- `git -C "$DOTFILES" pull --rebase --autostash` before pushing if the remote has
  moved (another Roverspace may have pushed).
