from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_main_scene_activates_position_layer():
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")
    assert 'res://scripts/ui/main_v31.gd' in scene


def test_position_rules_define_front_and_back_contracts():
    source = (ROOT / "scripts/core/combat_position_rules.gd").read_text(encoding="utf-8")
    assert 'const FRONT: Array[int] = [0, 1]' in source
    assert 'const MID_BACK: Array[int] = [1, 2, 3]' in source
    assert '"heavy_blow": return FRONT.duplicate()' in source
    assert '"field_aid": return MID_BACK.duplicate()' in source
    assert 'status in ["stun", "break"]' in source
    assert 'source_stat in ["precision", "critical_chance"]' in source


def test_wrong_rank_disables_skill_and_runtime_rejects_it():
    source = (ROOT / "scripts/ui/main_v31.gd").read_text(encoding="utf-8")
    assert 'button.disabled = not COMBAT_POSITION_RULES.is_usable(hero, skill)' in source
    assert 'if not COMBAT_POSITION_RULES.is_usable(hero, skill):' in source
    assert 'Rangs autorisés' in source
    assert 'super._use_combat_skill(slot)' in source


def test_position_change_remains_a_separate_turn_action():
    source = (ROOT / "scripts/ui/main_v30.gd").read_text(encoding="utf-8")
    assert 'func _change_combat_position(delta: int)' in source
    assert 'hero["combat_position"] = target_position' in source
    assert '_complete_active_hero_turn()' in source
