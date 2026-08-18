import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads((ROOT / path).read_text())


def test_chapter_five_has_eight_stages_and_seven_playable_zones():
    chapter = load('data/levels/chapter_05_great_closure.json')
    world = load('data/levels/chapter_05_world.json')
    assert chapter['chapter_id'] == 'chapter_05_great_closure'
    assert len(chapter['stages']) == 8
    assert len(world['zones']) == 7
    for zone in world['zones']:
        assert (ROOT / f"scenes/world/chapter_05/{zone['id']}.tscn").exists()


def test_chapter_five_crosses_military_civilian_and_saan_sources():
    chapter = load('data/levels/chapter_05_great_closure.json')
    world = load('data/levels/chapter_05_world.json')
    assert len(world['fragments']) == 14
    categories = {f['category'] for f in world['fragments']}
    assert {'military','civilian','saan'} <= categories
    rules = chapter['investigation']
    assert rules['required_fragments'] >= 8
    assert rules['independent_source_families'] >= 4
    assert rules['civilian_sources_min'] >= 2
    assert rules['saan_sources_min'] >= 2


def test_general_of_silex_is_mechanical_not_hp_sponge():
    chapter = load('data/levels/chapter_05_great_closure.json')
    runtime = (ROOT / 'scripts/world/chapter_05_boss_runtime.gd').read_text()
    assert chapter['boss']['name'] == 'Le Général de Silex'
    assert len(chapter['boss']['phases']) == 3
    assert chapter['boss']['signature'] == 'Ordre qui ne finit jamais'
    assert 'damage_reduction' in runtime
    assert 'DOCTRINE ADAPTATIVE' in runtime
    assert 'set_process(true)' in runtime


def test_chapter_five_is_routed_saved_reset_and_visible_in_journal():
    project = (ROOT / 'project.godot').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    save = (ROOT / 'scripts/core/save_manager.gd').read_text()
    game = (ROOT / 'scripts/core/game_state.gd').read_text()
    journal = (ROOT / 'scripts/ui/quest_journal_ui.gd').read_text()
    assert 'Chapter05Runtime="*res://scripts/world/chapter_05_runtime.gd"' in project
    assert 'Chapter05BossRuntime="*res://scripts/world/chapter_05_boss_runtime.gd"' in project
    assert 'func start_chapter_05()' in router
    assert 'SAVE_VERSION := "0.25"' in save
    assert '"chapter_05": Chapter05Runtime.serialize()' in save
    assert 'Chapter05Runtime.reset_new_game()' in game
    assert 'PROGRESSION DU CHAPITRE V' in journal
    assert 'DOSSIER OR-SILEX / SAAN' in journal


def test_chapter_five_unlocks_absents_and_deep_vestiges():
    chapter = load('data/levels/chapter_05_great_closure.json')
    index = load('data/world/deep_vestiges.json')
    assert chapter['unlock'] == 'chapter_06_absent'
    by_id = {v['id']: v for v in index['vestiges']}
    assert by_id['vestige_or_silex_black_glass']['unlock']['flag'] == 'c05_weaponized_reality_confirmed'
    assert by_id['vestige_saan_last_seal']['unlock']['flag'] == 'c05_saan_network_confirmed'
