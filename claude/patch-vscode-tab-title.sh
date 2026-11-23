#!/bin/bash
# Removes the Claude Code webview's 25-char tab title cut (anthropics/claude-code#90580).
# Extension updates restore it, so the SessionStart hook re-applies this; silent unless it patches.
if ! ls -d ~/.vscode-remote/extensions/sergigarreta.claude-tab-titles-* >/dev/null 2>&1; then
  bash /workspaces/.codespaces/.persistedshare/dotfiles/vscode/claude-tab-titles/install.sh >/dev/null 2>&1 \
    && echo "Installed claude-tab-titles VSCode extension. Run Developer: Reload Window once to activate it."
fi
python3 - <<'PY'
import glob, os, re, shutil
for p in glob.glob(os.path.expanduser("~/.vscode-remote/extensions/anthropic.claude-code-*/webview/index.js")):
    s = open(p, encoding="utf-8").read()
    s, n = re.subn(r'return (\$|\w+)\.length>25\?\1\.substring\(0,24\)\+"(?:…|\\u2026)":\1\}', r'return \1}', s)
    if n:
        if not os.path.exists(p + ".bak"):
            shutil.copy(p, p + ".bak")
        open(p, "w", encoding="utf-8").write(s)
        print(f"Patched Claude tab title cut in {p}. Run Developer: Reload Window to apply.")
PY
