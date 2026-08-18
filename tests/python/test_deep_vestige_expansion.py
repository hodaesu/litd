import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    normalized = str(path).removeprefix('res://')
    return json.loads((ROOT / normalized).read_text())


def test_all_seven_deep_vestiges_are_playable_and_data_driven():
    index = load('data/world/deep_vestiges.json')
    vestiges = index['vestiges']
    expected = {
        'vestige_ashai_seven_resonances',
        'vestige_or_silex_black_glass',
        'vestige_saan_last_seal',
        'vestige_vaor_khal_thousand_orders',
        'vestige_lyr_mar_reversed_tides',
        'vestige_sahm_ir_sealed_voices',
        'vestige_ydris_impossible_causes',
    }
    assert len(vestiges) == 7
    assert {v['id'] for v in vestiges} == expected
    assert {v['status'] for v in vestiges} == {'playable'}
    for entry in vestiges:
        assert entry['data_path'].startswith('res://data/levels/')
        data = load(entry['data_path'])
        assert data['vestige_id'] == entry['id']
        assert len(data.get('zones', [])) >= 6


def test_deep_vestige_runtime_is_generic_and_persistent():
    runtime = (ROOT / 'scripts/world/deep_vestige_runtime.gd').read_text()
    assert 'const INDEX_PATH := "res://data/world/deep_vestiges.json"' in runtime
    assert 'for value in index_data.get("vestiges", [])' in runtime
    assert 'var path := String(entry.get("data_path", ""))' in runtime
    assert 'vestige_data[id] = _load_json(path)' in runtime
    assert 'DATA_PATHS' not in runtime
    assert 'func fragment_count_for' in runtime
    assert 'func _try_complete' in runtime
    assert 'func serialize()' in runtime


def test_deep_vestige_bosses_have_distinct_counterplay():
    runtime = (ROOT / 'scripts/world/deep_vestige_boss_runtime_v2.gd').read_text()
    contracts = load('data/boss_design_contracts.json')
    index = load('data/world/deep_vestiges.json')
    ids = {b['id'] for b in contracts['bosses']}
    for entry in index['vestiges']:
        boss_id = entry['boss']
        assert boss_id in ids
        assert boss_id in runtime
    assert 'VICTOIRE PRÉDITE' in runtime
    assert 'SCEAU RÉACTIF' in runtime
    assert 'ACCORD FORCÉ' in runtime


def test_deep_vestige_ui_lists_all_indexed_dungeons_dynamically():
    ui = (ROOT / 'scripts/ui/deep_vestige_ui.gd').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    builder = (ROOT / 'scripts/world/deep_vestige_blockout_builder.gd').read_text()
    assert 'DeepVestigeRuntime.index_entries()' in ui
    assert '_add_vestige(id, String(entry.get("name", id))' in ui
    assert 'AshlandsSceneRouter.start_deep_vestige(String(id_value))' in ui
    assert 'func start_deep_vestige(vestige_id: String)' in router
    assert 'func _register_dynamic_deep_vestige_zones()' in router
    assert 'GENERIC_DEEP_VESTIGE_SCENE' in router
    assert 'use_pending_zone' in builder
    assert 'DeepVestigeRuntime.data_path_for_zone(zone_id)' in builder
    assert (ROOT / 'scenes/world/deep_vestiges/generic_deep_vestige.tscn').exists()
