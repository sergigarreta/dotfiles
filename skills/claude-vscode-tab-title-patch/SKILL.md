---
name: claude-vscode-tab-title-patch
description: Patch the Claude Code VS Code extension so session tab titles are not cut to 24 chars + "…". Use when the user says Claude tab titles are truncated again, usually after an extension update.
---

The webview cuts tab titles at 25 chars (upstream issue anthropics/claude-code#90580, still open). No VS Code setting helps. Each extension update undoes the patch.

A `SessionStart` hook in `~/.claude/settings.json` (from dotfiles `claude/settings.json`) runs `claude/patch-vscode-tab-title.sh` on every Claude session, so an update gets re-patched automatically. To patch by hand (backs up to `index.js.bak` once):

```bash
/workspaces/.codespaces/.persistedshare/dotfiles/claude/patch-vscode-tab-title.sh
```

The personal extension `sergigarreta.claude-tab-titles` (dotfiles `vscode/claude-tab-titles/`, installed by its `install.sh`) also patches when VS Code starts, and if it patched it closes each Claude tab and reopens it with `claude-vscode.reopenClosedSession` so it loads the new code. Run that by hand with **Claude Tab Titles: Patch and Reload Claude Tabs**, but only while no Claude tab is mid-turn. Its log is in the **Claude Tab Titles** output channel. It keeps its own copy of the regex in `extension.js`: update both files together.

Without the extension: **Developer: Reload Webviews** or **Developer: Reload Window**. Undo: copy `index.js.bak` over `index.js`.

If the script prints nothing but titles are still cut, the code changed: find the new cut with `LC_ALL=C grep -oE '.{0,80}length>25\?.{0,60}' ~/.vscode-remote/extensions/anthropic.claude-code-*/webview/index.js`, then update the regex in the script.
