from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "scripts/core/knowledge_discovery_ui_contract.gd"
SMOKE = ROOT / "scripts/tests/knowledge_discovery_ui_contract_smoke_test.gd"
SCENE = ROOT / "scenes/tests/knowledge_discovery_ui_contract_smoke.tscn"
WORKFLOW = ROOT / ".github/workflows/veilleurs-p1-knowledge-discovery-ui-smoke.yml"


def test_contract_is_read_only_and_reconciles_existing_sources():
    source = CONTRACT.read_text(encoding="utf-8")
    assert "class_name KnowledgeDiscoveryUIContract" in source
    assert "static func resolve_level(" in source
    assert "static func enemy_view(" in source
    assert "static func world_view(" in source
    assert '"encounter": LEVEL_OBSERVED' in source
    assert '"text": LEVEL_STUDIED' in source
    assert '"sanctuary": LEVEL_STUDIED' in source
    assert '"capture": LEVEL_DOCUMENTED' in source
    assert '"research": LEVEL_DOCUMENTED' in source
    assert '"read_only": true' in source
    assert "CampaignMemoryDirector." not in source
    assert "VeilleursArchivesRuntime.new" not in source


def test_dedicated_strict_godot_smoke_is_wired():
    assert SCENE.exists()
    smoke = SMOKE.read_text(encoding="utf-8")
    assert "KNOWLEDGE_DISCOVERY_UI_CONTRACT_SMOKE_OK" in smoke
    assert "presentation contract never mutates source data" in smoke
    workflow = WORKFLOW.read_text(encoding="utf-8")
    assert "Strict Godot import" in workflow
    assert "knowledge_discovery_ui_contract_smoke.tscn" in workflow
