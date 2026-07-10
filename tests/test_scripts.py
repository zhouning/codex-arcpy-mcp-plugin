from pathlib import Path


ROOT = Path(__file__).parents[1]
PLUGIN = ROOT / "plugins/arcpy-mcp"
CONFIGURE = PLUGIN / "scripts/configure-macos.sh"


def test_ca_asset_contains_only_a_public_certificate():
    certificate = (PLUGIN / "assets/arcpy-mcp-ca.crt").read_text(encoding="ascii")

    assert certificate.count("BEGIN CERTIFICATE") == 1
    assert certificate.count("END CERTIFICATE") == 1
    assert "PRIVATE KEY" not in certificate


def test_configure_script_uses_keychain_launchagent_and_private_marketplace():
    text = CONFIGURE.read_text(encoding="utf-8")

    required = [
        "security add-generic-password",
        "security find-generic-password",
        "launchctl setenv ARCPY_MCP_TOKEN",
        "security add-trusted-cert",
        "codex plugin marketplace add",
        "git@github.com:zhouning/codex-arcpy-mcp-plugin.git",
        "codex plugin add arcpy-mcp@zhouning-arcpy",
        "https://192.168.25.228:8765/healthz",
        "--rotate-token",
    ]
    for phrase in required:
        assert phrase in text

    forbidden = [
        'echo "$TOKEN"',
        'echo "$token"',
        "set -x",
        "ca.key",
        "server.key",
    ]
    for phrase in forbidden:
        assert phrase not in text
