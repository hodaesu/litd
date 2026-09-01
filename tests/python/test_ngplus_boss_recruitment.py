import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads((ROOT / path).read_text())


def test_ngplus_boss_catalog_is_disabled_by_canon():
    data = load('data/world/ngplus_boss_recruits.json')
    assert data['schema_version'] >= 3
    assert data['status'] == 'disabled_by_canon_audit'
    assert data['recruits'] == []
    assert data['capture_rules'] == {}
    assert 'Ange' in data['hard_exclusions']


def test_ngplus_rules_keep_capture_separate_from_personhood_and_justice():
    rules = load('data/world/new_game_plus.json')['boss_recruitment']
    assert rules['enabled'] is False
    exclusions = ' '.join(rules['hard_exclusions']).lower()
    assert 'human' in exclusions or 'personhood' in exclusions
    assert 'justice' in exclusions
    assert 'founders' in exclusions or 'historical figures' in exclusions
    personhood_rule = rules['personhood_rule'].lower()
    assert 'capture' in personhood_rule
    assert 'arrestation' in personhood_rule
    assert 'procès' in personhood_rule
    assert 'coopération' in personhood_rule


def test_runtime_boss_recruitment_shim_is_hard_disabled():
    state = (ROOT / 'scripts/core/ngplus_boss_recruitment.gd').read_text()
    assert 'func enabled() -> bool:' in state
    assert 'return false' in state
    assert 'func definition_for_enemy(_enemy: Dictionary) -> Dictionary:' in state
    assert 'func definition_for_species(_species_id: String) -> Dictionary:' in state
    assert 'func raw_entry_for_encounter(_encounter_id: String) -> Dictionary:' in state
    assert 'func raw_entry_for_species(_species_id: String) -> Dictionary:' in state
    assert '_generated_skill_trees' not in state


def test_creature_capture_rejects_bosses_in_every_cycle():
    creatures = (ROOT / 'scripts/core/creature_manager.gd').read_text()
    assert 'Les mini-boss et boss ne sont pas capturables.' in creatures
    assert "ne peuvent être recrutés qu'en Nouveau Cycle+" not in creatures
    assert 'var boss_definition := BossRecruitmentState.definition_for_enemy(enemy)' not in creatures
    assert 'var is_special := bool(definition.get("boss_recruit", false))' not in creatures


def test_legacy_boss_recruits_are_removed_when_old_saves_are_loaded():
    creatures = (ROOT / 'scripts/core/creature_manager.gd').read_text()
    assert 'if bool(creature.get("boss_recruit", false)):' in creatures
    assert 'continue' in creatures
    assert 'creature.erase("boss_recruit")' in creatures


def test_compatibility_autoload_cannot_enable_boss_capture_and_regular_roster_stays_intact():
    project = (ROOT / 'project.godot').read_text()
    state = (ROOT / 'scripts/core/ngplus_boss_recruitment.gd').read_text()
    regular = load('data/capturable_creatures.json')
    assert 'BossRecruitmentState="*res://scripts/core/ngplus_boss_recruitment.gd"' in project
    assert 'func enabled() -> bool:' in state and 'return false' in state
    assert {entry['enemy_id'] for entry in regular} == {1, 8, 10}
