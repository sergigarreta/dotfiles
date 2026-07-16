#!/bin/bash

# On-demand Claude dev setup. NOT run automatically per codespace — trigger it
# via the "Claude dev setup" VSCode task (Run Task) or run this script directly.
#
# It surfaces the editable source repos in the running VSCode window and freezes
# the rover-plugins marketplace so local edits are not clobbered by autoUpdate.

set -e

DOTFILES=/workspaces/.codespaces/.persistedshare/dotfiles
ROVER_PLUGINS="$HOME/.claude/plugins/marketplaces/rover-plugins"

# Freeze the rover-plugins marketplace so local edits survive. autoUpdate:true
# pulls upstream and clobbers any change; false keeps the clone editable at the
# cost of not receiving upstream fixes until flipped back to true.
KNOWN_MP=~/.claude/plugins/known_marketplaces.json
if [ -f "$KNOWN_MP" ]; then
  jq '.["rover-plugins"].autoUpdate = false' "$KNOWN_MP" > "$KNOWN_MP.tmp" && mv "$KNOWN_MP.tmp" "$KNOWN_MP"
  echo "rover-plugins autoUpdate disabled."
fi

# Surface source repos as extra folders in the running VSCode window. Committing
# in the dotfiles folder pushes to the personal dotfiles repo; the rover-plugins
# folder is the marketplace clone (frozen above so edits stick).
if command -v code >/dev/null 2>&1; then
  code --add "$DOTFILES" || true
  code --add "$ROVER_PLUGINS" || true
  echo "Added dotfiles + rover-plugins to VSCode workspace."
else
  echo "code CLI not on PATH — cannot add folders to VSCode." >&2
fi
