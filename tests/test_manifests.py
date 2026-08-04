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
        "url": "https://192.168.50.170:8765/mcp",
        "bearer_token_env_var": "ARCPY_MCP_TOKEN",
    }


def test_skill_contains_required_safety_and_workflow_rules():
    skill = (PLUGIN / "skills/arcpy-mcp/SKILL.md").read_text(encoding="utf-8")

    required = [
        "health_check",
        "get_capabilities",
        "create_upload",
        "get_upload_status",
        "renew_upload",
        "complete_upload",
        "inspect_dataset",
        "search_tools",
        "describe_tool",
        "submit_job",
        "get_job",
        "cancel_job",
        "get_job_log",
        "create_download",
        "ARCPY_MCP_TOKEN",
        "Never send a Windows absolute path",
        "Never request arbitrary Python execution",
        "artifact-relative paths",
        "CPU deep-learning",
    ]
    for phrase in required:
        assert phrase in skill


def test_readme_documents_install_update_rotation_and_removal():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")

    required = [
        "git clone git@github.com:zhouning/codex-arcpy-mcp-plugin.git",
        "./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/configure-macos.sh",
        "./codex-arcpy-mcp-plugin/plugins/arcpy-mcp/scripts/verify-connection.sh",
        "codex plugin add arcpy-mcp@zhouning-arcpy",
        "codex plugin marketplace upgrade zhouning-arcpy",
        "configure-macos.sh --rotate-token",
        "codex plugin remove arcpy-mcp@zhouning-arcpy",
        "codex plugin marketplace remove zhouning-arcpy",
        "https://192.168.50.170:8765/mcp",
        "macOS acceptance is pending",
    ]
    for phrase in required:
        assert phrase in readme
