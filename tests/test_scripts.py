import hashlib
from pathlib import Path


ROOT = Path(__file__).parents[1]
PLUGIN = ROOT / "plugins/arcpy-mcp"
CONFIGURE = PLUGIN / "scripts/configure-macos.sh"
VERIFY = PLUGIN / "scripts/verify-connection.sh"
REPLACEMENT_CA_SHA256 = (
    "3d875f739f3200e8cb6e351e0c2c6976d3686de11dd7e915fe069ee8535957cd"
)


def test_ca_asset_contains_only_the_replacement_public_certificate():
    certificate_bytes = (PLUGIN / "assets/arcpy-mcp-ca.crt").read_bytes()
    certificate = certificate_bytes.decode("ascii")

    assert hashlib.sha256(certificate_bytes).hexdigest() == REPLACEMENT_CA_SHA256
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
        "https://192.168.50.170:8765/healthz",
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


def test_configure_script_refreshes_ca_without_touching_token():
    text = CONFIGURE.read_text(encoding="utf-8")

    required = [
        "--refresh-ca",
        'LEGACY_CA_SHA1="609AD1A4FD4707958587A7C2B4E1DBDEA87F5800"',
        'CURRENT_CA_SHA1="33FB760A998BE34BE3A7972290AD49C15F1E886F"',
        "security find-certificate",
        "security delete-certificate",
        "security add-trusted-cert",
        "refresh_ca",
        "refresh_plugin",
        'grep -F "$fingerprint" >/dev/null',
    ]
    for phrase in required:
        assert phrase in text

    case_body = text.rsplit('case "$MODE" in', maxsplit=1)[1].split(
        "esac", maxsplit=1
    )[0]
    install_branch = case_body.split("install)", maxsplit=1)[1].split(
        ";;", maxsplit=1
    )[0]
    rotate_branch = case_body.split("--rotate-token)", maxsplit=1)[1].split(
        ";;", maxsplit=1
    )[0]
    refresh_branch = case_body.split("--refresh-ca)", maxsplit=1)[1].split(
        ";;", maxsplit=1
    )[0]
    assert "store_token" in install_branch
    assert "install_token_loader" in install_branch
    assert "refresh_ca" in install_branch
    assert "refresh_plugin" in install_branch
    assert "store_token" in rotate_branch
    assert "install_token_loader" in rotate_branch
    assert "refresh_ca" in refresh_branch
    assert "refresh_plugin" in refresh_branch
    assert "store_token" not in refresh_branch
    assert "install_token_loader" not in refresh_branch
    assert 'grep -Fq "$fingerprint"' not in text


def test_verify_script_checks_each_layer_without_dumping_secrets():
    text = VERIFY.read_text(encoding="utf-8")

    required = [
        "security find-generic-password",
        "launchctl setenv ARCPY_MCP_TOKEN",
        "security verify-cert",
        "https://192.168.50.170:8765/healthz",
        "https://192.168.50.170:8765/mcp",
        "Authorization: Bearer %s",
        '"method":"initialize"',
        "--config <(printf",
        "codex plugin marketplace list",
        "codex plugin list",
        "codex mcp list",
        "arcpy-mcp",
        "zhouning-arcpy",
    ]
    for phrase in required:
        assert phrase in text

    forbidden = [
        'echo "$TOKEN"',
        'echo "$token"',
        "set -x",
        "printenv",
        "launchctl getenv",
        '--header "Authorization: Bearer $token"',
        "\nenv\n",
    ]
    for phrase in forbidden:
        assert phrase not in text
