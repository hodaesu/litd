import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_chapter_three_has_six_playable_zones_and_six_actors():
    data = json.loads((ROOT / 'data/levels/chapter_03_threshold.json').read_text())
    world = json.loads((ROOT / 'data/levels/chapter_03_world.json').read_text())
    assert len(data['stages']) == 8
    assert len(data['actors']) == 6
    assert {a['name'] for a in data['actors']} == {'Veyra Oss','Edras Nhal','Sera Val-Khesh','Othmar Sevr','Bram Torgun','Eline Sar'}
    assert len(world['zones']) == 6
    for zone in world['zones']:
        assert (ROOT / f"scenes/world/chapter_03/{zone['id']}.tscn").exists()


def test_responsibility_requires_crossed_evidence():
    data = json.loads((ROOT / 'data/levels/chapter_03_threshold.json').read_text())
    rules = data['evidence_rules']
    assert rules['required_evidence'] >= 9
    assert rules['required_actor_links'] == 6
    assert rules['independent_source_groups'] >= 4
    assert rules['contradictions_required'] >= 2
    assert all(a['culpability'] and a['counterpoint'] for a in data['actors'])


def test_threshold_echo_has_three_outcomes_and_ancient_symbol_reveal():
    data = json.loads((ROOT / 'data/levels/chapter_03_threshold.json').read_text())
    assert data['boss']['name'] == "L'Écho du Seuil"
    assert len(data['boss']['phases']) == 3
    assert data['boss']['signature'] == 'Zéro Seconde'
    assert {c['id'] for c in data['boss_choices']} == {'break','record','prolong'}
    assert data['ancient_symbol_revelation']['unlock'] == 'chapter_04_first_rupture'


def test_chapter_three_runtime_builder_router_and_combat_are_connected():
    runtime = (ROOT / 'scripts/world/chapter_03_runtime.gd').read_text()
    builder = (ROOT / 'scripts/world/chapter_03_blockout_builder.gd').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    bridge = (ROOT / 'scripts/world/ashlands_combat_bridge.gd').read_text()
    boss = (ROOT / 'scripts/world/chapter_03_boss_runtime.gd').read_text()
    assert 'func collect_evidence' in runtime
    assert 'func actor_count_with_evidence' in runtime
    assert 'func independent_source_count' in runtime
    assert 'func choose_echo_outcome' in runtime
    assert 'Chapter03Evidence' in builder
    assert 'func start_chapter_03()' in router
    assert 'c03_threshold_sentinel' in bridge
    assert "L'Écho du Seuil" in bridge
    assert 'Zéro Seconde' in bridge
    assert 'ratio <= 0.65' in boss and 'ratio <= 0.30' in boss


def test_chapter_three_is_autoloaded_saved_reset_and_visible_in_journal():
    project = (ROOT / 'project.godot').read_text()
    save = (ROOT / 'scripts/core/save_manager.gd').read_text()
    game = (ROOT / 'scripts/core/game_state.gd').read_text()
    journal = (ROOT / 'scripts/ui/quest_journal_ui.gd').read_text()
    assert 'Chapter03Runtime="*res://scripts/world/chapter_03_runtime.gd"' in project
    assert 'Chapter03BossRuntime="*res://scripts/world/chapter_03_boss_runtime.gd"' in project
    assert 'SAVE_VERSION := "0.22"' in save
    assert '"chapter_03": Chapter03Runtime.serialize()' in save
    assert 'Chapter03Runtime.reset_new_game()' in game
    assert 'PROGRESSION DU CHAPITRE III' in journal
    assert 'DOSSIER DU PROJET SEUIL' in journal
    assert 'RESPONSABILITÉS DOCUMENTÉES' in journal
    assert 'ENTRER DANS LE RÉSEAU DU SEUIL' in journal
