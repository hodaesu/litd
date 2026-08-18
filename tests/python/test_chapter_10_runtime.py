import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads((ROOT / path).read_text())


def test_chapter_ten_has_eight_stages_seven_zones_and_campaign_quests():
    chapter = load('data/levels/chapter_10_final_choice.json')
    world = load('data/levels/chapter_10_world.json')
    assert chapter['chapter_id'] == 'chapter_10_final_choice'
    assert len(chapter['stages']) == 8
    assert len(world['zones']) == 7
    assert chapter['unlock'] == 'endings'
    assert set(chapter['main_quest_bindings']) == {'c10_gather_world','c10_last_crossing','c10_world_choice'}
    for zone in world['zones']:
        assert (ROOT / f"scenes/world/chapter_10/{zone['id']}.tscn").exists()


def test_final_decision_documents_real_costs_and_multiple_voices():
    chapter = load('data/levels/chapter_10_final_choice.json')
    world = load('data/levels/chapter_10_world.json')
    assert len(chapter['council_groups']) == 7
    assert sum(1 for g in chapter['council_groups'] if g.get('always')) == 3
    assert len(world['stakes']) == 13
    assert len({s['source_family'] for s in world['stakes']}) >= 10
    assert chapter['decision_rules']['stakes_required'] >= 8
    assert chapter['decision_rules']['stake_families_required'] >= 5
    assert 'jamais créée' in chapter['decision_rules']['rule']


def test_final_choices_are_inherited_from_campaign_not_created_by_chapter_ten():
    runtime = (ROOT / 'scripts/world/chapter_10_runtime.gd').read_text()
    endings = load('data/world/main_campaign_endings.json')
    assert len(endings['endings']) == 6
    assert len(endings['failure_states']) == 3
    assert 'return CampaignState.available_endings()' in runtime
    assert 'func unavailable_orientations()' in runtime
    assert 'func _failure_state()' in runtime
    assert 'CampaignState.set_chapter_flag("campaign_complete")' in runtime


def test_unpaid_cost_and_common_rupture_follow_mechanical_boss_rule():
    chapter = load('data/levels/chapter_10_final_choice.json')
    world = load('data/levels/chapter_10_world.json')
    contracts = load('data/boss_design_contracts.json')
    boss_runtime = (ROOT / 'scripts/world/chapter_10_boss_runtime.gd').read_text()
    bridge = (ROOT / 'scripts/world/ashlands_combat_bridge.gd').read_text()
    ids = {b['id'] for b in contracts['bosses']}
    assert {'c10_unpaid_cost','c10_boss_final'} <= ids
    assert chapter['miniboss']['signature'] == "Quelqu'un paiera"
    assert chapter['boss']['signature'] == 'Ce que nous refusons de sacrifier'
    assert len([n for n in world['nodes'] if n['type'] == 'cost']) == 3
    assert len([n for n in world['nodes'] if n['type'] == 'rupture_anchor']) == 3
    assert '[85,55,25,0]' in boss_runtime
    assert '[95,70,40,0]' in boss_runtime
    assert 'c10_unpaid_cost' in bridge and 'c10_boss_final' in bridge


def test_chapter_ten_is_routed_autoloaded_saved_reset_and_visible():
    project = (ROOT / 'project.godot').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    save = (ROOT / 'scripts/core/save_manager.gd').read_text()
    game = (ROOT / 'scripts/core/game_state.gd').read_text()
    ui = (ROOT / 'scripts/ui/chapter_10_journal_ui.gd').read_text()
    assert 'Chapter10Runtime="*res://scripts/world/chapter_10_runtime.gd"' in project
    assert 'Chapter10BossRuntime="*res://scripts/world/chapter_10_boss_runtime.gd"' in project
    assert 'Chapter10JournalUI="*res://scripts/ui/chapter_10_journal_ui.gd"' in project
    assert 'func start_chapter_10()' in router
    assert 'SAVE_VERSION := "0.30"' in save
    assert '"chapter_10": Chapter10Runtime.serialize()' in save
    assert 'Chapter10Runtime.reset_new_game()' in game
    assert 'OUVRIR LE CONSEIL DU MONDE' in ui
    assert 'ORIENTATIONS RÉELLEMENT DISPONIBLES' in ui
    assert 'ORIENTATIONS NON RÉALISABLES PAR CETTE PARTIE' in ui


def test_all_six_success_endings_and_three_failure_states_change_sanctuary():
    layers = load('data/levels/sanctuary_state_layers.json')['layers']
    ids = {layer['id'] for layer in layers}
    expected = {
        'ending_radical_closure','ending_stable_coexistence','ending_preserve_crossings',
        'ending_seek_absent','ending_restore_concord','ending_transform_concord',
        'ending_fractured_survival','ending_authoritarian_order','ending_veil_dissolution'
    }
    assert expected <= ids
    for layer in layers:
        if layer['id'] in expected:
            assert layer['priority'] >= 110
            assert layer['visual'] and layer['audio'] and layer['population']


def test_final_revelation_keeps_light_in_the_dark_core_motto():
    chapter = load('data/levels/chapter_10_final_choice.json')
    assert 'La lumière ne supprime pas' in chapter['end_revelation']
    assert 'qui paie le prix' in chapter['end_revelation']
