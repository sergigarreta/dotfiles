#!/bin/bash

# Dotfiles installation script for GitHub Codespaces
# This script sets up the development environment for the Rover project

set -e

echo "Setting up Rover development environment..."

# Copy personal.py settings to the web project
echo "Copying personal.py to web project..."
cp /workspaces/.codespaces/.persistedshare/dotfiles/personal.py /workspaces/web/src/aplaceforrover/rover/settings/personal.py

# Install caveman Claude plugin/skill
echo "Installing caveman Claude plugin..."
if [ ! -d "$HOME/.claude/plugins/cache/caveman" ]; then
    curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash
else
    echo "caveman plugin already installed, skipping."
fi

# Set default Claude Code model to Sonnet (merge, don't clobber other settings)
# Also default all subagents to Sonnet via CLAUDE_CODE_SUBAGENT_MODEL env var.
echo "Setting default Claude model + subagent model to sonnet..."
mkdir -p ~/.claude
CLAUDE_SETTINGS=~/.claude/settings.json
if [ -f "$CLAUDE_SETTINGS" ]; then
  jq '.model = "sonnet" | .env.CLAUDE_CODE_SUBAGENT_MODEL = "sonnet"' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
else
  echo '{"model": "sonnet", "env": {"CLAUDE_CODE_SUBAGENT_MODEL": "sonnet"}}' > "$CLAUDE_SETTINGS"
fi

# Set caveman default intensity to ultra
# Read by the caveman SessionStart hook (caveman-config.js) before the 'full'
# fallback. Config file is shell-independent and survives restarts.
echo "Setting caveman default mode to ultra..."
mkdir -p ~/.config/caveman
echo '{"defaultMode": "ultra"}' > ~/.config/caveman/config.json

# Install personal Claude Code skills (user-level, available in every codespace).
# Symlink (not copy) so edits under ~/.claude/skills are live for Claude AND
# tracked in this dotfiles repo. These are personal skills, not a plugin
# marketplace, so nothing auto-updates or overwrites them.
echo "Linking personal Claude skills..."
mkdir -p ~/.claude/skills
for skill_dir in /workspaces/.codespaces/.persistedshare/dotfiles/skills/*/; do
  name="$(basename "$skill_dir")"
  target="$HOME/.claude/skills/$name"
  rm -rf "$target"
  ln -s "${skill_dir%/}" "$target"
done

# Install the Acceleration team Claude Code plugin
echo "Installing team-acceleration Claude plugin..."
if command -v claude >/dev/null 2>&1; then
  claude plugin marketplace add roverdotcom/rover-claude-plugins || true
  claude plugin install team-acceleration@rover-plugins || true
else
  echo "claude CLI not on PATH yet — skipping team-acceleration install." >&2
fi

# Register the internal Google Workspace MCP server (personal, local scope).
# Stored in ~/.claude.json under the /workspaces/web project — not the shared
# repo .mcp.json. Auth is OAuth via browser on first use (run `claude` /mcp).
echo "Registering google-workspace MCP server..."
if command -v claude >/dev/null 2>&1; then
  if claude mcp get google-workspace >/dev/null 2>&1; then
    echo "google-workspace MCP already registered, skipping."
  else
    (cd /workspaces/web && claude mcp add --transport http google-workspace \
      https://google-workspace-mcp.internal-tools.ext-svc.rover.com/mcp) || true
  fi
else
  echo "claude CLI not on PATH yet — skipping google-workspace MCP registration." >&2
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
  # parse it (empty file -> {}), then add the task only if it isn't already
  # present so re-running install.sh is idempotent and preserves other tasks.
  { sed 's://.*$::' "$WEB_TASKS" 2>/dev/null || echo '{}'; } \
    | jq 'if (.tasks // []) | any(.label == "Claude dev setup") then . else
        {version: (.version // "2.0.0"),
         tasks: ((.tasks // []) + [{
           label: "Claude dev setup",
           type: "shell",
           command: "bash /workspaces/.codespaces/.persistedshare/dotfiles/setup-claude-dev.sh",
           problemMatcher: [],
           detail: "Surface dotfiles + rover-plugins repos in VSCode; freeze rover-plugins autoUpdate."
         }])}
      end' > "$WEB_TASKS.tmp" && mv "$WEB_TASKS.tmp" "$WEB_TASKS"
  git -C /workspaces/web update-index --skip-worktree .vscode/tasks.json 2>/dev/null || true
else
  echo "web/.vscode or jq missing — skipping VSCode task registration." >&2
fi
