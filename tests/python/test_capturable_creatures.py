import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load(name):
    return json.loads((ROOT / "data" / name).read_text())


def test_only_regular_first_level_creatures_are_capturable():
    definitions = _load("capturable_creatures.json")
    enemies = {enemy["id"]: enemy for enemy in _load("enemies.json")}
    assert {definition["enemy_id"] for definition in definitions} == {1, 8, 10}
    assert enemies[38]["boss"] is True
    assert 38 not in {definition["enemy_id"] for definition in definitions}
    assert all(not enemies[definition["enemy_id"]].get("boss", False) for definition in definitions)


def test_every_creature_has_three_complete_skill_trees():
    for definition in _load("capturable_creatures.json"):
        trees = definition["skill_trees"]
        assert set(trees) == {"offense", "defense", "special"}
        skill_ids = {node["id"] for nodes in trees.values() for node in nodes}
        assert len(skill_ids) == 9
        for branch, nodes in trees.items():
            assert len(nodes) == 3, (definition["id"], branch)
            for node in nodes:
                assert node["cost"] > 0
                assert node["required_level"] >= 1
                assert not node.get("requires") or node["requires"] in skill_ids


def test_capture_contracts_are_playable():
    for definition in _load("capturable_creatures.json"):
        capture = definition["capture"]
        assert 0 < capture["max_hp_ratio"] <= 0.5
        assert 0 <= capture["resistance"] < 100
        assert capture["essence_cost"] > 0
        assert len(definition["base_damage"]) == 2
        assert definition["base_damage"][0] <= definition["base_damage"][1]


def test_runtime_explicitly_rejects_bosses_and_persists_rng_state():
    manager = (ROOT / "scripts/core/creature_manager.gd").read_text()
    assert 'enemy.get("boss", false)' in manager
    assert "Un boss ne peut pas être capturé" in manager
    for key in ("captured_creatures", "capture_seed", "capture_attempt_counter", "creature_instance_counter"):
        assert f'"{key}"' in manager
    assert "func serialize()" in manager
    assert "func deserialize(data: Dictionary)" in manager


def test_capture_and_bestiary_are_connected_to_combat_ui():
    ui = (ROOT / "scripts/ui/main.gd").read_text()
    assert 'make_button("CAPTURER"' in ui
    assert "CreatureManager.attempt_capture" in ui
    assert "func show_creatures()" in ui
    assert "CreatureManager.companion_turn" in ui
    assert "CreatureManager.grant_active_xp" in ui


def test_save_schema_includes_creatures_and_version_bump():
    save_manager = (ROOT / "scripts/core/save_manager.gd").read_text()
    assert 'SAVE_VERSION := "0.16"' in save_manager
    assert '"creatures": CreatureManager.serialize()' in save_manager
    assert 'CreatureManager.deserialize(payload.get("creatures", {}))' in save_manager
