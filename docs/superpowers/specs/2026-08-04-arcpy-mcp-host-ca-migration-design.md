# ArcPy MCP Host and CA Migration Design

**Date:** 2026-08-04

## Objective

Migrate the macOS Codex plugin from the old ArcPy MCP endpoint at
`192.168.25.228:8765` to `192.168.50.170:8765`, distribute the replacement
public CA certificate, and provide a repeatable client migration that preserves
the existing Bearer token.

The plugin version remains `0.1.0`. The migration changes connection material
and client setup, not the MCP or plugin interface.

## Scope

The change will:

- replace `plugins/arcpy-mcp/assets/arcpy-mcp-ca.crt` with the CA generated at
  `C:\Users\zn198\AppData\Local\ArcPyMCP\certs\ca.crt`;
- change the fixed MCP, health, documentation, and test endpoints to
  `https://192.168.50.170:8765`;
- add a macOS CA refresh mode that does not rotate or rewrite the Bearer token;
- document and enforce the handling of signed artifact download URLs issued for
  the old host; and
- update automated tests for the new endpoint, certificate, and migration
  behavior.

The change will not rotate the Bearer token, change the plugin version, modify
the Windows service, or claim that macOS acceptance has run from this Windows
workspace.

## Client Migration Flow

`plugins/arcpy-mcp/scripts/configure-macos.sh` will accept a new
`--refresh-ca` mode alongside the existing default install and
`--rotate-token` modes.

In `--refresh-ca` mode, the script will:

1. Resolve the login Keychain and bundled replacement CA.
2. Look for the legacy CA by its exact SHA-1 certificate fingerprint,
   `609AD1A4FD4707958587A7C2B4E1DBDEA87F5800`.
3. Delete that exact certificate when present. Absence is not an error, but a
   detected certificate that cannot be deleted stops the migration.
4. Check for the replacement CA by its exact SHA-1 certificate fingerprint,
   `33FB760A998BE34BE3A7972290AD49C15F1E886F`. If it is already present, skip
   import; otherwise import the bundled certificate as an SSL trust root in
   the login Keychain and verify that the current fingerprint is present.
5. Upgrade the private marketplace when already registered, or add it when it
   is absent, then reinstall `arcpy-mcp@zhouning-arcpy` so Codex receives the
   new MCP endpoint.
6. Check the new `/healthz` endpoint using the bundled CA.

This mode will not prompt for, read, store, print, or inject the Bearer token.
The existing default installation and `--rotate-token` semantics remain
unchanged.

After refreshing the CA, the operator will run `verify-connection.sh`. The
verification script will check the new CA and endpoint, retrieve the unchanged
token from Keychain without printing it, perform authenticated MCP
initialization, and verify the marketplace, plugin, and MCP registrations.
Codex must then be restarted and a new thread opened so the refreshed plugin
configuration is loaded.

## Signed Artifact Download URLs

A signed artifact download URL contains the issuing host and is not a durable
artifact identifier. Every URL issued for the old host is invalid after the
migration. Clients must not rewrite the hostname or reuse the URL.

The artifact ID remains the input to the download workflow. To download an
existing artifact, the client calls `create_download` again and uses only the
newly returned signed URL for the active transfer. The skill and README will
state this rule explicitly. Existing rules that prohibit printing or
persisting signed URLs and prohibit sending the Bearer token to signed URLs
remain in force.

## Files and Responsibilities

- `plugins/arcpy-mcp/assets/arcpy-mcp-ca.crt`: replacement public CA only.
- `plugins/arcpy-mcp/.mcp.json`: fixed MCP address for Codex.
- `plugins/arcpy-mcp/scripts/configure-macos.sh`: install, token rotation, and
  migration-aware CA refresh workflows.
- `plugins/arcpy-mcp/scripts/verify-connection.sh`: layered checks against the
  new endpoint.
- `plugins/arcpy-mcp/skills/arcpy-mcp/SKILL.md`: signed download URL renewal
  rule.
- `README.md`: endpoint, prerequisites, migration procedure, troubleshooting,
  and acceptance status.
- `tests/`: endpoint, CA, migration behavior, documentation, safety, and
  repository checks.

The endpoint remains explicit in the plugin manifest and shell scripts. A new
configuration-generation layer is out of scope because the plugin targets one
private, fixed service and generation would add maintenance overhead without a
current consumer.

## Error Handling and Safety

- Legacy CA removal targets only the known old SHA-1 fingerprint, never every
  certificate sharing the `ArcPy MCP Local CA` common name.
- Refreshing is idempotent: an absent legacy CA does not fail the operation,
  and an already installed current CA is detected and not imported again.
- A deletion failure for a detected legacy CA, replacement CA import failure,
  marketplace/plugin refresh failure, or new endpoint health failure returns a
  nonzero exit status.
- No command logs, shell arguments, diagnostics, or documentation expose the
  Bearer token.
- Signed download URLs are treated as ephemeral secrets and are never repaired
  by textual hostname substitution.

## Testing and Acceptance

Automated tests will verify that:

- `.mcp.json`, scripts, README, and expectations use
  `192.168.50.170:8765`;
- the old `192.168.25.228` address is absent from shipped configuration,
  scripts, the user-facing README, and skill content;
- the committed CA has PEM-file SHA-256
  `3D875F739F3200E8CB6E351E0C2C6976D3686DE11DD7E915FE069EE8535957CD`,
  contains exactly one public certificate, and contains no private key;
- `--refresh-ca` exists, targets the legacy CA by exact fingerprint, and does
  not execute the token-storage path;
- README documents the ordered migration and signed URL renewal workflow; and
- the ArcPy skill directs clients to call `create_download` again instead of
  reusing old URLs.

Local acceptance consists of the pytest suite, `bash -n` for both macOS shell
scripts, a static secret scan, and inspection of the final diff. Live Keychain,
LaunchAgent, TLS, authenticated MCP, and plugin-loading checks must run later
on the target Mac and remain documented as pending until then.

## Operator Procedure

On the target Mac, the operator will:

1. Pull the repository update.
2. Run
   `./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/configure-macos.sh --refresh-ca`.
3. Run
   `./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/verify-connection.sh`.
4. Restart Codex and open a new thread.
5. Reissue any needed artifact download URL with `create_download`.
