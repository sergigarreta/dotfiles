#!/bin/bash

# Claude Code setup — user-level settings, plugins, skills and MCP servers.
#
# Called by the top-level install.sh, and safe to re-run on its own:
#   bash /workspaces/.codespaces/.persistedshare/dotfiles/claude/install.sh
#
# Every step is idempotent. Declarative settings live in claude/settings.json
# (edit that, not this script); this script only applies them.

set -e

DOTFILES_DIR=/workspaces/.codespaces/.persistedshare/dotfiles
CLAUDE_DIR="$DOTFILES_DIR/claude"
CLAUDE_SETTINGS=~/.claude/settings.json

# ---------------------------------------------------------------------------
# User settings (~/.claude/settings.json)
# ---------------------------------------------------------------------------
# Merged rather than overwritten so settings owned elsewhere survive: the wiki's
# SessionStart/Stop hooks, marketplaces and enabledPlugins written by the claude
# CLI, and permission rules the user added interactively via /permissions.
echo "Applying Claude settings from claude/settings.json..."
mkdir -p ~/.claude
if command -v jq >/dev/null 2>&1; then
  [ -f "$CLAUDE_SETTINGS" ] || echo '{}' > "$CLAUDE_SETTINGS"
  jq -s -f "$CLAUDE_DIR/merge-settings.jq" \
    "$CLAUDE_SETTINGS" "$CLAUDE_DIR/settings.json" \
    > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
else
  echo "jq missing — cannot merge Claude settings." >&2
fi

# ---------------------------------------------------------------------------
# Personal skills
# ---------------------------------------------------------------------------
# Symlink (not copy) so edits under ~/.claude/skills are live for Claude AND
# tracked in this dotfiles repo. These are personal skills, not a plugin
# marketplace, so nothing auto-updates or overwrites them. The loop only creates
# links — removing a skill means deleting the symlink by hand too.
echo "Linking personal Claude skills..."
mkdir -p ~/.claude/skills
for skill_dir in "$DOTFILES_DIR"/skills/*/; do
  name="$(basename "$skill_dir")"
  target="$HOME/.claude/skills/$name"
  rm -rf "$target"
  ln -s "${skill_dir%/}" "$target"
done

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------
echo "Installing caveman Claude plugin..."
if [ ! -d "$HOME/.claude/plugins/cache/caveman" ]; then
  curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash
else
  echo "caveman plugin already installed, skipping."
fi

# Read by the caveman SessionStart hook (caveman-config.js) before its 'full'
# fallback. Config file is shell-independent and survives restarts.
echo "Setting caveman default mode to ultra..."
mkdir -p ~/.config/caveman
echo '{"defaultMode": "ultra"}' > ~/.config/caveman/config.json

echo "Installing team-acceleration Claude plugin..."
if command -v claude >/dev/null 2>&1; then
  claude plugin marketplace add roverdotcom/rover-claude-plugins || true
  claude plugin install team-acceleration@rover-plugins || true
else
  echo "claude CLI not on PATH yet — skipping team-acceleration install." >&2
fi

# ---------------------------------------------------------------------------
# MCP servers
# ---------------------------------------------------------------------------
# Internal Google Workspace MCP, personal/local scope: stored in ~/.claude.json
# under the /workspaces/web project, not the shared repo .mcp.json. Auth is OAuth
# via browser on first use (run `claude`, then /mcp).
echo "Registering google-workspace MCP server..."
if command -v claude >/dev/null 2>&1; then
  # Local scope is per-directory, so both the check and the add must run from
  # /workspaces/web or the entry lands under the wrong project.
  if (cd /workspaces/web && claude mcp get google-workspace) >/dev/null 2>&1; then
    echo "google-workspace MCP already registered, skipping."
  else
    (cd /workspaces/web && claude mcp add --transport http google-workspace \
      https://google-workspace-mcp.internal-tools.ext-svc.rover.com/mcp) || true
  fi
else
  echo "claude CLI not on PATH yet — skipping google-workspace MCP registration." >&2
fi

echo "Claude setup done."
