#!/bin/bash

# Dotfiles installation script for GitHub Codespaces
# This script sets up the development environment for the Rover project

set -e

echo "Setting up Rover development environment..."

# Copy personal.py settings to the web project
echo "Copying personal.py to web project..."
cp /workspaces/.codespaces/.persistedshare/dotfiles/personal.py /workspaces/web/src/aplaceforrover/rover/settings/personal.py

# Set up Stripe webhook environment variable for automatic webhook listening
echo "Setting up Stripe webhook environment..."
echo 'export DC_PARAMS="--profile stripe"' >> ~/.bashrc
source ~/.bashrc

# Install caveman Claude plugin/skill
echo "Installing caveman Claude plugin..."
if [ ! -d "$HOME/.claude/plugins/cache/caveman" ]; then
    curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash
else
    echo "caveman plugin already installed, skipping."
fi

# Set default Claude Code model to Sonnet (merge, don't clobber other settings)
echo "Setting default Claude model to sonnet..."
mkdir -p ~/.claude
CLAUDE_SETTINGS=~/.claude/settings.json
if [ -f "$CLAUDE_SETTINGS" ]; then
  jq '.model = "sonnet"' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
else
  echo '{"model": "sonnet"}' > "$CLAUDE_SETTINGS"
fi

# Set caveman default intensity to ultra
# Read by the caveman SessionStart hook (caveman-config.js) before the 'full'
# fallback. Config file is shell-independent and survives restarts.
echo "Setting caveman default mode to ultra..."
mkdir -p ~/.config/caveman
echo '{"defaultMode": "ultra"}' > ~/.config/caveman/config.json

# Install personal Claude Code skills (user-level, available in every codespace)
echo "Installing personal Claude skills..."
mkdir -p ~/.claude/skills
cp -r /workspaces/.codespaces/.persistedshare/dotfiles/skills/. ~/.claude/skills/

# Install the Acceleration team Claude Code plugin
echo "Installing team-acceleration Claude plugin..."
if command -v claude >/dev/null 2>&1; then
  claude plugin marketplace add roverdotcom/rover-claude-plugins || true
  claude plugin install team-acceleration@rover-plugins || true
else
  echo "claude CLI not on PATH yet — skipping team-acceleration install." >&2
fi
