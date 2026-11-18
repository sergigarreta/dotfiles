const vscode = require("vscode");
const os = require("os");
const path = require("path");
const fs = require("fs");

const HEARTBEAT = path.join(os.homedir(), ".cache", "codespace-keepalive", "heartbeat.txt");
const TERMINAL_NAME = "codespace-keepalive";

let timer;
let log;
let status;
let paused = false;

function cfg() {
  return vscode.workspace.getConfiguration("codespaceKeepAlive");
}

function inWindow(now = new Date()) {
  const c = cfg();
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", {
      timeZone: c.get("timeZone") || "UTC",
      weekday: "short",
      hour: "numeric",
      hourCycle: "h23",
    })
      .formatToParts(now)
      .map((p) => [p.type, p.value])
  );
  const hour = Number(parts.hour);
  if (c.get("weekdaysOnly") && (parts.weekday === "Sat" || parts.weekday === "Sun")) return false;
  return hour >= c.get("startHour") && hour < c.get("endHour");
}

function terminal() {
  const existing = vscode.window.terminals.find((t) => t.name === TERMINAL_NAME && t.exitStatus === undefined);
  return existing || vscode.window.createTerminal({ name: TERMINAL_NAME, hideFromUser: true, cwd: os.homedir() });
}

// The codespace counts user input as activity, not background processes, so the
// ping goes through the same paths a person would: terminal input and an editor save.
async function ping(reason) {
  const stamp = new Date().toISOString();
  terminal().sendText(`: keepalive ${stamp}`, true);

  fs.mkdirSync(path.dirname(HEARTBEAT), { recursive: true });
  if (!fs.existsSync(HEARTBEAT)) fs.writeFileSync(HEARTBEAT, "");
  const doc = await vscode.workspace.openTextDocument(HEARTBEAT);
  const edit = new vscode.WorkspaceEdit();
  edit.replace(doc.uri, new vscode.Range(0, 0, doc.lineCount, 0), `${stamp}\n`);
  await vscode.workspace.applyEdit(edit);
  await doc.save();

  log.appendLine(`${stamp} ping (${reason})`);
}

async function tick() {
  const active = cfg().get("enabled") && !paused && inWindow();
  status.text = active ? "$(pulse) keep-alive" : "$(circle-slash) keep-alive";
  status.tooltip = active ? "Codespace keep-alive pinging" : "Codespace keep-alive idle (outside hours or off)";
  if (!active) return;
  try {
    await ping("timer");
  } catch (err) {
    log.appendLine(`${new Date().toISOString()} ping failed: ${err && err.message}`);
  }
}

function schedule() {
  clearInterval(timer);
  timer = setInterval(tick, cfg().get("intervalMinutes") * 60 * 1000);
  tick();
}

function activate(context) {
  log = vscode.window.createOutputChannel("Codespace Keep-Alive");
  status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, -1000);
  status.command = "codespaceKeepAlive.toggle";
  status.show();

  context.subscriptions.push(
    log,
    status,
    { dispose: () => clearInterval(timer) },
    vscode.commands.registerCommand("codespaceKeepAlive.pingNow", () => ping("manual")),
    vscode.commands.registerCommand("codespaceKeepAlive.toggle", () => {
      paused = !paused;
      log.appendLine(`${new Date().toISOString()} ${paused ? "paused" : "resumed"}`);
      tick();
    }),
    vscode.commands.registerCommand("codespaceKeepAlive.showLog", () => log.show()),
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (e.affectsConfiguration("codespaceKeepAlive")) schedule();
    })
  );

  log.appendLine(`${new Date().toISOString()} activated, heartbeat file ${HEARTBEAT}`);
  schedule();
}

function deactivate() {
  clearInterval(timer);
}

module.exports = { activate, deactivate };
