#!/bin/bash
# Packages this folder as a .vsix and installs it into the codespace's VS Code server.
# On a fresh codespace the server may not exist yet when dotfiles run, so the
# install waits for it in the background (up to 30 min) instead of skipping.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
VSIX="${TMPDIR:-/tmp}/codespace-keepalive.vsix"
python3 - "$DIR" "$VSIX" <<'PY'
import json, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
pkg = json.load(open(f"{src}/package.json"))
manifest = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="{pkg['name']}" Version="{pkg['version']}" Publisher="{pkg['publisher']}"/>
    <DisplayName>{pkg['displayName']}</DisplayName>
    <Description xml:space="preserve">{pkg['description']}</Description>
    <Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="{pkg['engines']['vscode']}"/></Properties>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
  <Dependencies/>
  <Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets>
</PackageManifest>"""
types = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension=".json" ContentType="application/json"/><Default Extension=".js" ContentType="application/javascript"/><Default Extension=".vsixmanifest" ContentType="text/xml"/></Types>"""
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", types)
    z.writestr("extension.vsixmanifest", manifest)
    for f in ("package.json", "extension.js"):
        z.write(f"{src}/{f}", f"extension/{f}")
PY
find_server() { ls -td ~/.vscode-remote/bin/*/bin/code-server 2>/dev/null | head -1; }
install_into() {
  "$1" --user-data-dir ~/.vscode-remote/data --extensions-dir ~/.vscode-remote/extensions --install-extension "$VSIX" --force
  rmdir ~/.vscode-server 2>/dev/null || true
}
SERVER="$(find_server)"
if [ -n "$SERVER" ]; then
  install_into "$SERVER"
  exit 0
fi
echo "VS Code server not found yet — installing codespace-keepalive in the background once it appears." >&2
export VSIX
export -f find_server install_into
nohup bash -c 'for _ in $(seq 120); do S="$(find_server)"; [ -n "$S" ] && { sleep 30; install_into "$S"; exit 0; }; sleep 15; done' \
  > "${TMPDIR:-/tmp}/codespace-keepalive-install.log" 2>&1 &
