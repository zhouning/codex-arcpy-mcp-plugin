import json
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
