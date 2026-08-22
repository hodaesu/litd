from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]


def test_main_scene_activates_four_skill_combat_layer():
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")
    assert 'res://scripts/ui/main_v30.gd' in scene
    layer = (ROOT / "scripts/ui/main_v30.gd").read_text(encoding="utf-8")
    assert 'extends "res://scripts/ui/main_v29.gd"' in layer


def test_each_hero_has_exactly_four_interchangeable_combat_skill_slots():
    manager = (ROOT / "scripts/core/hero_skill_manager.gd").read_text(encoding="utf-8")
    assert "const COMBAT_LOADOUT_SIZE := 4" in manager
    assert 'hero["combat_loadout"] = sanitized' in manager
    assert "func equip_combat_skill(hero: Dictionary, slot: int, skill_id: String) -> bool:" in manager
    assert 'if GameState.current_screen == "combat":' in manager
    assert "return false" in manager
    assert "known_combat_skills" in manager


def test_combat_has_four_skills_plus_separate_context_actions():
    layer = (ROOT / "scripts/ui/main_v30.gd").read_text(encoding="utf-8")
    assert "HeroSkillManager.COMBAT_LOADOUT_SIZE" in layer
    assert 'make_button("OBJETS"' in layer
    assert 'make_button("POSITION"' in layer
    assert 'make_button("PASSER"' in layer
    assert 'make_button("CAPTURER"' in layer
    assert "func _change_combat_position(delta: int)" in layer
    assert "func _pass_combat_turn()" in layer
    assert "combat_acted_hero_ids" in layer
    assert "super.enemy_turn()" in layer


def test_healing_items_and_grenades_are_combat_supplies_not_skill_slots():
    rules = json.loads((ROOT / "data/levels/ashlands_survival_rules.json").read_text(encoding="utf-8"))
    assert rules["expedition_inventory"]["bandages"] >= 1
    assert rules["expedition_inventory"]["medicine"] >= 1
    assert rules["expedition_inventory"]["grenades"] >= 1
    assert rules["combat_items"]["bandages"]["effect"] == "heal"
    assert rules["combat_items"]["medicine"]["effect"] == "heal"
    assert rules["combat_items"]["grenades"]["effect"] == "damage_all"
    assert rules["principles"]["combat_items_are_separate_from_skill_loadout"] is True
    assert rules["principles"]["position_change_costs_turn"] is True
    assert rules["principles"]["passing_costs_turn"] is True
