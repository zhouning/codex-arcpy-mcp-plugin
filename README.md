# Codex ArcPy MCP Plugin

Private Codex plugin for the ArcPy MCP service at
`https://192.168.50.170:8765/mcp`.

The plugin connects macOS Codex to the allowlisted ArcPy service running on
the Windows ArcGIS Pro host. It does not expose arbitrary Python, shell, or
ArcPy callable execution.

## Prerequisites

- macOS can route to `192.168.50.170:8765` through the private LAN or VPN.
- GitHub SSH access can clone `zhouning/codex-arcpy-mcp-plugin`.
- Codex CLI 0.144.1 or newer is installed on macOS.
- The Windows ArcPy MCP service reports healthy.
- You have the server-generated Bearer Token through a secure channel.

Do not paste the token into a shell command. The installer prompts for it
without terminal echo and stores it in the macOS login Keychain.

## Install On macOS

```bash
git clone git@github.com:zhouning/codex-arcpy-mcp-plugin.git
./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/configure-macos.sh
```

The script performs these actions:

- imports only the public `ArcPy MCP Local CA` certificate into the login Keychain;
- stores the Bearer Token under Keychain service `codex-arcpy-mcp`;
- installs a user LaunchAgent that restores `ARCPY_MCP_TOKEN` at login;
- adds the private GitHub marketplace and runs
  `codex plugin add arcpy-mcp@zhouning-arcpy`;
- verifies TLS and `/healthz` through the fixed IP endpoint.

Restart Codex and start a new thread after installation.

## Verify

```bash
./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/verify-connection.sh
```

The diagnostic checks Keychain access, launch environment injection, the CA,
the Windows endpoint, the marketplace, the installed plugin, and the `arcpy`
MCP registration. It does not print the token or dump the environment.

Then start a new Codex thread and ask:

```text
Use the ArcPy MCP plugin. Check the Windows ArcPy service health and report
the ArcGIS version, license level, Spatial Analyst status, Image Analyst
status, and processor type.
```

## Update

Refresh the local scripts and the configured remote marketplace:

```bash
git -C codex-arcpy-mcp-plugin pull --ff-only
codex plugin marketplace upgrade zhouning-arcpy
codex plugin add arcpy-mcp@zhouning-arcpy
```

Restart Codex and use a new thread after an update so the new Skill and MCP
configuration are loaded.

## Migrate The Host And CA

When the Windows host or local CA changes, update the checkout and refresh the
client trust and plugin registration:

```bash
git -C codex-arcpy-mcp-plugin pull --ff-only
./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/configure-macos.sh --refresh-ca
./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/verify-connection.sh
```

The refresh removes only the known legacy CA fingerprint, imports the bundled
replacement CA into the login Keychain, and reinstalls the plugin configuration.
The Bearer Token does not change and the command does not read or rewrite it.

Restart Codex and open a new thread after the refresh. Signed artifact download
URLs contain the issuing host, so URLs created before this migration are no
longer valid. Do not rewrite or reuse a signed URL issued for the old host; keep
the artifact ID and call `create_download` again.

## Rotate The Bearer Token

Rotate the static token on the Windows server and restart the ArcPy MCP
service first. Then update the macOS Keychain and launch environment:

```bash
./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/configure-macos.sh --rotate-token
```

Restart Codex after rotation. The script never writes the token into this
repository or a plaintext configuration file.

## Remove

```bash
codex plugin remove arcpy-mcp@zhouning-arcpy
codex plugin marketplace remove zhouning-arcpy
launchctl bootout "gui/$UID/com.zhouning.arcpy-mcp-token" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.zhouning.arcpy-mcp-token.plist"
rm -rf "$HOME/Library/Application Support/ArcPyMCP"
security delete-generic-password -a "$USER" -s codex-arcpy-mcp
launchctl unsetenv ARCPY_MCP_TOKEN
```

Remove the `ArcPy MCP Local CA` certificate from the login Keychain with
Keychain Access after confirming its certificate fingerprint.

## Deep Learning

The Windows host currently exposes allowlisted ArcGIS deep-learning inference
on CPU. Model training is not exposed. Inference requires a compatible ArcGIS
Pro 3.7.1 DLPK or EMD artifact and can take substantially longer than vector
or raster processing.

## Troubleshooting Order

1. Confirm private routing to `192.168.50.170:8765`.
2. Confirm the Windows service responds at `/healthz`.
3. Run `verify-connection.sh` and resolve certificate or Keychain errors.
4. Confirm `arcpy-mcp` appears in `codex plugin list`.
5. Confirm `arcpy` appears in `codex mcp list`.
6. Start a new Codex thread and call MCP `health_check`.

## Verification Status

- Windows server health and authenticated MCP `health_check`: passed.
- Real ArcPy Buffer and Slope workflows on Windows: passed.
- Plugin manifests, Skill validation, Bash syntax, and static secret checks: passed.
- macOS acceptance is pending on the target Mac.
- The Windows scheduled task is installed, but a real logoff/login or reboot is
  still required to validate automatic startup on this host.
