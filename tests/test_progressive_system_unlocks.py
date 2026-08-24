import json
from pathlib import Path

ROOT = Path(__file__).parents[1]


def load(path: str):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_world_rules_are_active_from_new_game():
    scope = load("data/content_scope.json")
    world = scope["categories"]["world_rules"]
    assert world["activation"] == "new_game"
    assert world["never_locked"] is True
    required = {
        "persistent_injuries", "untreated_injury_aggravation", "infirmary",
        "field_healing", "all_healing_characters_can_treat", "mutilations",
        "fear_hope_postures", "madness_afflictions", "positive_negative_traits",
        "permadeath", "physical_retreat", "ash_guidance_on_request",
        "enemy_senses", "enemy_reactions", "patrols", "reactive_rooms",
    }
    assert required.issubset(set(world["systems"]))


def test_only_player_capabilities_are_locked():
    scope = load("data/content_scope.json")
    unlocks = scope["categories"]["unlockable_capabilities"]
    assert {"capture", "bounties", "specialized_exploration_roles", "trap_weaponization", "player_markers"}.issubset(unlocks)
    for definition in unlocks.values():
        assert definition["logic"] == "or"
        assert definition["hidden_until_unlocked"] is True
    assert unlocks["targeted_farming"]["required_for_story"] is False


def test_campaign_progression_can_never_require_grinding():
    scope = load("data/content_scope.json")
    assert scope["progression"]["campaign_unlock_prevents_grind_gate"] is True
    assert scope["farming"]["required_for_main_story"] is False
    director = read("scripts/core/content_scope_director.gd")
    assert 'definition.get("logic", "or")' in director
    assert "chapter_met or rank_met" in director


def test_injuries_are_persistent_and_contextually_explained():
    rules = load("data/game_rules.json")
    injuries = rules["persistent_injuries"]
    assert injuries["persist_after_combat"] is True
    assert injuries["persist_after_dungeon"] is True
    assert injuries["removed_only_by_treatment"] is True
    assert injuries["can_worsen_when_untreated"] is True
    runtime = read("scripts/core/persistent_injury_runtime.gd")
    for event in ("first_persistent_injury", "first_injury_with_healer", "first_injury_aggravation", "first_return_with_injury"):
        assert event in runtime


def test_progression_state_is_saved():
    project = read("project.godot")
    saves = read("scripts/core/save_manager.gd")
    assert 'ContentScopeDirector="*res://scripts/core/content_scope_director.gd"' in project
    assert '"progression_scope": ContentScopeDirector.serialize()' in saves
    assert 'ContentScopeDirector.deserialize(payload.get("progression_scope",{}))' in saves


def test_world_activity_is_not_gated_by_progression():
    exploration = read("scripts/core/exploration_director.gd")
    assert 'is_world_rule_active("patrols")' not in exploration
    assert 'is_world_rule_active("reactive_rooms")' not in exploration
    assert 'is_unlocked("specialized_exploration_roles")' in exploration
    assert 'is_unlocked("trap_weaponization")' in exploration
    assert 'is_unlocked("player_markers")' in exploration


def test_locked_capabilities_are_hidden_in_ui():
    main = read("scripts/ui/main.gd")
    journal = read("scripts/ui/quest_journal_ui.gd")
    assert 'if ContentScopeDirector.is_unlocked("capture")' in main
    assert 'if not ContentScopeDirector.is_unlocked("bounties")' in journal
