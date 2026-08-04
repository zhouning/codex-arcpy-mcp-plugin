#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'This script must run on macOS.\n' >&2
  exit 1
fi

MODE="${1:-install}"
case "$MODE" in
  install|--rotate-token|--refresh-ca) ;;
  *)
    printf 'Usage: %s [--rotate-token|--refresh-ca]\n' "$0" >&2
    exit 2
    ;;
esac

for required_command in codex git security launchctl curl grep id tr; do
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
LEGACY_CA_SHA1="609AD1A4FD4707958587A7C2B4E1DBDEA87F5800"
CURRENT_CA_SHA1="33FB760A998BE34BE3A7972290AD49C15F1E886F"

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

ca_present() {
  local fingerprint="$1"

  security find-certificate -a -Z "$LOGIN_KEYCHAIN" 2>/dev/null \
    | tr '[:lower:]' '[:upper:]' \
    | grep -F "$fingerprint" >/dev/null
}

refresh_ca() {
  if ca_present "$LEGACY_CA_SHA1"; then
    if ! security delete-certificate \
      -Z "$LEGACY_CA_SHA1" \
      "$LOGIN_KEYCHAIN" >/dev/null; then
      printf 'Failed to remove the legacy ArcPy MCP CA.\n' >&2
      return 1
    fi
  fi

  if ! ca_present "$CURRENT_CA_SHA1"; then
    security add-trusted-cert \
      -r trustRoot \
      -p ssl \
      -k "$LOGIN_KEYCHAIN" \
      "$CA_CERT"
  fi

  if ! ca_present "$CURRENT_CA_SHA1"; then
    printf 'The replacement ArcPy MCP CA is not installed.\n' >&2
    return 1
  fi
}

refresh_plugin() {
  if codex plugin marketplace list | grep -Fq "$MARKETPLACE_NAME"; then
    codex plugin marketplace upgrade "$MARKETPLACE_NAME"
  else
    codex plugin marketplace add "$MARKETPLACE_SOURCE"
  fi
  codex plugin add arcpy-mcp@zhouning-arcpy
}

case "$MODE" in
  install)
    store_token
    install_token_loader
    refresh_ca
    refresh_plugin
    ;;
  --rotate-token)
    store_token
    install_token_loader
    ;;
  --refresh-ca)
    refresh_ca
    refresh_plugin
    ;;
esac

curl \
  --fail \
  --silent \
  --show-error \
  --cacert "$CA_CERT" \
  "$HEALTH_URL"

printf '\nArcPy MCP configured. Restart Codex and open a new thread.\n'
