import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RULES = json.loads((ROOT / "data" / "game_rules.json").read_text(encoding="utf-8"))
INJURIES = json.loads((ROOT / "data" / "persistent_injuries.json").read_text(encoding="utf-8"))
TRAITS = json.loads((ROOT / "data" / "character_traits.json").read_text(encoding="utf-8"))

def test_litd_has_one_non_selectable_difficulty():
    difficulty = RULES["difficulty"]
    assert difficulty["mode_count"] == 1
    assert difficulty["player_selectable"] is False
    assert difficulty["story_scales_to_company_level"] is True
    assert difficulty["farming_required_for_story"] is False

def test_injuries_persist_until_real_treatment():
    rules = RULES["persistent_injuries"]
    assert rules["persist_after_combat"] is True
    assert rules["persist_after_dungeon"] is True
    assert rules["persist_after_sleep"] is True
    assert rules["removed_only_by_treatment"] is True
    assert rules["can_worsen_when_untreated"] is True
    assert INJURIES["treatment"]["field_stabilization_removes_debuff"] is False

def test_any_character_with_healing_capability_treats_every_injury():
    rules = RULES["persistent_injuries"]
    assert rules["healer_can_treat_every_injury_in_party"] is True
    assert rules["healing_eligibility"] == "any_living_character_with_healing_capability"
    assert rules["creatures_with_healing_capability_can_treat"] is True
    runtime = (ROOT / "scripts" / "core" / "persistent_injury_runtime.gd").read_text(encoding="utf-8")
    assert "func has_healing_capability" in runtime
    assert "HeroSkillManager.known_combat_skills" in runtime
    assert "CreatureManager.skill_nodes" in runtime
    assert 'String(skill.get("effect", "")) == "heal"' in runtime
    assert 'String(node.get("stat", "")) in ["healing_power", "party_heal"]' in runtime
    assert "MEDICAL_CLASSES" not in runtime
    assert "func treat_all_party_injuries" in runtime
    assert "func treat_all_at_infirmary" in runtime

def test_no_permanent_blindness_system():
    assert RULES["vision"]["permanent_blindness"] is False
    assert RULES["vision"]["eye_injuries_are_temporary"] is True
    injury_ids = {entry["id"] for entry in INJURIES["definitions"]}
    assert "blindness" not in injury_ids
    assert "blind" not in injury_ids

def test_ambidextrous_is_contextual_and_respects_two_handed_weapons():
    ambidextrous = next(t for t in TRAITS["positives"] if t["id"] == "ambidextrous")
    assert ambidextrous["effects"]["ignore_one_handed_arm_penalty"] == 1
    assert "arm_lost" in ambidextrous["contexts"]
    assert RULES["two_handed_rule"]["requires_two_functional_arms"] is True
    assert RULES["two_handed_rule"]["ambidextrous_does_not_bypass"] is True
    director = (ROOT / "scripts" / "core" / "character_trait_director.gd").read_text(encoding="utf-8")
    assert 'weapon_hands == 1' in director
    assert 'weapon_hands >= 2' in director
    assert 'result["two_handed_locked"] = 1.0' in director

def test_contextual_traits_keep_catalog_within_contract():
    positive_ids = {t["id"] for t in TRAITS["positives"]}
    assert {"ambidextrous", "alternate_support", "pain_endurance", "improviser", "ground_fighter"} <= positive_ids
    assert 20 <= len(TRAITS["positives"]) <= 30
    assert len(TRAITS["positives"]) == 25

def test_persistent_injuries_are_wired_to_gameplay_and_save():
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    game = (ROOT / "scripts" / "core" / "game_state.gd").read_text(encoding="utf-8")
    save = (ROOT / "scripts" / "core" / "save_manager.gd").read_text(encoding="utf-8")
    ui = (ROOT / "scripts" / "ui" / "main.gd").read_text(encoding="utf-8")
    assert 'PersistentInjuryRuntime="*res://scripts/core/persistent_injury_runtime.gd"' in project
    assert "PersistentInjuryRuntime.prepare_character(prepared_hero)" in game
    assert "PersistentInjuryRuntime.prepare_character(hero_value)" in save
    assert "PersistentInjuryRuntime.active_debuffs" in ui
    assert "PersistentInjuryRuntime.close_expedition" in ui
    assert "PersistentInjuryRuntime.treat_all_party_injuries" in ui
