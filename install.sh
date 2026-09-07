#!/bin/bash

# Dotfiles installation script for GitHub Codespaces
# This script sets up the development environment for the Rover project

set -e

echo "Setting up Rover development environment..."

DOTFILES_DIR=/workspaces/.codespaces/.persistedshare/dotfiles

# Copy personal.py settings to the web project
echo "Copying personal.py to web project..."
cp /workspaces/.codespaces/.persistedshare/dotfiles/personal.py /workspaces/web/src/aplaceforrover/rover/settings/personal.py

# Claude Code setup — settings, plugins, skills, MCP servers. Split out so the
# config that changes often lives in one place: claude/settings.json is the
# declarative part, claude/install.sh applies it. Must run before the wiki block,
# which merges its hooks into the settings file this creates.
echo "Setting up Claude Code..."
bash "$DOTFILES_DIR/claude/install.sh"

# Set up the personal research wiki (Karpathy LLM Wiki pattern). It is a separate
# private repo so it can also be cloned outside this codespace; this clone is the
# codespace-side copy.
#
# Auth needs the WIKI_REPO_TOKEN Codespaces secret (fine-grained PAT on
# sergigarreta/llm-wiki, Contents: read+write). The codespace's own GITHUB_TOKEN
# cannot reach personal repos — it is scoped to the roverdotcom repos listed in
# web/.devcontainer/devcontainer.json.
echo "Setting up research wiki..."
WIKI=/workspaces/wiki
CLAUDE_SETTINGS=~/.claude/settings.json
# The credential helper reads the token from the environment at call time, so the
# PAT is never written to .git/config or ~/.git-credentials. It must be set on the
# URL-scoped key: ~/.gitconfig points credential.https://github.com.helper at
# `gh auth git-credential`, and a URL-scoped helper always beats a generic one, so
# setting plain credential.helper here would be silently ignored. The empty value
# first resets the inherited helper list.
WIKI_CRED_HELPER='!f() { echo username=x-access-token; echo "password=$WIKI_REPO_TOKEN"; }; f'
if [ -z "${WIKI_REPO_TOKEN:-}" ]; then
  echo "WIKI_REPO_TOKEN not set — skipping wiki setup. Add it at https://github.com/settings/codespaces and restart." >&2
