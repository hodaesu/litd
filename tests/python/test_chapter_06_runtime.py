import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_chapter_six_has_eight_stage_loop_and_campaign_unlock():
    data = json.loads((ROOT / 'data/levels/chapter_06_absent.json').read_text())
    assert data['chapter_id'] == 'chapter_06_absent'
    assert len(data['stages']) == 8
    assert data['unlock'] == 'chapter_07_living_responsible'
    assert {s['type'] for s in data['stages']} >= {'exploration','investigation','creature_investigation','campfire','miniboss','contact','boss','return'}


def test_chapter_six_world_has_seven_scenes_and_cross_source_signals():
    world = json.loads((ROOT / 'data/levels/chapter_06_world.json').read_text())
    assert len(world['zones']) == 7
    assert len(world['signals']) == 14
    assert len({s['source_family'] for s in world['signals']}) >= 5
    for zone in world['zones']:
        assert (ROOT / f"scenes/world/chapter_06/{zone['id']}.tscn").exists()


def test_creature_mediation_has_direct_and_non_blocking_proxy_paths():
    runtime = (ROOT / 'scripts/world/chapter_06_runtime.gd').read_text()
    design = json.loads((ROOT / 'data/levels/chapter_06_absent.json').read_text())
    assert 'CreatureManager.active_creature()' in runtime
    assert 'direct_reaction_count() >= 2' in runtime
    assert 'proxy_reaction_count() >= 3' in runtime
    assert design['creature_mediation']['ethic']


def test_saen_contact_requires_evidence_but_keeps_ontology_open():
    data = json.loads((ROOT / 'data/levels/chapter_06_absent.json').read_text())
    runtime = (ROOT / 'scripts/world/chapter_06_runtime.gd').read_text()
    assert data['saen']['name'] == 'Saen'
    assert 'nature ontologique non résolue' in data['saen']['status']
    assert 'signal_count() < 8' in runtime
    assert 'independent_source_family_count() < 4' in runtime
    assert 'stable_contact' in runtime


def test_walking_boundary_uses_three_environmental_anchors():
    data = json.loads((ROOT / 'data/levels/chapter_06_absent.json').read_text())
    world = json.loads((ROOT / 'data/levels/chapter_06_world.json').read_text())
    boss = (ROOT / 'scripts/world/chapter_06_boss_runtime.gd').read_text()
    boundary_nodes = [n for n in world['nodes'] if n['type'] == 'anchor']
    assert len(boundary_nodes) == 3
    assert data['boss']['name'] == 'La Frontière qui marche'
    assert data['boss']['signature'] == "Ici n'est plus ici"
    assert '[85,60,35,0]' in boss
    assert 'Chapter06Runtime.anchor_count()' in boss


def test_shifted_wayfarer_has_a_real_mechanical_contract():
    contracts = json.loads((ROOT / 'data/boss_design_contracts.json').read_text())
    entry = next(b for b in contracts['bosses'] if b['id'] == 'c06_shifted_wayfarer')
    runtime = (ROOT / 'scripts/world/chapter_06_boss_runtime.gd').read_text()
    assert entry['signature'] == 'Un pas trop tôt'
    assert len(entry['mechanics']) >= 1
    assert 'POSITION DÉCALÉE' in runtime and 'CONVERGENCE' in runtime


def test_chapter_six_is_autoloaded_routed_saved_reset_and_in_journal():
    project = (ROOT / 'project.godot').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    save = (ROOT / 'scripts/core/save_manager.gd').read_text()
    game = (ROOT / 'scripts/core/game_state.gd').read_text()
    journal = (ROOT / 'scripts/ui/quest_journal_ui.gd').read_text()
    bridge = (ROOT / 'scripts/world/ashlands_combat_bridge.gd').read_text()
    assert 'Chapter06Runtime="*res://scripts/world/chapter_06_runtime.gd"' in project
    assert 'Chapter06BossRuntime="*res://scripts/world/chapter_06_boss_runtime.gd"' in project
    assert 'func start_chapter_06()' in router
    assert 'SAVE_VERSION := "0.26"' in save
    assert '"chapter_06": Chapter06Runtime.serialize()' in save
    assert 'Chapter06Runtime.reset_new_game()' in game
    assert '_stage_header(parent, "CHAPITRE VI", Chapter06Runtime)' in journal
    assert 'DOSSIER DES ABSENTS' in journal
    assert 'ENTRER DANS LE JARDIN SANS SAISON' in journal
    assert 'c06_shifted_wayfarer' in bridge
    assert 'c06_boss_boundary' in bridge


def test_boundary_keeps_three_moral_outcomes():
    data = json.loads((ROOT / 'data/levels/chapter_06_absent.json').read_text())
    assert {c['id'] for c in data['boss_choices']} == {'force','resonate','withdraw'}
