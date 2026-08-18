import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]

def test_chapter_four_has_eight_stage_reference_loop():
    data = json.loads((ROOT/'data/levels/chapter_04_first_rupture.json').read_text())
    assert data['chapter_id'] == 'chapter_04_first_rupture'
    assert len(data['stages']) == 8
    types = [s['type'] for s in data['stages']]
    assert 'exploration' in types and 'campfire' in types and 'miniboss' in types and 'boss' in types and 'return' in types
    assert data['unlock'] == 'chapter_05_great_closure'

def test_chapter_four_world_has_six_scenes_and_twelve_fragments():
    world = json.loads((ROOT/'data/levels/chapter_04_world.json').read_text())
    assert len(world['zones']) == 6
    assert len(world['fragments']) == 12
    assert sum(1 for f in world['fragments'] if f.get('contradiction')) >= 2
    for zone in world['zones']:
        assert (ROOT/f"scenes/world/chapter_04/{zone['id']}.tscn").exists()

def test_archaeology_requires_cross_source_confirmation():
    runtime = (ROOT/'scripts/world/chapter_04_runtime.gd').read_text()
    assert 'func independent_source_family_count()' in runtime
    assert 'func contradiction_count()' in runtime
    assert 'confirmed_hypotheses' in runtime
    assert 'first_rupture' in runtime
    assert 'not_a_door' in runtime
    assert 'required_fragments' in runtime

def test_measure_and_chorus_reach_combat_runtime():
    bridge = (ROOT/'scripts/world/ashlands_combat_bridge.gd').read_text()
    boss = (ROOT/'scripts/world/chapter_04_boss_runtime.gd').read_text()
    assert 'c04_faceless_measure' in bridge
    assert 'Le Mesureur Sans Visage' in bridge
    assert 'c04_boss_unfinished_chorus' in bridge
    assert 'Le Chœur Inachevé' in bridge
    assert 'Nous étions plusieurs' in bridge
    assert 'ratio <= 0.65' in boss and 'ratio <= 0.30' in boss

def test_chapter_four_is_routed_saved_reset_and_visible_in_journal():
    project = (ROOT/'project.godot').read_text()
    router = (ROOT/'scripts/world/ashlands_scene_router.gd').read_text()
    save = (ROOT/'scripts/core/save_manager.gd').read_text()
    game = (ROOT/'scripts/core/game_state.gd').read_text()
    journal = (ROOT/'scripts/ui/quest_journal_ui.gd').read_text()
    assert 'Chapter04Runtime="*res://scripts/world/chapter_04_runtime.gd"' in project
    assert 'Chapter04BossRuntime="*res://scripts/world/chapter_04_boss_runtime.gd"' in project
    assert 'func start_chapter_04()' in router
    assert 'SAVE_VERSION := "0.26"' in save
    assert '"chapter_04": Chapter04Runtime.serialize()' in save
    assert 'Chapter04Runtime.reset_new_game()' in game
    assert 'PROGRESSION DU CHAPITRE IV' in journal
    assert 'ARCHÉOLOGIE ASHAÏ' in journal
    assert 'DESCENDRE VERS LA CITÉ DE NHAL' in journal

def test_chorus_has_three_moral_outcomes():
    data = json.loads((ROOT/'data/levels/chapter_04_first_rupture.json').read_text())
    assert {c['id'] for c in data['boss_choices']} == {'release','communicate','preserve'}
    assert data['boss']['name'] == 'Le Chœur Inachevé'
    assert data['boss']['signature'] == 'Nous étions plusieurs'
