const vscode = require("vscode");
const fs = require("fs");
const path = require("path");

const CLAUDE_ID = "anthropic.claude-code";
// Upstream issue anthropics/claude-code#90580. Keep in sync with claude/patch-vscode-tab-title.sh.
const CUT = /return (\$|\w+)\.length>25\?\1\.substring\(0,24\)\+"(?:…|\\u2026)":\1\}/g;

function patch(log) {
  const ext = vscode.extensions.getExtension(CLAUDE_ID);
  if (!ext) return false;
  const file = path.join(ext.extensionPath, "webview", "index.js");
  const src = fs.readFileSync(file, "utf8");
  const out = src.replace(CUT, "return $1}");
  if (out === src) {
    if (!src.includes(".substring(0,24)")) return false;
    log.appendLine(`Title cut pattern not found in ${file}; the regex may need updating.`);
    return false;
  }
  if (!fs.existsSync(file + ".bak")) fs.copyFileSync(file, file + ".bak");
  fs.writeFileSync(file, out);
  log.appendLine(`Patched ${file}`);
  return true;
}

function claudeTabs() {
  return vscode.window.tabGroups.all
    .flatMap((g) => g.tabs)
    .filter((t) => t.input instanceof vscode.TabInputWebview && t.input.viewType.includes("claudeVSCodePanel"));
}

// Claude keeps a stack of the last 10 closed sessions, so tabs go one at a time:
// each close is undone by the next reopen before the following tab closes.
async function reloadTabs(log) {
  const ext = vscode.extensions.getExtension(CLAUDE_ID);
  if (!ext) return;
  await ext.activate();
  const tabs = claudeTabs();
  for (const tab of tabs) {
    const label = tab.label;
    const before = claudeTabs().length;
    await vscode.window.tabGroups.close(tab, true);
    await new Promise((r) => setTimeout(r, 300));
    await vscode.commands.executeCommand("claude-vscode.reopenClosedSession");
    log.appendLine(`Reloaded "${label}" (${claudeTabs().length >= before ? "ok" : "not reopened"})`);
  }
}

async function activate(context) {
  const log = vscode.window.createOutputChannel("Claude Tab Titles");
  context.subscriptions.push(
    log,
    vscode.commands.registerCommand("claudeTabTitles.refreshTabs", async () => {
      patch(log);
      await reloadTabs(log);
    })
  );
  try {
    if (patch(log)) {
      // Let Claude restore its tabs before closing them.
      await new Promise((r) => setTimeout(r, 3000));
      await reloadTabs(log);
    }
  } catch (e) {
    log.appendLine(String(e && e.stack ? e.stack : e));
  }
}

module.exports = { activate, deactivate() {} };
