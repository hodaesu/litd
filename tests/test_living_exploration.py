import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def load(path: str):
    return json.loads(read(path))


def test_all_twelve_exploration_pillars_are_implemented():
    code = read("scripts/core/exploration_director.gd")
    required = [
        "func perceive(", "func assign_role(", "func resolve_trap(",
        "func register_patrol(", "func emit_noise(", "func set_light_level(",
        "func execute_retreat(", "func react_room(", "func solve_obstacle(",
        "func remember_landmark(", "func place_marker(",
        "func push_or_return_summary(", "func record_discovery("
    ]
    for contract in required:
        assert contract in code


def test_exploration_uses_world_cues_not_permanent_markers():
    code = read("scripts/core/exploration_director.gd")
    hud = read("scripts/ui/hud_director.gd")
    assert "HUDDirector.request_world_guidance" in code
    assert '"world_cue_only": true' in code
    assert '"hud_marker": false' in hud


def test_first_map_has_authored_living_content():
    content = load("data/levels/ashlands_living_exploration.json")
    manifest = load("data/levels/terre_des_cendres_blockout_manifest.json")
    zone_ids = {zone["id"] for zone in manifest["zones"]}
    assert set(content["zones"]) == zone_ids
    assert all("landmark" in zone for zone in content["zones"].values())
    assert sum(len(zone.get("traps", [])) for zone in content["zones"].values()) >= 14
    assert sum(len(zone.get("patrols", [])) for zone in content["zones"].values()) >= 6


def test_traps_are_readable_and_offer_multiple_responses():
    rules = load("data/exploration_systems.json")
    assert len(rules["traps"]) >= 8
    for trap in rules["traps"].values():
        assert len(trap["cues"]) >= 2
        assert len(trap["actions"]) >= 3
        assert "failure" in trap


def test_roles_use_posture_traits_and_injuries():
    code = read("scripts/core/exploration_director.gd")
    rules = load("data/exploration_systems.json")
    assert len(rules["roles"]) == 6
    assert "PsychologyRuntime.psychological_posture_label" in code
    assert "CharacterTraitDirector.modifiers" in code
    assert "persistent_injuries" in code


def test_patrols_react_to_noise_and_hero_reputation():
    code = read("scripts/core/exploration_director.gd")
    assert '"investigate"' in code
    assert "_party_renown()" in code
    assert '"avoid"' in code


def test_retreat_has_real_retention_and_pursuit_consequences():
    rules = load("data/exploration_systems.json")
    code = read("scripts/core/expedition_manager.gd")
    assert set(rules["retreat"]) == {"normal_exit", "shortcut", "emergency", "rout"}
    assert rules["retreat"]["emergency"]["keep_ratio"] < 1.0
    assert "apply_extraction_retention" in code


def test_exploration_state_is_saved_and_reset():
    project = read("project.godot")
    saves = read("scripts/core/save_manager.gd")
    state = read("scripts/core/game_state.gd")
    assert 'ExplorationDirector="*res://scripts/core/exploration_director.gd"' in project
    assert '"living_exploration"' in saves
    assert "ExplorationDirector.reset_new_game()" in state


def test_camp_uses_any_available_healing_capability():
    code = read("scripts/core/exploration_director.gd")
    assert "PersistentInjuryRuntime.available_healer" in code
    assert "PersistentInjuryRuntime.treat_all_party_injuries" in code
    assert "PersistentInjuryRuntime.stabilize_in_field" in code


def test_no_forbidden_survival_micromanagement_was_added():
    rules = read("data/exploration_systems.json").lower()
    for forbidden in ['"hunger"', '"thirst"', '"individual_weight"', '"equipment_durability"']:
        assert forbidden not in rules
