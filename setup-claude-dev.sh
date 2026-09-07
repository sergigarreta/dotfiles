#!/bin/bash

# On-demand Claude dev setup. NOT run automatically per codespace — trigger it
# via the "Claude dev setup" VSCode task (Run Task) or run this script directly.
#
# It surfaces the editable source repos in the running VSCode window and freezes
# the rover-plugins marketplace so local edits are not clobbered by autoUpdate.

set -e

DOTFILES=/workspaces/.codespaces/.persistedshare/dotfiles
ROVER_PLUGINS="$HOME/.claude/plugins/marketplaces/rover-plugins"
WIKI=/workspaces/wiki

# Freeze the rover-plugins marketplace so local edits survive. autoUpdate:true
# pulls upstream and clobbers any change; false keeps the clone editable at the
# cost of not receiving upstream fixes until flipped back to true.
KNOWN_MP=~/.claude/plugins/known_marketplaces.json
if [ -f "$KNOWN_MP" ]; then
  jq '.["rover-plugins"].autoUpdate = false' "$KNOWN_MP" > "$KNOWN_MP.tmp" && mv "$KNOWN_MP.tmp" "$KNOWN_MP"
  echo "rover-plugins autoUpdate disabled."
fi

# Resolve a CLI that can actually reach the running window. /usr/local/bin/code is
# a shim that re-searches PATH for a later `code` and exits 127 with "code or
# code-insiders is not installed" when there is none, so `command -v code` alone
# proves nothing. The real binary ships with the server; the data dir name differs
# across VSCode clients, so try both.
CODE=""
for candidate in "$HOME"/.vscode-remote/bin/*/bin/remote-cli/code \
                 "$HOME"/.vscode-server/bin/*/bin/remote-cli/code; do
  if [ -x "$candidate" ]; then
    CODE="$candidate"
    break
  fi
done
if [ -z "$CODE" ] && command -v code >/dev/null 2>&1; then
  CODE="$(command -v code)"
fi

if [ -d "$WIKI" ]; then
  FOLDERS="$DOTFILES $ROVER_PLUGINS $WIKI"
  ADDED="dotfiles + rover-plugins + wiki"
else
  FOLDERS="$DOTFILES $ROVER_PLUGINS"
  ADDED="dotfiles + rover-plugins"
  echo "$WIKI is not cloned — install.sh only clones it when WIKI_REPO_TOKEN is set." >&2
fi

# Surface source repos as extra folders in the running VSCode window. Committing
# in the dotfiles folder pushes to the personal dotfiles repo; the rover-plugins
# folder is the marketplace clone (frozen above so edits stick). The wiki folder
# is the research wiki repo — VSCode gives markdown preview and clickable links.
#
# One invocation, not one per folder: the window starts as a single-folder window,
# and the first --add converts it to an untitled workspace and reloads, dropping
# the IPC socket that any follow-up call is still talking to. --add takes several
# folders, so the whole set lands in a single workspace mutation.
if [ -n "$CODE" ]; then
  if "$CODE" --add $FOLDERS; then
    echo "Added $ADDED to VSCode workspace."
  else
    echo "code --add failed — $ADDED not added to the VSCode workspace." >&2
  fi
else
  echo "No usable code CLI — run this from a VSCode terminal or the Run Task menu, not a bare shell." >&2
fi
