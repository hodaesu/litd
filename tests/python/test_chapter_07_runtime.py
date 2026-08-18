import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads((ROOT / path).read_text())


def test_chapter_seven_has_eight_stage_justice_loop_and_unlock():
    data = load('data/levels/chapter_07_living_responsible.json')
    assert data['chapter_id'] == 'chapter_07_living_responsible'
    assert len(data['stages']) == 8
    assert data['unlock'] == 'chapter_08_outer_world'
    assert {'cross_examination','campfire','miniboss','boss','return'} <= {s['type'] for s in data['stages']}


def test_living_responsible_world_has_seven_scenes_and_crossed_sources():
    world = load('data/levels/chapter_07_world.json')
    assert len(world['zones']) == 7
    assert len(world['testimonies']) >= 16
    assert len({e['source_family'] for e in world['testimonies']}) >= 8
    for zone in world['zones']:
        assert (ROOT / f"scenes/world/chapter_07/{zone['id']}.tscn").exists()


def test_bram_and_veyra_require_old_and_new_evidence_before_status_choice():
    runtime = (ROOT / 'scripts/world/chapter_07_runtime.gd').read_text()
    assert 'Chapter03Runtime.actor_links' in runtime
    assert 'testimony_count_for_actor(data_id) < 3' in runtime
    assert 'independent_source_count_for_actor(data_id) < 2' in runtime
    assert 'choose_provisional_outcome' in runtime
    data = load('data/levels/chapter_07_living_responsible.json')
    assert len(data['provisional_outcomes']['bram']) == 3
    assert len(data['provisional_outcomes']['veyra']) == 3


def test_edras_and_pilgrim_follow_global_boss_rule():
    data = load('data/levels/chapter_07_living_responsible.json')
    contracts = load('data/boss_design_contracts.json')
    ids = {b['id'] for b in contracts['bosses']}
    runtime = (ROOT / 'scripts/world/chapter_07_boss_runtime.gd').read_text()
    assert {'c07_opening_pilgrim','c07_boss_edras'} <= ids
    assert data['boss']['name'] == "Edras Nhal, l'Ouvert"
    assert len(data['boss']['phases']) == 3
    assert data['boss']['signature'] == 'Regardez enfin'
    assert '[80,55,30,0]' in runtime
    assert 'FAUSSE URGENCE' in runtime
    assert 'TRANSE ALIMENTÉE' in runtime


def test_controlled_trial_is_conditional_not_free_option():
    data = load('data/levels/chapter_07_living_responsible.json')
    controlled = next(c for c in data['boss_choices'] if c['id'] == 'controlled_trial')
    assert controlled['requirements']['anchors'] == 3
    assert controlled['requirements']['absent_contact_min'] >= 8
    assert controlled['requirements']['justice_integrity_min'] >= 45
    runtime = (ROOT / 'scripts/world/chapter_07_runtime.gd').read_text()
    assert 'func available_boss_choices()' in runtime
    assert 'justice_integrity_min' in runtime


def test_chapter_seven_is_autoloaded_routed_saved_reset_and_in_journal():
    project = (ROOT / 'project.godot').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    save = (ROOT / 'scripts/core/save_manager.gd').read_text()
    game = (ROOT / 'scripts/core/game_state.gd').read_text()
    journal = (ROOT / 'scripts/ui/quest_journal_ui.gd').read_text()
    bridge = (ROOT / 'scripts/world/ashlands_combat_bridge.gd').read_text()
    assert 'Chapter07Runtime="*res://scripts/world/chapter_07_runtime.gd"' in project
    assert 'Chapter07BossRuntime="*res://scripts/world/chapter_07_boss_runtime.gd"' in project
    assert 'func start_chapter_07()' in router
    assert 'SAVE_VERSION := "0.30"' in save
    assert '"chapter_07": Chapter07Runtime.serialize()' in save
    assert 'Chapter07Runtime.reset_new_game()' in game
    assert 'CHAPITRE VII' in journal and 'DOSSIER DE RESPONSABILITÉ' in journal
    assert 'c07_opening_pilgrim' in bridge and 'c07_boss_edras' in bridge


def test_chapter_seven_unlocks_public_hearing_without_collective_guilt():
    data = load('data/levels/chapter_07_living_responsible.json')
    layers = load('data/levels/sanctuary_state_layers.json')
    assert 'sans accuser leurs populations' in data['end_revelation']
    public = next(layer for layer in layers['layers'] if layer['id'] == 'public_hearing')
    assert 'sanctuary_public_hearing_unlocked' in public['when']['campaign_any_flag']
