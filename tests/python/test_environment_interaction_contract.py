from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "scripts" / "core" / "environment_interaction_contract.gd"
CONTROLLER = ROOT / "scripts" / "world" / "exploration_party_controller.gd"
REPRESENTATIVES = [
    ROOT / "scripts" / "world" / "shortcut_gate.gd",
    ROOT / "scripts" / "world" / "resource_node.gd",
    ROOT / "scripts" / "world" / "lore_collectible.gd",
    ROOT / "scripts" / "world" / "veilleurs_vs001_corpse_proxy.gd",
    ROOT / "scripts" / "world" / "veilleurs_vs001_interaction_proxy.gd",
    ROOT / "scripts" / "world" / "campfire_interaction.gd",
]


def test_common_contract_exposes_descriptor_and_result_fields():
    text = CONTRACT.read_text(encoding="utf-8")
    for field in [
        '"interaction_id"',
        '"kind"',
        '"label"',
        '"verb"',
        '"available"',
        '"blocked_reason"',
        '"consumed"',
        '"inspect"',
        '"success"',
        '"outcome"',
        '"reason"',
        '"payload"',
    ]:
        assert field in text
    assert "static func describe(" in text
    assert "static func perform(" in text
    assert "_legacy_descriptor" in text


def test_exploration_controller_no_longer_knows_interaction_subtypes():
    text = CONTROLLER.read_text(encoding="utf-8")
    assert "EnvironmentInteractionContract.perform(target, self)" in text
    assert "EnvironmentInteractionContract.describe(target, self)" in text
    assert 'target.has_method("interact")' not in text
    assert 'target.has_method("harvest")' not in text
    assert 'target.has_method("rest")' not in text


def test_representative_environment_objects_implement_common_surface():
    for path in REPRESENTATIVES:
        text = path.read_text(encoding="utf-8")
        assert "func interaction_descriptor(" in text, path
        assert "func perform_interaction(" in text, path
        assert "EnvironmentInteractionContract.descriptor(" in text, path
        assert "EnvironmentInteractionContract.result(" in text, path


def test_specialized_effect_methods_are_preserved():
    expected = {
        "shortcut_gate.gd": "func interact() -> bool:",
        "resource_node.gd": "func harvest(",
        "lore_collectible.gd": "func interact() -> void:",
        "veilleurs_vs001_corpse_proxy.gd": "func interact() -> Dictionary:",
        "veilleurs_vs001_interaction_proxy.gd": "func interact() -> Dictionary:",
        "campfire_interaction.gd": "func rest() -> Dictionary:",
    }
    for path in REPRESENTATIVES:
        text = path.read_text(encoding="utf-8")
        assert expected[path.name] in text, path
