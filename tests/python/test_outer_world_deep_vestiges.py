import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

VESTIGES = {
    'vestige_vaor_khal_thousand_orders.json': ('Cités de Vaor-Khal', 'vestige_vaor_boss_command_without_body', "Obéissez et le chemin s'ouvrira"),
    'vestige_lyr_mar_reversed_tides.json': ('Navigateurs de Lyr-Mar', 'vestige_lyrmar_boss_absent_cartographer', 'Toutes les routes reviennent'),
    'vestige_sahm_ir_sealed_voices.json': ('Cités de Sahm-Ir', 'vestige_sahmir_boss_single_interpreter', 'Un seul sens'),
    'vestige_ydris_impossible_causes.json': ("Ateliers d'Ydris", 'vestige_ydris_boss_living_theorem', 'Déjà calculé'),
}


def load(path):
    return json.loads((ROOT / path).read_text())


def test_four_outer_world_ancient_civilizations_are_distinct_from_modern_regimes():
    data = load('data/world/outer_world_ancient_civilizations.json')
    assert len(data['civilizations']) == 4
    assert {c['name'] for c in data['civilizations']} == {'Cités de Vaor-Khal','Navigateurs de Lyr-Mar','Cités de Sahm-Ir',"Ateliers d'Ydris"}
    assert {c['modern_world'] for c in data['civilizations']} == {'varkhane','namar','azravel','kor_em'}
    assert all(c['collapse'] and c['legacy'] and c['deep_question'] for c in data['civilizations'])
    assert 'continuation juridique' in next(c for c in data['civilizations'] if c['id'] == 'vaor_khal')['legacy']


def test_each_outer_world_vestige_is_a_full_six_zone_optional_dungeon():
    for filename, (civilization, boss_id, signature) in VESTIGES.items():
        data = load(f'data/levels/{filename}')
        assert data['optional'] is True
        assert data['difficulty_tier'] == 'deep_vestige'
        assert data['recommended_level_offset'] >= 5
        assert data['civilization'] == civilization
        assert len(data['zones']) == 6
        assert len(data['fragments']) == 9
        assert data['completion_requirements']['boss'] == boss_id
        assert data['completion_requirements']['fragments_min'] >= 7
        assert data['boss']['id'] == boss_id
        assert data['boss']['signature'] == signature
        assert len(data['boss']['phases']) == 3
        assert data['boss']['environmental_solution']
        assert len(data['boss']['alternate_resolutions']) == 3
        assert data['boss']['punishes_bruteforce']
        assert data['rewards']['relic']['id']
        assert data['rewards']['deep_truth']['id']


def test_each_outer_world_vestige_has_miniboss_and_boss_combat_identity():
    bridge = (ROOT / 'scripts/world/ashlands_combat_bridge.gd').read_text()
    boss_runtime = (ROOT / 'scripts/world/deep_vestige_boss_runtime_v2.gd').read_text()
    contracts = load('data/boss_design_contracts.json')['bosses']
    contract_ids = {b['id'] for b in contracts}
    expected_bosses = {
        'vestige_vaor_boss_command_without_body',
        'vestige_lyrmar_boss_absent_cartographer',
        'vestige_sahmir_boss_single_interpreter',
        'vestige_ydris_boss_living_theorem',
    }
    expected_minibosses = {'vv_miniboss_order_bearer','vm_miniboss_drowned_pilot','vz_miniboss_stone_cantor','vy_miniboss_causal_auditor'}
    assert expected_bosses | expected_minibosses <= contract_ids
    for boss_id in expected_bosses:
        assert boss_id in bridge
        assert boss_id in boss_runtime
    for miniboss_id in expected_minibosses:
        assert miniboss_id in bridge


def test_new_vestiges_unlock_from_physical_chapter_eight_traces():
    index = load('data/world/deep_vestiges.json')['vestiges']
    outer = {v['modern_world']: v for v in index if v.get('modern_world')}
    traces = {t['power']: t for t in load('data/levels/chapter_08_ancient_traces.json')['traces']}
    assert set(outer) == set(traces) == {'varkhane','namar','azravel','kor_em'}
    for world_id in outer:
        assert outer[world_id]['unlock']['chapter'] == 'chapter_08_outer_world'
        assert outer[world_id]['unlock']['flag'] == traces[world_id]['unlock_flag']
        assert outer[world_id]['id'] == traces[world_id]['vestige_id']
        assert outer[world_id]['status'] == 'playable'


def test_generic_deep_vestige_builder_avoids_twenty_four_duplicate_scenes():
    builder = (ROOT / 'scripts/world/deep_vestige_blockout_builder.gd').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    scene = (ROOT / 'scenes/world/deep_vestiges/generic_deep_vestige.tscn').read_text()
    assert 'use_pending_zone' in builder
    assert 'DeepVestigeRuntime.pending_zone_id' in builder
    assert 'data_path_for_zone' in builder
    assert '_register_dynamic_deep_vestige_zones' in router
    assert 'generic_deep_vestige.tscn' in router
    assert 'use_pending_zone = true' in scene
