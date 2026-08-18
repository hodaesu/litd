import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_chapter_two_world_has_five_playable_scenes_and_investigation_data():
    data = json.loads((ROOT / 'data/levels/chapter_02_world.json').read_text())
    zones = data['zones']
    assert len(zones) == 5
    ids = {z['id'] for z in zones}
    assert ids == {'c02_old_road','c02_watchpost','c02_quarry_camp','c02_buried_archive','c02_resonance_station'}
    assert len(data['clues']) == 13
    assert any(c['authenticity'] == 'false' for c in data['clues'])
    assert len(data['hypotheses']) >= 4
    for zone_id in ids:
        assert (ROOT / f'scenes/world/chapter_02/{zone_id}.tscn').exists()


def test_chapter_two_builder_creates_contextual_world_without_exploration_hud():
    builder = (ROOT / 'scripts/world/chapter_02_blockout_builder.gd').read_text()
    assert 'EncounterTrigger.new()' in builder
    assert 'Chapter02Clue' in builder
    assert 'CampfireInteraction.new()' in builder
    assert 'ZoneTransitionGate.new()' in builder
    assert 'HUD' not in builder


def test_chapter_two_runtime_requires_independent_sources_and_persists():
    runtime = (ROOT / 'scripts/world/chapter_02_runtime.gd').read_text()
    assert 'func independent_source_count()' in runtime
    assert 'source_groups.size()' in runtime
    assert 'confirmed_hypotheses' in runtime
    assert 'func choose_final_outcome(choice_id: String)' in runtime
    assert 'func serialize()' in runtime
    assert 'func deserialize(payload: Dictionary)' in runtime
    assert 'c02_old_instruments' in runtime
    assert 'c02_deleted_pages' in runtime
    assert 'c02_false_accident' in runtime


def test_conservator_and_sahra_are_connected_to_combat():
    bridge = (ROOT / 'scripts/world/ashlands_combat_bridge.gd').read_text()
    boss = (ROOT / 'scripts/world/chapter_02_boss_runtime.gd').read_text()
    assert 'c02_broken_curator' in bridge
    assert 'Le Conservateur Brisé' not in bridge or 'c02_broken_curator' in bridge
    assert 'c02_marker_warden' in bridge
    assert 'Sahra Vel — La Veilleuse des Bornes' in bridge
    assert 'La Carte qui se Souvient' in bridge
    assert 'ratio <= 0.65' in boss
    assert 'ratio <= 0.30' in boss


def test_chapter_two_is_routed_saved_reset_and_visible_in_journal():
    project = (ROOT / 'project.godot').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    save = (ROOT / 'scripts/core/save_manager.gd').read_text()
    game = (ROOT / 'scripts/core/game_state.gd').read_text()
    journal = (ROOT / 'scripts/ui/quest_journal_ui.gd').read_text()
    assert 'Chapter02Runtime="*res://scripts/world/chapter_02_runtime.gd"' in project
    assert 'Chapter02BossRuntime="*res://scripts/world/chapter_02_boss_runtime.gd"' in project
    assert 'func start_chapter_02()' in router
    assert 'SAVE_VERSION := "0.21"' in save
    assert '"chapter_02": Chapter02Runtime.serialize()' in save
    assert 'Chapter02Runtime.reset_new_game()' in game
    assert 'PROGRESSION DU CHAPITRE II' in journal
    assert 'ENQUÊTE — %d indices' in journal
    assert 'PARTIR SUR LA ROUTE DES BORNES' in journal
    assert 'Chapter02Runtime.final_choice_required.connect' in journal
