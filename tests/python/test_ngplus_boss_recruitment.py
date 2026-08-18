import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads((ROOT / path).read_text())


def test_ngplus_roster_covers_chapter_and_deep_vestige_bosses_and_minibosses():
    data = load('data/world/ngplus_boss_recruits.json')
    recruits = data['recruits']
    ids = {r['encounter_id'] for r in recruits}
    assert data['unlock_cycle_min'] == 1
    assert data['level_sync'] == 'party_average'
    assert len(recruits) >= 34
    assert {'c01_miniboss_warden','c10_unpaid_cost','c01_boss_ash_witness','c10_boss_final'} <= ids
    assert {
        'vestige_ashai_boss_seventh_voice','vestige_silex_boss_last_strategist',
        'vestige_saan_boss_last_watch','vestige_vaor_boss_command_without_body',
        'vestige_lyrmar_boss_absent_cartographer','vestige_sahmir_boss_single_interpreter',
        'vestige_ydris_boss_living_theorem'
    } <= ids
    assert all(r['signature'].strip() and r['archetype'].strip() for r in recruits)


def test_rank_specific_recruitment_is_harder_for_major_bosses():
    rules = load('data/world/ngplus_boss_recruits.json')['capture_rules']
    assert rules['boss']['max_hp_ratio'] < rules['miniboss']['max_hp_ratio']
    assert rules['deep_boss']['max_hp_ratio'] <= rules['boss']['max_hp_ratio']
    assert rules['boss']['essence_cost'] > rules['miniboss']['essence_cost']
    assert rules['deep_boss']['essence_cost'] >= rules['boss']['essence_cost']


def test_recruited_boss_level_tracks_party_average_instead_of_boss_hp_template():
    state = (ROOT / 'scripts/core/ngplus_boss_recruitment.gd').read_text()
    creatures = (ROOT / 'scripts/core/creature_manager.gd').read_text()
    assert 'func party_reference_level()' in state
    assert 'float(total) / float(maxi(1, count))' in state
    assert 'var starting_level := BossRecruitmentState.party_reference_level() if adaptive else 1' in creatures
    assert 'func sync_adaptive_recruits()' in creatures
    assert 'creature["level"] = target_level' in creatures
    assert 'creature["xp"] = 0' in creatures
    assert '"level_sync": adaptive' in creatures


def test_ngplus_boss_recruitment_uses_unique_encounter_ids_not_shared_enemy_ids():
    state = (ROOT / 'scripts/core/ngplus_boss_recruitment.gd').read_text()
    creatures = (ROOT / 'scripts/core/creature_manager.gd').read_text()
    assert 'chapter_boss_id' in state and 'chapter_miniboss_id' in state
    assert 'encounter_id_from_enemy' in state
    assert 'BossRecruitmentState.definition_for_enemy(enemy)' in creatures
    assert 'source_encounter_id' in creatures
    assert 'encounter_hash' in creatures


def test_bosses_remain_unrecruitable_outside_ngplus_but_use_existing_capture_action_inside_it():
    state = (ROOT / 'scripts/core/ngplus_boss_recruitment.gd').read_text()
    creatures = (ROOT / 'scripts/core/creature_manager.gd').read_text()
    combat_ui = (ROOT / 'scripts/ui/main.gd').read_text()
    assert 'return EndgameState.active_cycle >= int(data.get("unlock_cycle_min", 1))' in state
    assert 'Les mini-boss et boss ne peuvent être recrutés qu\'en Nouveau Cycle+.' in creatures
    assert 'action_panel.add_child(make_button("CAPTURER"' in combat_ui
    assert 'CreatureManager.attempt_capture(capture_target)' in combat_ui


def test_boss_companions_get_generated_skill_trees_and_keep_signature():
    state = (ROOT / 'scripts/core/ngplus_boss_recruitment.gd').read_text()
    creatures = (ROOT / 'scripts/core/creature_manager.gd').read_text()
    assert 'func _generated_skill_trees(entry: Dictionary)' in state
    assert '"offense"' in state and '"defense"' in state and '"special"' in state
    assert 'signature+" — Assaut"' in state
    assert 'signature+" — Rempart"' in state
    assert '"signature": str(definition.get("signature", ""))' in creatures
    assert '"signature": str(creature.get("signature", ""))' in creatures


def test_boss_recruitment_is_autoloaded_without_changing_regular_creature_roster():
    project = (ROOT / 'project.godot').read_text()
    regular = load('data/capturable_creatures.json')
    assert 'BossRecruitmentState="*res://scripts/core/ngplus_boss_recruitment.gd"' in project
    assert {entry['enemy_id'] for entry in regular} == {1, 8, 10}
