import json
from pathlib import Path


ROOT = Path(__file__).parents[1]
PLUGIN = ROOT / "plugins/arcpy-mcp"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_plugin_manifest_has_remote_mcp_and_skill():
    manifest = load(PLUGIN / ".codex-plugin/plugin.json")

    assert manifest["name"] == "arcpy-mcp"
    assert manifest["version"] == "0.1.0"
    assert manifest["mcpServers"] == "./.mcp.json"
    assert manifest["skills"] == "./skills/"
    assert manifest["interface"]["displayName"] == "ArcPy MCP"


def test_mcp_uses_fixed_ip_and_environment_token():
    config = load(PLUGIN / ".mcp.json")
    server = config["mcpServers"]["arcpy"]

    assert server == {
        "type": "http",
        "url": "https://192.168.25.228:8765/mcp",
        "bearer_token_env_var": "ARCPY_MCP_TOKEN",
    }
