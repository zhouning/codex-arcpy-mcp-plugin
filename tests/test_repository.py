import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).parents[1]


def test_marketplace_points_to_arcpy_plugin():
    marketplace = json.loads(
        (ROOT / ".agents/plugins/marketplace.json").read_text(encoding="utf-8")
    )

    assert marketplace["name"] == "zhouning-arcpy"
    assert marketplace["plugins"][0]["name"] == "arcpy-mcp"
    assert marketplace["plugins"][0]["source"] == {
        "source": "local",
        "path": "./plugins/arcpy-mcp",
    }
    assert marketplace["plugins"][0]["policy"] == {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL",
    }


def test_macos_scripts_are_executable_in_git():
    paths = [
        "plugins/arcpy-mcp/scripts/configure-macos.sh",
        "plugins/arcpy-mcp/scripts/verify-connection.sh",
    ]
    result = subprocess.run(
        ["git", "ls-files", "--stage", *paths],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    modes = {
        line.split(maxsplit=3)[3]: line.split(maxsplit=1)[0]
        for line in result.stdout.splitlines()
    }

    assert modes == {path: "100755" for path in paths}


def test_shipped_client_files_do_not_reference_old_endpoint():
    shipped_files = [
        ROOT / "README.md",
        ROOT / "plugins/arcpy-mcp/.mcp.json",
        ROOT / "plugins/arcpy-mcp/scripts/configure-macos.sh",
        ROOT / "plugins/arcpy-mcp/scripts/verify-connection.sh",
        ROOT / "plugins/arcpy-mcp/skills/arcpy-mcp/SKILL.md",
    ]

    for path in shipped_files:
        assert "192.168.25.228" not in path.read_text(encoding="utf-8"), path
