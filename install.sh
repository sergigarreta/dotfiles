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
# WIKI_REPO_TOKEN (fine-grained PAT, Contents: read+write) still takes over when
# set, e.g. as a Coder user secret.
echo "Setting up research wiki..."
CLAUDE_SETTINGS="$CLAUDE_HOME/settings.json"
# The token helper reads WIKI_REPO_TOKEN at call time, so the PAT never lands in
# .git/config. It goes on the URL-scoped key because a URL-scoped helper beats a
# generic one, and the empty value first resets the inherited helper list.
WIKI_CRED_HELPER='!f() { echo username=x-access-token; echo "password=$WIKI_REPO_TOKEN"; }; f'
wiki_git() {
  if [ -n "${WIKI_REPO_TOKEN:-}" ]; then
    git -c credential.https://github.com.helper= \
        -c credential.https://github.com.helper="$WIKI_CRED_HELPER" "$@"
  else
    git "$@"
  fi
}
if [ ! -d "$WIKI/.git" ]; then
  wiki_git clone https://github.com/sergigarreta/llm-wiki "$WIKI" || \
    echo "wiki clone failed — check the GitHub login (gh auth status) or WIKI_REPO_TOKEN." >&2
fi
if [ -d "$WIKI/.git" ]; then
  if [ -n "${WIKI_REPO_TOKEN:-}" ]; then
    git -C "$WIKI" config --replace-all credential.https://github.com.helper ""
    git -C "$WIKI" config --add credential.https://github.com.helper "$WIKI_CRED_HELPER"
  fi
  git -C "$WIKI" pull --rebase --autostash --quiet || true

  # Skill symlinked out of the wiki repo, so the procedures are versioned with
  # the wiki they operate on.
  mkdir -p "$CLAUDE_HOME/skills"
  rm -rf "$CLAUDE_HOME/skills/llm-wiki"
  ln -s "$WIKI/.claude/skills/llm-wiki" "$CLAUDE_HOME/skills/llm-wiki"

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

# The Roverspace GitHub login already pushes to this repo. DOTFILES_REPO_TOKEN,
# when set, takes over with the same token-helper pattern as the wiki above.
echo "Configuring dotfiles push auth..."
DOTFILES_CRED_HELPER='!f() { echo username=x-access-token; echo "password=$DOTFILES_REPO_TOKEN"; }; f'
if [ -z "${DOTFILES_REPO_TOKEN:-}" ]; then
  echo "DOTFILES_REPO_TOKEN not set — using the Roverspace GitHub login for dotfiles pushes."
else
  git -C "$DOTFILES_DIR" config --replace-all credential.https://github.com.helper ""
  git -C "$DOTFILES_DIR" config --add credential.https://github.com.helper "$DOTFILES_CRED_HELPER"
  echo "dotfiles repo ready to push at $DOTFILES_DIR."
fi

echo "Registering Roverspace in Statsig segment..."
bash "$DOTFILES_DIR/statsig-register-workspace.sh" || true