else
  if [ ! -d "$WIKI/.git" ]; then
    git -c credential.https://github.com.helper= \
        -c credential.https://github.com.helper="$WIKI_CRED_HELPER" \
        clone https://github.com/sergigarreta/llm-wiki "$WIKI" || \
      echo "wiki clone failed — check the PAT's Contents permission." >&2
  fi
  if [ -d "$WIKI/.git" ]; then
    git -C "$WIKI" config credential.https://github.com.helper ""
    git -C "$WIKI" config --add credential.https://github.com.helper "$WIKI_CRED_HELPER"
    git -C "$WIKI" pull --rebase --autostash --quiet || true

    # Skill symlinked out of the wiki repo, so the procedures are versioned with
    # the wiki they operate on.
    rm -rf "$HOME/.claude/skills/llm-wiki"
    ln -s "$WIKI/.claude/skills/llm-wiki" "$HOME/.claude/skills/llm-wiki"

    # Load the wiki schema into every session in the web repo only.
    # CLAUDE.local.md is already gitignored by web (.gitignore), so this leaves no
    # diff in the shared repo. The import resolves outside the working directory,
    # so Claude Code asks for approval the first time — accept it once.
    if [ -d /workspaces/web ] && ! grep -q '@/workspaces/wiki/WIKI.md' /workspaces/web/CLAUDE.local.md 2>/dev/null; then
      printf '# Personal\n\n@/workspaces/wiki/WIKI.md\n' >> /workspaces/web/CLAUDE.local.md
    fi

    # SessionStart pulls the wiki and reports its state; Stop commits and pushes
    # any changes. Merged with jq so model/enabledPlugins/marketplaces survive,
    # and filtered first so re-running install.sh does not duplicate the entries.
    if command -v jq >/dev/null 2>&1; then
      jq '.hooks.SessionStart = ((.hooks.SessionStart // []) | map(select(.hooks[0].command != "/workspaces/wiki/bin/wiki-session-start.sh")) + [{hooks:[{type:"command",command:"/workspaces/wiki/bin/wiki-session-start.sh"}]}])
        | .hooks.Stop = ((.hooks.Stop // []) | map(select(.hooks[0].command != "/workspaces/wiki/bin/wiki-sync.sh")) + [{hooks:[{type:"command",command:"/workspaces/wiki/bin/wiki-sync.sh"}]}])' \
        "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
    fi
    echo "Research wiki ready at $WIKI."
  fi
fi

# Make this dotfiles clone pushable. Codespaces clones it with the codespace's
# own GITHUB_TOKEN, which is scoped to the roverdotcom repos in
# web/.devcontainer/devcontainer.json and cannot write a personal repo, so
# commits here fail to push without a PAT.
#
# Same pattern as the wiki above: the helper reads the token from the
# environment at call time, so the PAT never lands in .git/config or
# ~/.git-credentials, and it must go on the URL-scoped key because
# ~/.gitconfig's URL-scoped `gh auth git-credential` helper beats a generic one.
echo "Configuring dotfiles push auth..."
DOTFILES_CRED_HELPER='!f() { echo username=x-access-token; echo "password=$DOTFILES_REPO_TOKEN"; }; f'
if [ -z "${DOTFILES_REPO_TOKEN:-}" ]; then
  echo "DOTFILES_REPO_TOKEN not set — dotfiles pushes will fail. Add it at https://github.com/settings/codespaces and restart." >&2
else
  git -C "$DOTFILES_DIR" config credential.https://github.com.helper ""
  git -C "$DOTFILES_DIR" config --add credential.https://github.com.helper "$DOTFILES_CRED_HELPER"
  echo "dotfiles repo ready to push at $DOTFILES_DIR."
fi

# Register the on-demand "Claude dev setup" VSCode task WITHOUT committing to the
# shared web repo. The actual work (freeze rover-plugins autoUpdate, add source
# repos to the window) lives in setup-claude-dev.sh and only runs when the task
# is actioned — not automatically per codespace. We write the task into the
# tracked web/.vscode/tasks.json, then skip-worktree so git never reports it as
# modified. (Trade-off: while skipped, upstream edits to tasks.json won't apply;
# undo with: git update-index --no-skip-worktree .vscode/tasks.json)
echo "Registering 'Claude dev setup' VSCode task..."
WEB_TASKS=/workspaces/web/.vscode/tasks.json
if [ -d /workspaces/web/.vscode ] && command -v jq >/dev/null 2>&1; then
  # tasks.json ships as JSONC (comment header); strip // line-comments so jq can
  # parse it (empty file -> {}), then drop any previous copy of the task before
  # appending the current one — idempotent, preserves other tasks, and refreshes
  # the definition when it changes here (skipping on label would freeze it).
  { sed 's://.*$::' "$WEB_TASKS" 2>/dev/null || echo '{}'; } \
    | jq '{version: (.version // "2.0.0"),
           tasks: (((.tasks // []) | map(select(.label != "Claude dev setup"))) + [{
             label: "Claude dev setup",
             type: "shell",
             command: "bash /workspaces/.codespaces/.persistedshare/dotfiles/setup-claude-dev.sh",
             problemMatcher: [],
             detail: "Surface dotfiles + rover-plugins + wiki repos in VSCode; freeze rover-plugins autoUpdate."
           }])}' > "$WEB_TASKS.tmp" && mv "$WEB_TASKS.tmp" "$WEB_TASKS"
  git -C /workspaces/web update-index --skip-worktree .vscode/tasks.json 2>/dev/null || true
else
  echo "web/.vscode or jq missing — skipping VSCode task registration." >&2
fi

# Apply vscode/machine-settings.json to the VSCode Machine settings, which cover
# every folder in the codespace — a repo .vscode/settings.json would only cover
# that folder, and web's is tracked. Codespaces writes this file itself (feature
# blurbs, port labels), so deep-merge with the same jq script the Claude settings
# use rather than overwriting. The data dir name differs across VSCode clients,
# hence the loop.
echo "Applying VSCode machine settings..."
if command -v jq >/dev/null 2>&1; then
  for VSCODE_DATA in ~/.vscode-remote/data/Machine ~/.vscode-server/data/Machine; do
    [ -d "$VSCODE_DATA" ] || continue
    VSCODE_SETTINGS="$VSCODE_DATA/settings.json"
    [ -s "$VSCODE_SETTINGS" ] || echo '{}' > "$VSCODE_SETTINGS"
    # A hand-added // comment makes the file JSONC, which jq cannot parse; leave
    # it untouched in that case rather than clobbering it.
    jq -s -f "$DOTFILES_DIR/claude/merge-settings.jq" \
      "$VSCODE_SETTINGS" "$DOTFILES_DIR/vscode/machine-settings.json" \
      > "$VSCODE_SETTINGS.tmp" \
      && mv "$VSCODE_SETTINGS.tmp" "$VSCODE_SETTINGS" \
      || { rm -f "$VSCODE_SETTINGS.tmp"; echo "could not parse $VSCODE_SETTINGS — skipped." >&2; }
  done
else
  echo "jq missing — skipping VSCode machine settings." >&2
fi
