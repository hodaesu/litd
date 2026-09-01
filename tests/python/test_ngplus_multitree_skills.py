import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads((ROOT / path).read_text())


def test_ngplus_data_preserves_exclusive_skill_tree_choice():
    data = load('data/world/new_game_plus.json')
    rules = data['skill_tree_rules']
    assert data['schema_version'] >= 5
    assert rules['multitree_enabled'] is False
    assert rules['tree_choice_exclusive_in_all_cycles'] is True
    assert rules['canonical_trees_per_character'] == 3
    assert rules['canonical_nodes_per_tree'] == 15
    assert {'heroes', 'enemies', 'captured_creatures'} <= set(rules['applies_to'])
    assert {'skill_point_cost', 'required_level', 'in_branch_prerequisites'} <= set(rules['still_required'])


def test_hero_skill_manager_never_opens_other_trees_in_ngplus():
    manager = (ROOT / 'scripts/core/hero_skill_manager.gd').read_text()
    assert 'func multi_tree_enabled() -> bool:' in manager
    assert 'return false' in manager
    assert 'if specialization != "" and specialization != branch: return false' in manager
    assert 'if str(hero.get("specialization","")) == "": hero["specialization"] = _branch_for(hero,skill_id)' in manager
    assert 'EndgameState.active_cycle >= 1' not in manager


def test_creature_manager_never_opens_other_trees_in_ngplus():
    manager = (ROOT / 'scripts/core/creature_manager.gd').read_text()
    assert 'func multi_tree_enabled() -> bool:' in manager
    assert 'return false' in manager
    assert 'if specialization != "" and specialization != skill_branch:' in manager
    assert 'if str(creature.get("specialization", "")) == "":' in manager
    assert 'EndgameState.active_cycle >= 1' not in manager


def test_ngplus_skill_ui_does_not_relabel_locked_branches_or_boss_capture():
    scene = (ROOT / 'scenes/Main.tscn').read_text()
    ui = (ROOT / 'scripts/ui/ngplus_skill_tree_ui.gd').read_text()
    assert 'ngplus_skill_tree_ui.gd' in scene
    assert 'OUVERT NG+' not in ui
    assert 'En NG+, les mini-boss et boss peuvent aussi être recrutés.' not in ui
    assert 'func _ready() -> void:' in ui
    assert 'pass' in ui


def test_exclusive_trees_keep_point_level_and_prerequisite_requirements():
    hero = (ROOT / 'scripts/core/hero_skill_manager.gd').read_text()
    creature = (ROOT / 'scripts/core/creature_manager.gd').read_text()
    assert 'int(hero.get("skill_points",0)) < int(node.cost)' in hero
    assert 'int(hero.get("level",1)) < int(node.required_level)' in hero
    assert 'str(node.requires) == "" or hero.get("unlocked_skills", []).has(str(node.requires))' in hero
    assert 'int(creature.get("skill_points", 0)) < int(node.get("cost", 1))' in creature
    assert 'int(creature.get("level", 1)) < int(node.get("required_level", 1))' in creature
    assert 'prerequisite == "" or creature.get("unlocked_skills", []).has(prerequisite)' in creature
