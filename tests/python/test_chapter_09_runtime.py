import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads((ROOT / path).read_text())


def test_chapter_nine_has_eight_stage_synthesis_loop_and_seven_zones():
    chapter = load('data/levels/chapter_09_veil_nature.json')
    world = load('data/levels/chapter_09_world.json')
    assert chapter['chapter_id'] == 'chapter_09_veil_nature'
    assert len(chapter['stages']) == 8
    assert len(world['zones']) == 7
    assert chapter['unlock'] == 'chapter_10_final_choice'
    assert set(chapter['main_quest_bindings']) == {'c09_shared_reality','c09_fear_shape','c09_no_final_answer'}
    for zone in world['zones']:
        assert (ROOT / f"scenes/world/chapter_09/{zone['id']}.tscn").exists()


def test_seven_ancient_civilizations_are_compared_without_making_vestiges_mandatory():
    chapter = load('data/levels/chapter_09_veil_nature.json')
    lenses = chapter['ancient_lenses']
    assert len(lenses) == 7
    assert {l['civilization'] for l in lenses} == {
        'Ashaï de Nhal', "Royaumes d'Or-Silex", 'Veilleurs de Saan',
        'Cités de Vaor-Khal', 'Navigateurs de Lyr-Mar', 'Cités de Sahm-Ir', "Ateliers d'Ydris"
    }
    rule = chapter['model_rules']['rule']
    assert 'facultatifs' in rule
    assert chapter['model_rules']['ancient_lenses_required'] == 7
    assert chapter['model_rules']['deep_truths_for_high_confidence'] >= 3


def test_models_keep_observation_interpretation_and_unknowns_separate():
    chapter = load('data/levels/chapter_09_veil_nature.json')
    world = load('data/levels/chapter_09_world.json')
    assert len(chapter['models']) == 5
    assert len(world['observations']) >= 19
    assert len({o['source_family'] for o in world['observations']}) >= 10
    assert all(m['required_support'] >= 3 and m['required_families'] >= 3 for m in chapter['models'])
    revelation = chapter['end_revelation'].lower()
    assert any(marker in revelation for marker in ('inconnue', 'ne savons toujours pas', 'ne savons pas'))
    assert 'volonté' in revelation


def test_deep_truths_raise_confidence_but_are_not_required_for_stage_two():
    runtime = (ROOT / 'scripts/world/chapter_09_runtime.gd').read_text()
    assert 'func deep_truth_count()' in runtime
    assert 'func confidence_for(model_id: String)' in runtime
    assert 'deep_truth_bonus_per_vestige' in runtime
    assert 'ancient_lenses_seen() >= 7' in runtime
    stage_two_section = runtime.split('_complete_if("c09_stage_02_lenses"', 1)[1].split('\n', 1)[0]
    assert 'deep_truth_count' not in stage_two_section


def test_consensus_boss_requires_three_perspectives_and_has_three_resolutions():
    chapter = load('data/levels/chapter_09_veil_nature.json')
    world = load('data/levels/chapter_09_world.json')
    runtime = (ROOT / 'scripts/world/chapter_09_boss_runtime.gd').read_text()
    contracts = load('data/boss_design_contracts.json')
    nodes = [n for n in world['nodes'] if n['type'] == 'perspective']
    assert len(nodes) == 3
    assert chapter['boss']['id'] == 'c09_boss_consensus'
    assert chapter['boss']['name'] == 'Le Consensus Brisé'
    assert chapter['boss']['signature'] == 'Nous ne voyons pas le même monde'
    assert len(chapter['boss']['alternate_resolutions']) == 3
    assert {c['id'] for c in chapter['boss_choices']} == {'single_anchor','negotiated_plurality','autonomous_zone'}
    assert '[90,65,35,0]' in runtime
    assert 'Chapter09Runtime.node_count("perspective")' in runtime
    assert any(b['id'] == 'c09_boss_consensus' for b in contracts['bosses'])


def test_fear_miniboss_teaches_probability_narrowing_not_creation_from_nothing():
    chapter = load('data/levels/chapter_09_veil_nature.json')
    world = load('data/levels/chapter_09_world.json')
    bridge = (ROOT / 'scripts/world/ashlands_combat_bridge.gd').read_text()
    boss_runtime = (ROOT / 'scripts/world/chapter_09_boss_runtime.gd').read_text()
    assert any(o['id'] == 'c09_obs_fear_not_creation' for o in world['observations'])
    fear_model = next(m for m in chapter['models'] if m['id'] == 'fear_narrows')
    assert "n'inventent pas librement" in fear_model['statement']
    assert 'c09_fear_echo' in bridge
    assert "C'était inévitable" in bridge
    assert 'POSSIBILITÉ ALTERNATIVE' in boss_runtime


def test_chapter_nine_is_routed_saved_reset_and_contextually_visible():
    project = (ROOT / 'project.godot').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    save = (ROOT / 'scripts/core/save_manager.gd').read_text()
    game = (ROOT / 'scripts/core/game_state.gd').read_text()
    ui = (ROOT / 'scripts/ui/chapter_09_journal_ui.gd').read_text()
    bridge = (ROOT / 'scripts/world/ashlands_combat_bridge.gd').read_text()
    assert 'Chapter09Runtime="*res://scripts/world/chapter_09_runtime.gd"' in project
    assert 'Chapter09BossRuntime="*res://scripts/world/chapter_09_boss_runtime.gd"' in project
    assert 'Chapter09JournalUI="*res://scripts/ui/chapter_09_journal_ui.gd"' in project
    assert 'func start_chapter_09()' in router
    assert 'SAVE_VERSION := "0.31"' in save
    assert '"chapter_09": Chapter09Runtime.serialize()' in save
    assert 'Chapter09Runtime.reset_new_game()' in game
    assert "DESCENDRE SOUS L'ARBRE" in ui
    assert 'INCONNUES MAINTENUES OUVERTES' in ui
    assert 'c09_boss_consensus' in bridge


def test_chapter_nine_unlocks_model_chamber_and_preserves_uncertainty():
    chapter = load('data/levels/chapter_09_veil_nature.json')
    sanctuary = load('data/levels/sanctuary_state_layers.json')
    by_id = {layer['id']: layer for layer in sanctuary['layers']}
    assert chapter['unique_rewards']['service']['name'] == 'Chambre des Modèles'
    assert 'model_chamber' in by_id
    assert 'sanctuary_model_chamber_unlocked' in by_id['model_chamber']['when']['campaign_any_flag']
    assert any('Ce que nous ne savons pas' in cue for cue in by_id['model_chamber']['visual'])
