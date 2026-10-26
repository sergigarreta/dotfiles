---
name: claude-vscode-tab-title-patch
description: Patch the Claude Code VS Code extension so session tab titles are not cut to 24 chars + "…". Use when the user says Claude tab titles are truncated again, usually after an extension update.
---

The webview cuts tab titles at 25 chars (upstream issue anthropics/claude-code#90580, still open). No VS Code setting helps. Each extension update undoes the patch.

Patch every installed version (backs up to `index.js.bak` once):

```bash
cd ~/.vscode-remote/extensions && python3 - <<'PY'
import glob, re, shutil, os
for p in glob.glob("anthropic.claude-code-*/webview/index.js"):
    if not os.path.exists(p + ".bak"): shutil.copy(p, p + ".bak")
    s = open(p, encoding="utf-8").read()
    s, n = re.subn(r'return (\$|\w+)\.length>25\?\1\.substring\(0,24\)\+"(?:…|\\u2026)":\1\}', r'return \1}', s)
    open(p, "w", encoding="utf-8").write(s)
    print(p, "patched" if n else "pattern not found (already patched or code changed)")
PY
```

Then: **Developer: Reload Window**. Undo: copy `index.js.bak` over `index.js`.

If the pattern is not found, find the new cut with `LC_ALL=C grep -oE '.{0,80}length>25\?.{0,60}' webview/index.js`.
