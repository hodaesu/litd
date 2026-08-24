import json
from pathlib import Path

ROOT = Path(__file__).parents[1]


def load(path: str):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_hero_catalog_is_preserved_but_production_is_bounded():
    scope = load("data/skill_production_scope.json")
    heroes = scope["heroes"]
    assert heroes["catalog_nodes_per_branch"] == 15
    assert 8 <= heroes["production_nodes_per_branch"] <= 10
    assert heroes["reserve_nodes_per_branch"] == 5
    assert heroes["reserve_policy"] == "data_and_design_preserved_not_unlockable"

    manager = read("scripts/core/hero_skill_manager.gd")
    assert "FULL_CATALOG_NODES_PER_BRANCH := 15" in manager
    assert "PRODUCTION_NODES_PER_BRANCH := 10" in manager
    assert "func production_skill_nodes" in manager
    assert "func reserve_skill_nodes" in manager
    assert '"production_state": "active" if index < PRODUCTION_NODES_PER_BRANCH else "reserve"' in manager
    assert 'not bool(node.get("available_in_current_release", false))' in manager


def test_current_ui_hides_reserve_without_deleting_it():
    focused_ui = read("scripts/ui/main_v33.gd")
    assert "HeroSkillManager.production_skill_nodes" in focused_ui
    assert "5 CONCEPTS CONSERVÉS EN RÉSERVE" in focused_ui


def test_enemy_production_uses_small_pool_and_contextual_variation():
    scope = load("data/skill_production_scope.json")
    enemies = scope["enemies"]
    profiles = load("data/enemy_combat_profiles.json")
    assert 4 <= enemies["family_runtime_target"][0] <= enemies["family_runtime_target"][1] <= 8
    assert enemies["player_style_forty_five_skill_trees"] is False
    assert len(profiles["skills"]) <= 8
    assert {"ai_orientation", "fear_posture", "injury_state", "combat_rank", "environment", "family_identity"} <= set(enemies["diversity_sources"])


def test_no_new_major_system_before_pc_loop_validation():
    scope = load("data/skill_production_scope.json")
    assert scope["rules"]["no_new_major_system_before_pc_loop_validation"] is True
    assert scope["rules"]["do_not_delete_reserve"] is True
