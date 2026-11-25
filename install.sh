#!/bin/bash

# Dotfiles installation script for Roverspaces (Coder); the paths it relies on
# are resolved in lib/env.sh. Coder runs it on every workspace start, so every
# step must be idempotent.

set -e

. "$(dirname "$0")/lib/env.sh"

echo "Setting up Rover development environment..."

echo "Copying personal.py to web project..."
if [ -d /workspaces/web/src/aplaceforrover/rover/settings ]; then
  cp "$DOTFILES_DIR/personal.py" /workspaces/web/src/aplaceforrover/rover/settings/personal.py
else
  echo "/workspaces/web is not checked out yet — skipping personal.py." >&2
fi

# Claude Code setup — settings, plugins, skills, MCP servers. Split out so the
# config that changes often lives in one place: claude/settings.json is the
# declarative part, claude/install.sh applies it. Must run before the wiki block,
# which merges its hooks into the settings file this creates.
echo "Setting up Claude Code..."
bash "$DOTFILES_DIR/claude/install.sh"

# Set up the personal research wiki (Karpathy LLM Wiki pattern), a separate
# private repo cloned to /workspaces/wiki.
#
# The Roverspace's own GitHub login (the `gh auth git-credential` helper in
# ~/.gitconfig) can read and push sergigarreta/llm-wiki, so no token is needed.
echo "Setting up research wiki..."
CLAUDE_SETTINGS="$CLAUDE_HOME/settings.json"
if [ ! -d "$WIKI/.git" ]; then
  git clone https://github.com/sergigarreta/llm-wiki "$WIKI" || \
    echo "wiki clone failed — check the GitHub login (gh auth status)." >&2
fi
if [ -d "$WIKI/.git" ]; then
  # Older installs wrote a WIKI_REPO_TOKEN helper into this clone's config.
  # Drop it so git falls back to the Roverspace login.
  git -C "$WIKI" config --unset-all credential.https://github.com.helper || true
  git -C "$WIKI" pull --rebase --autostash --quiet || true

  # Skill symlinked out of the wiki repo, so the procedures are versioned with
  # the wiki they operate on.
  mkdir -p "$CLAUDE_HOME/skills"
  rm -rf "$CLAUDE_HOME/skills/llm-wiki"
  ln -s "$WIKI/.claude/skills/llm-wiki" "$CLAUDE_HOME/skills/llm-wiki"

  # Load the wiki schema into every session through the user-level CLAUDE.md.
  # A project file (web's CLAUDE.local.md) importing a path outside the repo
  # makes Claude Code show an approval prompt at startup, which stalls the
  # remote-control sessions. The user-level file has no such check.
  USER_CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"
  if ! grep -qx '@/workspaces/wiki/WIKI.md' "$USER_CLAUDE_MD" 2>/dev/null; then
    printf '\n@/workspaces/wiki/WIKI.md\n' >> "$USER_CLAUDE_MD"
  fi
  # Older installs put the import in web's CLAUDE.local.md; remove it there.
  if [ -f /workspaces/web/CLAUDE.local.md ] && grep -qx '@/workspaces/wiki/WIKI.md' /workspaces/web/CLAUDE.local.md; then
    sed -i -e '\|^@/workspaces/wiki/WIKI\.md$|d' -e '/^# Personal$/d' /workspaces/web/CLAUDE.local.md
    grep -q '[^[:space:]]' /workspaces/web/CLAUDE.local.md || rm -f /workspaces/web/CLAUDE.local.md
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

# The Roverspace GitHub login already pushes to this repo. Older installs wrote
# a DOTFILES_REPO_TOKEN helper into this clone's config; drop it.
git -C "$DOTFILES_DIR" config --unset-all credential.https://github.com.helper || true

echo "Registering Roverspace in Statsig segment..."
bash "$DOTFILES_DIR/statsig-register-workspace.sh" || true
