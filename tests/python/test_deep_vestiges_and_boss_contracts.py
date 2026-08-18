import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]


def test_all_known_campaign_bosses_have_mechanical_contracts():
    contracts = json.loads((ROOT/'data/boss_design_contracts.json').read_text())
    campaign = json.loads((ROOT/'data/world/main_campaign.json').read_text())
    contract_ids = {b['id'] for b in contracts['bosses']}
    known = {chapter['bosses'][0]['id'] for chapter in campaign['chapters']}
    aliases = {'c04_boss_chorus':'c04_boss_unfinished_chorus'}
    normalized = {aliases.get(i, i) for i in contract_ids}
    assert known.issubset(normalized | contract_ids)
    for boss in contracts['bosses']:
        assert boss['core_puzzle'].strip()
        assert boss['mechanics']
        assert boss['counterplay'].strip()
        assert boss['signature'].strip()


def test_deep_vestige_rule_covers_each_known_ancient_civilization():
    data = json.loads((ROOT/'data/world/deep_vestiges.json').read_text())
    civs = {v['civilization'] for v in data['vestiges']}
    assert {'Ashaï de Nhal', "Royaumes d'Or-Silex", 'Veilleurs de Saan'}.issubset(civs)
    assert data['difficulty']['recommended_offset_levels'] >= 4
    assert data['difficulty']['resource_abundance_multiplier'] < 1


def test_ashai_vestige_is_full_optional_dungeon_with_high_end_rewards():
    data = json.loads((ROOT/'data/levels/vestige_ashai_seven_resonances.json').read_text())
    assert data['optional'] is True
    assert len(data['zones']) == 6
    assert len(data['fragments']) == 10
    assert data['boss']['tier'] == 'deep_vestige_boss'
    assert len(data['boss']['phases']) == 3
    assert data['boss']['environmental_solution']
    assert data['boss']['punishes_bruteforce']
    assert data['rewards']['relic']['id'] == 'relic_anchor_lantern'
    assert data['rewards']['deep_truth']['id'] == 'deep_truth_ashai'
    for zone in data['zones']:
        assert (ROOT/f"scenes/world/deep_vestiges/{zone['id']}.tscn").exists()


def test_deep_vestige_is_routed_autoloaded_saved_and_reset():
    project = (ROOT/'project.godot').read_text()
    router = (ROOT/'scripts/world/ashlands_scene_router.gd').read_text()
    save = (ROOT/'scripts/core/save_manager.gd').read_text()
    game = (ROOT/'scripts/core/game_state.gd').read_text()
    ui = (ROOT/'scripts/ui/deep_vestige_ui.gd').read_text()
    assert 'DeepVestigeRuntime="*res://scripts/world/deep_vestige_runtime.gd"' in project
    assert 'DeepVestigeBossRuntime="*res://scripts/world/deep_vestige_boss_runtime_v2.gd"' in project
    assert 'func start_ashai_deep_vestige()' in router
    assert 'SAVE_VERSION := "0.28"' in save
    assert '"deep_vestiges": DeepVestigeRuntime.serialize()' in save
    assert 'DeepVestigeRuntime.reset_new_game()' in game
    assert 'Temple des Sept Résonances' in ui


def test_seventh_voice_is_connected_to_combat_and_punishes_repetition():
    bridge = (ROOT/'scripts/world/ashlands_combat_bridge.gd').read_text()
    boss = (ROOT/'scripts/world/deep_vestige_boss_runtime_v2.gd').read_text()
    assert 'vestige_ashai_boss_seventh_voice' in bridge
    assert 'La Septième Voix' in bridge
    assert 'Le Monde que Nous Accordons' in bridge
    assert 'ACCORD FORCÉ' in boss
    assert 'forced_agreement' in boss
