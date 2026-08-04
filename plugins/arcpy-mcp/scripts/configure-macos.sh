#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'This script must run on macOS.\n' >&2
  exit 1
fi

MODE="${1:-install}"
if [[ "$MODE" != "install" && "$MODE" != "--rotate-token" ]]; then
  printf 'Usage: %s [--rotate-token]\n' "$0" >&2
  exit 2
fi

for required_command in codex git security launchctl curl grep id; do
  command -v "$required_command" >/dev/null || {
    printf 'Missing command: %s\n' "$required_command" >&2
    exit 1
  }
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CA_CERT="$PLUGIN_DIR/assets/arcpy-mcp-ca.crt"
HEALTH_URL="https://192.168.50.170:8765/healthz"
MARKETPLACE_SOURCE="git@github.com:zhouning/codex-arcpy-mcp-plugin.git"
MARKETPLACE_NAME="zhouning-arcpy"
SERVICE_NAME="codex-arcpy-mcp"
ACCOUNT="$(id -un)"
LAUNCH_DIR="$HOME/Library/Application Support/ArcPyMCP"
LOADER="$LAUNCH_DIR/load-token.sh"
LAUNCH_LABEL="com.zhouning.arcpy-mcp-token"
PLIST="$HOME/Library/LaunchAgents/$LAUNCH_LABEL.plist"
LOGIN_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if [[ ! -f "$CA_CERT" ]]; then
  printf 'Missing CA certificate: %s\n' "$CA_CERT" >&2
  exit 1
fi
grep -q "BEGIN CERTIFICATE" "$CA_CERT"
if grep -q "PRIVATE KEY" "$CA_CERT"; then
  printf 'CA asset unexpectedly contains a private key.\n' >&2
  exit 1
fi

store_token() {
  local token

  printf 'ArcPy MCP Bearer Token: '
  IFS= read -r -s token
  printf '\n'
  if [[ ${#token} -lt 32 ]]; then
    unset token
    printf 'Token must contain at least 32 characters.\n' >&2
    exit 1
  fi

  security add-generic-password \
    -U \
    -a "$ACCOUNT" \
    -s "$SERVICE_NAME" \
    -w "$token" >/dev/null
  unset token
}

install_token_loader() {
  umask 077
  mkdir -p "$LAUNCH_DIR" "$HOME/Library/LaunchAgents"

  cat >"$LOADER" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

account="$(id -un)"
token="$(security find-generic-password -a "$account" -s codex-arcpy-mcp -w)"
launchctl setenv ARCPY_MCP_TOKEN "$token"
unset token
SH
  chmod 700 "$LOADER"

  cat >"$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LAUNCH_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$LOADER</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST
  chmod 600 "$PLIST"

  launchctl bootout "gui/$UID/$LAUNCH_LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$UID" "$PLIST"
  "$LOADER"
}

install_plugin() {
  security add-trusted-cert \
    -r trustRoot \
    -p ssl \
    -k "$LOGIN_KEYCHAIN" \
    "$CA_CERT"

  if codex plugin marketplace list | grep -Fq "$MARKETPLACE_NAME"; then
    codex plugin marketplace upgrade "$MARKETPLACE_NAME"
  else
    codex plugin marketplace add "$MARKETPLACE_SOURCE"
  fi
  codex plugin add arcpy-mcp@zhouning-arcpy
}

store_token
install_token_loader

if [[ "$MODE" == "install" ]]; then
  install_plugin
fi

curl \
  --fail \
  --silent \
  --show-error \
  --cacert "$CA_CERT" \
  "$HEALTH_URL"

printf '\nArcPy MCP configured. Restart Codex and open a new thread.\n'
