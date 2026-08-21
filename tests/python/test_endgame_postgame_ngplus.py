import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads((ROOT / path).read_text())


def test_all_nine_final_states_have_detailed_epilogues():
    endings = load('data/world/main_campaign_endings.json')
    epilogues = load('data/world/endgame_epilogues.json')
    expected = {e['id'] for e in endings['endings']} | {e['id'] for e in endings['failure_states']}
    by_id = {e['ending_id']: e for e in epilogues['epilogues']}
    assert expected == set(by_id)
    assert len(by_id) == 9
    for ending_id in expected:
        entry = by_id[ending_id]
        assert all(entry[key].strip() for key in ('opening','middle','political','closing'))
    assert len(epilogues['conditional_vignettes']) >= 6


def test_postgame_has_real_optional_operations_without_gating_ng_plus():
    postgame = load('data/world/postgame_operations.json')
    assert len(postgame['operations']) == 8
    # Kept as a legacy/preparation threshold for audits: runtime explicitly does not enforce it.
    assert postgame['operations_required_for_ng_plus'] == 3
    assert postgame['ng_plus_gate_enforced'] is False
    assert postgame['operations_recommended_for_guaranteed_legacy'] == 3
    ids = {op['id'] for op in postgame['operations']}
    assert {'postgame_routes','postgame_hearing','postgame_absent','postgame_creatures','postgame_stabilizers','postgame_delegations','postgame_memorial','postgame_future'} == ids
    assert all(op['cost'] and op['reward'] and op['flag'] for op in postgame['operations'])
    free = [op for op in postgame['operations'] if all(int(value) == 0 for value in op['cost'].values()) and not op.get('requirements')]
    assert len(free) >= postgame['operations_recommended_for_guaranteed_legacy']


def test_new_game_plus_is_immediate_optional_and_still_scales_difficulty():
    data = load('data/world/new_game_plus.json')
    assert data['unlock']['campaign_complete'] is True
    assert data['unlock']['runtime_gate'] == 'campaign_complete_only'
    assert data['unlock']['postgame_operations_gate_enforced'] is False
    assert data['allow_ng_plus_without_legacy'] is True
    assert data['continue_postgame_is_reversible'] is True
    assert data['max_legacy_perks'] == 1
    assert set(data['carry_over']) >= {'ending_history','legacy_points','epilogue_archive'}
    assert {'party_progression','inventory','creatures','campaign_progress'} <= set(data['reset'])
    assert data['difficulty_per_cycle'] == {'enemy_hp_pct':18,'enemy_damage_pct':12,'enemy_fear_pct':8}
    assert len(data['perks']) == 4


def test_endgame_runtime_is_autoloaded_saved_and_supports_both_postgame_paths():
    project = (ROOT / 'project.godot').read_text()
    save = (ROOT / 'scripts/core/save_manager.gd').read_text()
    runtime = (ROOT / 'scripts/core/endgame_state.gd').read_text()
    bridge = (ROOT / 'scripts/world/ashlands_combat_bridge.gd').read_text()
    assert 'EndgameState="*res://scripts/core/endgame_state.gd"' in project
    assert 'EndgameUI="*res://scripts/ui/endgame_ui.gd"' in project
    assert 'SAVE_VERSION := "0.31"' in save
    assert '"endgame": EndgameState.serialize()' in save
    assert 'EndgameState.deserialize(payload.get("endgame",{}))' in save
    assert 'func choose_continue_postgame()' in runtime
    assert 'func can_begin_new_game_plus(perk_id: String = "")' in runtime
    assert 'func begin_new_game_plus(perk_id: String = "")' in runtime
    assert 'return is_postgame_unlocked()' in runtime
    assert 'postgame_choice_presented' in runtime
    assert 'postgame_continuation_selected' in runtime
    assert 'GameState.reset_new_game()' in runtime
    assert 'func apply_enemy_scaling(enemy: Dictionary)' in runtime
    assert 'EndgameState.apply_enemy_scaling(e)' in bridge


def test_postgame_ui_exposes_continue_immediate_ngplus_and_optional_legacy_choice():
    ui = (ROOT / 'scripts/ui/endgame_ui.gd').read_text()
    assert "MONDE D'APRÈS" in ui
    assert 'APRÈS LA FIN — CHOISIS TON RYTHME' in ui
    assert 'CONTINUER CETTE PARTIE' in ui
    assert 'PASSER EN NG+ SANS HÉRITAGE' in ui
    assert 'CONFIRMER LE NOUVEAU CYCLE+' in ui
    assert 'RECONSTRUCTION OPTIONNELLE' in ui
    assert 'CHOISIR CET HÉRITAGE ET PASSER EN NG+' in ui
    assert 'CHRONIQUE DES CYCLES' in ui


def test_ng_plus_does_not_overwrite_light_in_the_dark_campaign_choices():
    runtime = (ROOT / 'scripts/core/endgame_state.gd').read_text()
    assert 'ending_history.append' in runtime
    assert 'epilogue_archive.append' in runtime
    assert 'completed_operations = {}' in runtime
    assert 'CampaignState.set_chapter_flag("ng_plus_active")' in runtime
    assert 'selected_legacy_perk' in runtime
