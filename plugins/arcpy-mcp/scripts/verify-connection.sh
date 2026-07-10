#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'This script must run on macOS.\n' >&2
  exit 1
fi

for required_command in codex security launchctl curl grep id; do
  command -v "$required_command" >/dev/null || {
    printf 'Missing command: %s\n' "$required_command" >&2
    exit 1
  }
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CA_CERT="$PLUGIN_DIR/assets/arcpy-mcp-ca.crt"
HEALTH_URL="https://192.168.25.228:8765/healthz"
ACCOUNT="$(id -un)"

if [[ ! -f "$CA_CERT" ]]; then
  printf 'Missing CA certificate: %s\n' "$CA_CERT" >&2
  exit 1
fi
if grep -q "PRIVATE KEY" "$CA_CERT"; then
  printf 'CA asset unexpectedly contains a private key.\n' >&2
  exit 1
fi

token="$(security find-generic-password -a "$ACCOUNT" -s codex-arcpy-mcp -w)"
if [[ ${#token} -lt 32 ]]; then
  unset token
  printf 'The Keychain token is missing or too short.\n' >&2
  exit 1
fi
launchctl setenv ARCPY_MCP_TOKEN "$token"
unset token
printf 'Keychain and launch environment: OK\n'

security verify-cert -c "$CA_CERT" >/dev/null
printf 'CA certificate: OK\n'

curl \
  --fail \
  --silent \
  --show-error \
  --output /dev/null \
  --cacert "$CA_CERT" \
  "$HEALTH_URL"
printf 'Windows ArcPy endpoint: OK\n'

codex plugin marketplace list | grep -F "zhouning-arcpy" >/dev/null
printf 'Codex marketplace: OK\n'

codex plugin list | grep -F "arcpy-mcp" >/dev/null
printf 'Codex plugin: OK\n'

codex mcp list | grep -F "arcpy" >/dev/null
printf 'ArcPy MCP registration: OK\n'

printf 'ArcPy MCP connection checks passed.\n'
