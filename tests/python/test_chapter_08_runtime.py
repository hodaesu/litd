import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads((ROOT / path).read_text())


def test_chapter_eight_has_eight_stage_world_tour_and_four_campaign_quests():
    chapter = load('data/levels/chapter_08_outer_world.json')
    world = load('data/levels/chapter_08_world.json')
    assert chapter['chapter_id'] == 'chapter_08_outer_world'
    assert len(chapter['stages']) == 8
    assert len(world['zones']) == 8
    assert set(chapter['main_quest_bindings']) == {'c08_varkhane','c08_namar','c08_azravel','c08_korem'}
    assert chapter['unlock'] == 'chapter_09_veil_nature'
    for zone in world['zones']:
        assert (ROOT / f"scenes/world/chapter_08/{zone['id']}.tscn").exists()


def test_each_foreign_power_has_official_and_non_official_voices():
    chapter = load('data/levels/chapter_08_outer_world.json')
    world = load('data/levels/chapter_08_world.json')
    assert len(world['records']) == 16
    powers = {'varkhane','namar','azravel','kor_em'}
    for power in powers:
        records = [r for r in world['records'] if r['power'] == power]
        assert len(records) == 4
        assert any(r['kind'] in {'civilian','dissident'} for r in records)
        assert any(r['kind'] in {'official','technical'} for r in records)
    rules = chapter['investigation']
    assert rules['minimum_per_power'] >= 3
    assert rules['civilian_or_dissident_per_power'] >= 1
    assert rules['independent_source_families'] >= 6


def test_canonical_foreign_allies_and_collective_guilt_rule_are_preserved():
    chapter = load('data/levels/chapter_08_outer_world.json')
    names = {a['name'] for a in chapter['foreign_allies']}
    assert names == {'Capitaine Varek Sorn','Navigatrice Issel Pell','Frère Oren Val','Docteure Keira Om'}
    assert 'peuples' in chapter['theme'].lower()
    assert 'culpabilité' in chapter['theme'].lower()
    assert sum(1 for r in load('data/levels/chapter_08_world.json')['records'] if 'no_collective_guilt' in r.get('supports', [])) >= 8


def test_both_chapter_eight_bosses_use_authority_as_a_mechanical_defense():
    chapter = load('data/levels/chapter_08_outer_world.json')
    contracts = load('data/boss_design_contracts.json')
    runtime = (ROOT / 'scripts/world/chapter_08_boss_runtime.gd').read_text()
    bosses = {b['id']: b for b in chapter['bosses']}
    assert set(bosses) == {'c08_boss_varkhane','c08_boss_azravel'}
    assert bosses['c08_boss_varkhane']['signature'] == 'Ordre du Trône Vide'
    assert bosses['c08_boss_azravel']['signature'] == 'Une seule vérité'
    contract_ids = {b['id'] for b in contracts['bosses']}
    assert {'c08_boss_varkhane','c08_boss_azravel'} <= contract_ids
    assert '[75,50,25,0]' in runtime
    assert '[80,55,30,0]' in runtime
    assert 'Chapter08Runtime.authority_node_count' in runtime


def test_chapter_eight_runtime_requires_cross_source_understanding():
    runtime = (ROOT / 'scripts/world/chapter_08_runtime.gd').read_text()
    assert 'func power_understood(power_id: String)' in runtime
    assert 'civilian_or_dissident_count_for' in runtime
    assert 'independent_source_family_count' in runtime
    assert 'foreign_command_count' in runtime
    assert 'record_count() >= int(rules.get("required_records", 12))' in runtime
    assert 'foreign_command_count() >= int(rules.get("foreign_command_records", 4))' in runtime


def test_chapter_eight_is_routed_saved_reset_and_contextually_visible():
    project = (ROOT / 'project.godot').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    save = (ROOT / 'scripts/core/save_manager.gd').read_text()
    game = (ROOT / 'scripts/core/game_state.gd').read_text()
    ui = (ROOT / 'scripts/ui/chapter_08_journal_ui.gd').read_text()
    bridge = (ROOT / 'scripts/world/ashlands_combat_bridge.gd').read_text()
    assert 'Chapter08Runtime="*res://scripts/world/chapter_08_runtime.gd"' in project
    assert 'Chapter08BossRuntime="*res://scripts/world/chapter_08_boss_runtime.gd"' in project
    assert 'Chapter08JournalUI="*res://scripts/ui/chapter_08_journal_ui.gd"' in project
    assert 'func start_chapter_08()' in router
    assert 'SAVE_VERSION := "0.28"' in save
    assert '"chapter_08": Chapter08Runtime.serialize()' in save
    assert 'Chapter08Runtime.reset_new_game()' in game
    assert 'TRAVERSER VERS VARKHANE' in ui
    assert 'DOSSIER TRANSFRONTALIER' in ui
    assert 'HISTOIRE PROFONDE' in ui
    assert 'c08_boss_varkhane' in bridge and 'c08_boss_azravel' in bridge


def test_each_outer_world_has_an_ancient_trace_and_deep_vestige():
    traces = load('data/levels/chapter_08_ancient_traces.json')['traces']
    ancient = load('data/world/outer_world_ancient_civilizations.json')['civilizations']
    vestiges = load('data/world/deep_vestiges.json')['vestiges']
    assert len(traces) == 4
    assert len(ancient) == 4
    assert {t['power'] for t in traces} == {'varkhane','namar','azravel','kor_em'}
    assert {c['modern_world'] for c in ancient} == {'varkhane','namar','azravel','kor_em'}
    outer = [v for v in vestiges if v.get('modern_world')]
    assert len(outer) == 4
    assert {v['modern_world'] for v in outer} == {'varkhane','namar','azravel','kor_em'}
    assert {t['vestige_id'] for t in traces} == {v['id'] for v in outer}
    runtime = (ROOT / 'scripts/world/chapter_08_runtime.gd').read_text()
    builder = (ROOT / 'scripts/world/chapter_08_blockout_builder.gd').read_text()
    assert 'func collect_ancient_trace' in runtime
    assert 'collected_ancient_traces' in runtime
    assert '_build_ancient_traces' in builder


def test_outer_world_vestiges_use_generic_extensible_routing():
    runtime = (ROOT / 'scripts/world/deep_vestige_runtime.gd').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    ui = (ROOT / 'scripts/ui/deep_vestige_ui.gd').read_text()
    assert 'data_path' in (ROOT / 'data/world/deep_vestiges.json').read_text()
    assert 'func vestige_id_for_zone' in runtime
    assert 'func prepare_zone' in runtime
    assert 'func start_deep_vestige(vestige_id: String)' in router
    assert 'GENERIC_DEEP_VESTIGE_SCENE' in router
    assert 'DeepVestigeRuntime.index_entries()' in ui
    assert (ROOT / 'scenes/world/deep_vestiges/generic_deep_vestige.tscn').exists()
