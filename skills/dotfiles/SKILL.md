---
name: dotfiles
description: "Manage the personal dotfiles repo at /workspaces/.codespaces/.persistedshare/dotfiles (sergigarreta/dotfiles) — the source of install.sh, personal.py, setup-claude-dev.sh, the claude/ directory holding Claude Code settings and permission allowlist, and the personal Claude skills symlinked into ~/.claude/skills. Use when adding, editing or removing a personal skill, allowlisting a command so Claude stops asking permission for it, changing Claude Code settings or MCP/plugin setup, changing codespace setup/install steps, or committing and pushing dotfiles changes. Pushing needs the DOTFILES_REPO_TOKEN PAT, which must never be printed, echoed, or written to a file."
allowed-tools: Bash(git:*), Bash(ls:*), Bash(cat:*), Bash(mkdir:*), Bash(ln:*), Bash(rm:*), Bash(sed:*), Bash(grep:*), Bash(bash:*), Read, Write, Edit
---

# Managing the dotfiles repo

## Layout

| Path | What it is |
|------|-----------|
| `/workspaces/.codespaces/.persistedshare/dotfiles` | the clone (call it `$DOTFILES`); remote `https://github.com/sergigarreta/dotfiles`, branch `main` |
| `install.sh` | runs once per codespace creation; the top-level orchestrator (personal.py, wiki, push auth, VSCode task) |
| `claude/settings.json` | **declarative** Claude Code user settings — model, env, `permissions.allow`. Edit this to change Claude config |
| `claude/merge-settings.jq` | deep-merge filter that applies the fragment above into `~/.claude/settings.json` |
| `claude/install.sh` | applies the settings fragment, links skills, installs plugins, registers MCP servers |
| `personal.py` | Django settings copied into `web/src/aplaceforrover/rover/settings/personal.py` |
| `setup-claude-dev.sh` | on-demand VSCode task (surface dotfiles + rover-plugins repos) |
| `skills/<name>/SKILL.md` | personal Claude skills, symlinked to `~/.claude/skills/<name>` by `claude/install.sh` |

`~/.claude/skills/<name>` are **symlinks into this repo**, so editing either path
edits the repo. `~/.claude/skills/llm-wiki` is the exception — it points into
`/workspaces/wiki` and is versioned in the wiki repo, not here.

Always work from a shell variable, never retype the path:

```bash
DOTFILES=/workspaces/.codespaces/.persistedshare/dotfiles
```

## Changing Claude Code config

All of it lives under `claude/`. Prefer the declarative file over the script:

- **A setting or permission rule** → edit `claude/settings.json`. It is merged,
  not copied, into `~/.claude/settings.json`: objects merge key by key, arrays
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

- It runs with `set -e` on a **fresh** codespace, and is also re-run by hand — so
  every step must be idempotent (guard with `if [ ! -d ... ]`, `jq` filters that
  drop an existing entry before re-adding it, `any(.label == ...)` checks).
- A missing secret must warn and continue, not abort the whole setup.
- Never write a secret into a file it creates. Tokens are supplied by
  environment-reading credential helpers (see below).

## Committing and pushing (uses DOTFILES_REPO_TOKEN)

Every change to this repo ends here. Editing a file is half the job — the repo is
the only thing that persists across codespaces, so commit and push before
reporting the work done.

`DOTFILES_REPO_TOKEN` is a fine-grained GitHub PAT (Contents: read+write on
`sergigarreta/dotfiles`), delivered as a Codespaces secret. The codespace's own
`GITHUB_TOKEN` is scoped to roverdotcom repos and **cannot** push here.

`install.sh` already configured this clone's URL-scoped credential helper to read
the token from the environment at call time:

```
credential.https://github.com.helper=!f() { echo username=x-access-token; echo "password=$DOTFILES_REPO_TOKEN"; }; f
```

So the token never lands in `.git/config`, `~/.git-credentials`, or the remote
URL — and it does not need to. **Just run git normally:**

```bash
git -C "$DOTFILES" add -A
git -C "$DOTFILES" commit -m "<message>"
git -C "$DOTFILES" push
```

### Handling the token — hard rules

- **Never print, echo, `env`-dump, log, or interpolate the token.** Do not run
  `echo $DOTFILES_REPO_TOKEN`, `env | grep DOTFILES`, or embed it in a remote
  URL like `https://x-access-token:$TOKEN@github.com/...` — that value would be
  written to `.git/config` and shown in `git remote -v`.
- To check whether it exists, test emptiness only:
  `[ -n "${DOTFILES_REPO_TOKEN:-}" ] && echo present || echo missing`
- If output could contain a URL with credentials, redact it:
  `git -C "$DOTFILES" remote -v | sed -E 's#https://[^@]*@#https://***@#'`
- Never copy the token into another repo, a script, an MCP call, a Jira ticket,
  or a PR body.

### If the push fails

1. Confirm the secret is present (emptiness test above). If missing: it must be
   added at <https://github.com/settings/codespaces> and the codespace restarted
   — a secret is only injected at container start.
2. Confirm the helper is configured, redacting as you print:

   ```bash
   git -C "$DOTFILES" config --local --get-all credential.https://github.com.helper | sed -E 's#\$DOTFILES_REPO_TOKEN#<env>#'
   ```

   If it is absent, re-add it — note the empty value first, which resets the
   inherited `gh auth git-credential` helper from `~/.gitconfig` (a URL-scoped
   helper always beats a generic one, so setting plain `credential.helper` is
   silently ignored):

   ```bash
   git -C "$DOTFILES" config credential.https://github.com.helper ""
   git -C "$DOTFILES" config --add credential.https://github.com.helper \
     '!f() { echo username=x-access-token; echo "password=$DOTFILES_REPO_TOKEN"; }; f'
   ```
3. A 403 with the helper present and the secret set means the PAT lacks
   **Contents: read and write** on `sergigarreta/dotfiles`, or has expired — the
   user has to fix it in GitHub settings; nothing here can work around it.

## Applying changes

- Skill edits: live immediately via the symlink; effective next session.
- `install.sh` changes: `bash "$DOTFILES/install.sh"` re-runs it in place
  (idempotent), or they apply on the next codespace creation.
- Claude config: `bash "$DOTFILES/claude/install.sh"` applies just that part
  without re-running the wiki clone or plugin installs above it.
- `personal.py` changes: re-run `install.sh`, or copy it to
  `/workspaces/web/src/aplaceforrover/rover/settings/personal.py` directly.

## Conventions

- Small, focused commits with an imperative subject line; no PR needed — commit
  straight to `main` and push.
- **Always commit and push as part of the task** — an edit left in the working
  tree does not survive a codespace rebuild, so an uncommitted change has not
  been delivered. Do not ask first, and do not stop at "edited, want me to
  push?"; finish the edit, commit it, push it, and report the pushed SHA.
- `git -C "$DOTFILES" pull --rebase --autostash` before pushing if the remote has
  moved (another codespace may have pushed).
