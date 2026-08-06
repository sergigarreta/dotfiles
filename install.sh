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

# Set up the personal research wiki (Karpathy LLM Wiki pattern). It is a separate
# private repo so it can also be opened as an Obsidian vault on the Mac; this
# clone is the codespace-side copy.
#
# Auth needs the WIKI_REPO_TOKEN Codespaces secret (fine-grained PAT on
# sergigarreta/llm-wiki, Contents: read+write). The codespace's own GITHUB_TOKEN
# cannot reach personal repos — it is scoped to the roverdotcom repos listed in
# web/.devcontainer/devcontainer.json.
echo "Setting up research wiki..."
WIKI=/workspaces/wiki
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
