import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_canonical_enemy_group_sizes_are_declared():
    rules = json.loads((ROOT / "data/roguelike/roguelike_rules.json").read_text(encoding="utf-8"))
    balance = rules["combat_balance"]
    assert balance["encounter_group_sizes"] == {
        "normal": [4, 4],
        "elite": [2, 3],
        "miniboss": [1, 2],
        "boss": [1, 1],
    }
    assert balance["encounter_member_scaling"]["normal"] == {"hp": 0.46, "damage": 0.55}


def test_dungeon_runtime_uses_group_size_contract():
    source = (ROOT / "scripts/ui/main_v25.gd").read_text(encoding="utf-8")
    policy = (ROOT / "scripts/core/level_scaling_policy.gd").read_text(encoding="utf-8")
    assert "func _encounter_group_size(encounter_class: String, encounter_key: String)" in source
    assert 'encounter_class = "elite"' in source
    assert 'encounter_class = "miniboss"' in source
    assert 'encounter_class = "boss"' in source
    assert 'templates = [10, 8]' in source
    assert 'templates = [30, 8]' in source
    assert 'templates = [38]' in source
    assert 'if room_type == "miniboss" and enemy_index > 0:' in source
    assert 'scaling_room_type = "combat"' in source
    assert 'level_scaling_policy.apply_encounter_member_scaling(enemy, encounter_class)' in source
    assert 'func apply_encounter_member_scaling(enemy: Dictionary, encounter_class: String)' in policy


def test_campaign_runtime_uses_same_group_size_contract():
    source = (ROOT / "scripts/world/ashlands_combat_bridge.gd").read_text(encoding="utf-8")
    assert "func _encounter_group_size(encounter_class: String)" in source
    assert 'var encounter_class := encounter_type if encounter_type in ["elite", "miniboss", "boss"] else "normal"' in source
    assert 'templates = [10, 8]' in source
    assert 'templates = [30, 8]' in source
    assert 'templates = [38]' in source
    assert 'var is_primary_miniboss := encounter_type == "miniboss" and enemy_index == 0' in source
    assert 'if encounter_type == "miniboss" and enemy_index > 0:' in source
    assert 'scaling_type = "normal"' in source
    assert 'level_scaling_policy.apply_encounter_member_scaling(e, encounter_class)' in source
