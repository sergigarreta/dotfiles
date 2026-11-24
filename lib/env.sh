# Sourced by every install script: the paths that differ between a Roverspace
# (Coder) and a GitHub Codespace. Source with `. "$(dirname "$0")/lib/env.sh"`
# or an equivalent relative path; nothing here has side effects.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -n "${CODER:-}" ]; then
  # Coder clones dotfiles to ~/.config/coderv2/dotfiles. Claude Code reads its
  # config from CLAUDE_CONFIG_DIR, which the Roverspace template exports for
  # login shells only, so agent scripts may not have it set.
  CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-/var/run/coder/claude}"
  # Agent scripts may run before the template's profile.d exports MACHINE_NAME,
  # which the template builds as <owner>-<workspace>.
  MACHINE_ID="${MACHINE_NAME:-${CODER_WORKSPACE_OWNER_NAME:+$CODER_WORKSPACE_OWNER_NAME-$CODER_WORKSPACE_NAME}}"
  export CLAUDE_CONFIG_DIR="$CLAUDE_HOME"
else
  CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  MACHINE_ID="${MACHINE_NAME:-${CODESPACE_NAME:-}}"
fi

WIKI=/workspaces/wiki
