import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads((ROOT / path).read_text())


def test_ngplus_data_opens_all_three_skill_trees_from_first_return():
    data = load('data/world/new_game_plus.json')
    rules = data['skill_tree_rules']
    assert data['schema_version'] >= 3
    assert rules['multitree_from_cycle'] == 1
    assert rules['branches'] == ['offense', 'defense', 'special']
    assert {'heroes', 'regular_creature_companions', 'boss_recruits'} <= set(rules['applies_to'])
    assert {'skill_point_cost', 'required_level', 'in_branch_prerequisites'} <= set(rules['still_required'])


def test_hero_skill_manager_keeps_single_tree_initial_cycle_but_opens_ngplus():
    manager = (ROOT / 'scripts/core/hero_skill_manager.gd').read_text()
    assert 'func multi_tree_enabled() -> bool:' in manager
    assert 'return EndgameState.active_cycle >= 1' in manager
    assert 'if not multi_tree_enabled() and specialization != "" and specialization != branch: return false' in manager
    assert 'if not multi_tree_enabled() and str(hero.get("specialization","")) == ""' in manager
    assert 'str(node.requires) == "" or hero.get("unlocked_skills", []).has(str(node.requires))' in manager


def test_creatures_and_boss_recruits_can_mix_trees_in_ngplus():
    manager = (ROOT / 'scripts/core/creature_manager.gd').read_text()
    assert 'func multi_tree_enabled() -> bool:' in manager
    assert 'return EndgameState.active_cycle >= 1' in manager
    assert 'if not multi_tree_enabled() and specialization != "" and specialization != skill_branch:' in manager
    assert 'if not multi_tree_enabled() and str(creature.get("specialization", "")) == ""' in manager
    assert 'prerequisite == "" or creature.get("unlocked_skills", []).has(prerequisite)' in manager


def test_ngplus_skill_ui_relabels_locked_branches_as_open():
    scene = (ROOT / 'scenes/Main.tscn').read_text()
    ui = (ROOT / 'scripts/ui/ngplus_skill_tree_ui.gd').read_text()
    assert 'ngplus_skill_tree_ui.gd' in scene
    assert ' — OUVERT NG+' in ui
    assert ' — VERROUILLÉ' in ui
    assert 'EndgameState.active_cycle < 1' in ui
    assert 'hero_skills' in ui and 'creatures' in ui


def test_multitree_does_not_grant_free_points_or_ignore_level_requirements():
    hero = (ROOT / 'scripts/core/hero_skill_manager.gd').read_text()
    creature = (ROOT / 'scripts/core/creature_manager.gd').read_text()
    assert 'int(hero.get("skill_points",0)) < int(node.cost)' in hero
    assert 'int(hero.get("level",1)) < int(node.required_level)' in hero
    assert 'int(creature.get("skill_points", 0)) < int(node.get("cost", 1))' in creature
    assert 'int(creature.get("level", 1)) < int(node.get("required_level", 1))' in creature
