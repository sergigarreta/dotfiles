#!/bin/bash

# Claude Code setup — user-level settings, plugins, skills and MCP servers.
#
# Called by the top-level install.sh, and safe to re-run on its own:
#   bash ~/.config/coderv2/dotfiles/claude/install.sh
#
# Every step is idempotent. Declarative settings live in claude/settings.json
# (edit that, not this script); this script only applies them.

set -e

. "$(dirname "$0")/../lib/env.sh"
CLAUDE_DIR="$DOTFILES_DIR/claude"
CLAUDE_SETTINGS="$CLAUDE_HOME/settings.json"

# ---------------------------------------------------------------------------
# User settings ($CLAUDE_HOME/settings.json)
# ---------------------------------------------------------------------------
# Merged rather than overwritten so settings owned elsewhere survive: the wiki's
# SessionStart/Stop hooks, marketplaces and enabledPlugins written by the claude
# CLI, and permission rules the user added interactively via /permissions.
echo "Applying Claude settings from claude/settings.json..."
mkdir -p "$CLAUDE_HOME"
if command -v jq >/dev/null 2>&1; then
  [ -f "$CLAUDE_SETTINGS" ] || echo '{}' > "$CLAUDE_SETTINGS"
  jq -s -f "$CLAUDE_DIR/merge-settings.jq" \
    "$CLAUDE_SETTINGS" "$CLAUDE_DIR/settings.json" \
    > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
else
  echo "jq missing — cannot merge Claude settings." >&2
fi

# ---------------------------------------------------------------------------
# Keybindings ($CLAUDE_HOME/keybindings.json)
# ---------------------------------------------------------------------------
# Copied wholesale: nothing else writes this file, and Claude Code has no UI for
# editing keybindings, so there is no external state to preserve.
echo "Applying Claude keybindings from claude/keybindings.json..."
cp "$CLAUDE_DIR/keybindings.json" "$CLAUDE_HOME/keybindings.json"

# ---------------------------------------------------------------------------
# Personal skills
# ---------------------------------------------------------------------------
# Symlink (not copy) so edits under $CLAUDE_HOME/skills are live for Claude AND
# tracked in this dotfiles repo. These are personal skills, not a plugin
# marketplace, so nothing auto-updates or overwrites them. The loop only creates
# links — removing a skill means deleting the symlink by hand too.
echo "Linking personal Claude skills..."
mkdir -p "$CLAUDE_HOME/skills"
for skill_dir in "$DOTFILES_DIR"/skills/*/; do
  name="$(basename "$skill_dir")"
  target="$CLAUDE_HOME/skills/$name"
  rm -rf "$target"
  ln -s "${skill_dir%/}" "$target"
done

# Skill docs call their helper scripts by ~/.claude/skills/<name>/..., so point
# that path at the real skills dir when Claude's config lives elsewhere.
if [ "$CLAUDE_HOME" != "$HOME/.claude" ] && [ ! -e "$HOME/.claude/skills" ]; then
  mkdir -p "$HOME/.claude"
  ln -s "$CLAUDE_HOME/skills" "$HOME/.claude/skills"
fi

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------
echo "Installing caveman Claude plugin..."
if [ ! -d "$CLAUDE_HOME/plugins/cache/caveman" ]; then
  curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash
else
  echo "caveman plugin already installed, skipping."
fi

# Read by the caveman SessionStart hook (caveman-config.js) before its 'full'
# fallback. Config file is shell-independent and survives restarts.
echo "Setting caveman default mode to ultra..."
mkdir -p ~/.config/caveman
echo '{"defaultMode": "ultra"}' > ~/.config/caveman/config.json

# setup-claude-dev.sh and the VSCode workspace expect the clone at
# $CLAUDE_HOME/plugins/marketplaces/rover-plugins to exist. enabledPlugins in
# settings.json only enables a plugin; it does not install it, so install here.
echo "Registering rover-plugins Claude plugin marketplace..."
if command -v claude >/dev/null 2>&1; then
  claude plugin marketplace add roverdotcom/rover-claude-plugins || true
  for plugin in ci-self-iteration owner-retention rover-mode work; do
    if claude plugin list 2>/dev/null | grep -q "$plugin@rover-plugins"; then
      echo "$plugin plugin already installed, skipping."
    else
      claude plugin install "$plugin@rover-plugins" --scope user || true
    fi
  done
else
  echo "claude CLI not on PATH yet — skipping rover-plugins marketplace." >&2
fi

# ---------------------------------------------------------------------------
# MCP servers
# ---------------------------------------------------------------------------
# Internal Google Workspace MCP, personal/local scope: stored in $CLAUDE_HOME/.claude.json
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

# Amplitude MCP, user scope. The repo's web gateway portal doesn't include
# Amplitude, so it's registered against its dedicated portal. Auth via /mcp.
echo "Registering amplitude MCP server..."
if command -v claude >/dev/null 2>&1; then
  if claude mcp get amplitude >/dev/null 2>&1; then
    echo "amplitude MCP already registered, skipping."
  else
    claude mcp add amplitude -s user --transport http \
      https://amplitude.mcp-portal.dev-tools.roversvc.com/mcp || true
  fi
else
  echo "claude CLI not on PATH yet — skipping amplitude MCP registration." >&2
fi

echo "Claude setup done."
