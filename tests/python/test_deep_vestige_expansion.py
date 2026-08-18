import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    return json.loads((ROOT / path).read_text())


def test_three_deep_vestiges_are_playable_and_have_six_zones_each():
    index = load('data/world/deep_vestiges.json')
    assert {v['status'] for v in index['vestiges']} == {'playable'}
    files = {
        'vestige_ashai_seven_resonances': 'data/levels/vestige_ashai_seven_resonances.json',
        'vestige_or_silex_black_glass': 'data/levels/vestige_or_silex_black_glass.json',
        'vestige_saan_last_seal': 'data/levels/vestige_saan_last_seal.json',
    }
    for vestige_id, path in files.items():
        data = load(path)
        assert data['vestige_id'] == vestige_id
        assert len(data['zones']) == 6
        for zone in data['zones']:
            assert (ROOT / f"scenes/world/deep_vestiges/{zone['id']}.tscn").exists()


def test_deep_vestige_runtime_is_generic_and_persistent():
    runtime = (ROOT / 'scripts/world/deep_vestige_runtime.gd').read_text()
    assert 'DATA_PATHS' in runtime
    assert 'vestige_or_silex_black_glass' in runtime
    assert 'vestige_saan_last_seal' in runtime
    assert 'func fragment_count_for' in runtime
    assert 'func _try_complete' in runtime
    assert 'func serialize()' in runtime


def test_deep_vestige_bosses_have_distinct_counterplay():
    runtime = (ROOT / 'scripts/world/deep_vestige_boss_runtime_v2.gd').read_text()
    bridge = (ROOT / 'scripts/world/ashlands_combat_bridge.gd').read_text()
    contracts = load('data/boss_design_contracts.json')
    ids = {b['id'] for b in contracts['bosses']}
    for boss_id in ['vestige_ashai_boss_seventh_voice','vestige_silex_boss_last_strategist','vestige_saan_boss_last_watch']:
        assert boss_id in ids
        assert boss_id in runtime
        assert boss_id in bridge
    assert 'VICTOIRE PRÉDITE' in runtime
    assert 'SCEAU RÉACTIF' in runtime
    assert 'ACCORD FORCÉ' in runtime


def test_deep_vestige_ui_lists_all_three_dungeons():
    ui = (ROOT / 'scripts/ui/deep_vestige_ui.gd').read_text()
    router = (ROOT / 'scripts/world/ashlands_scene_router.gd').read_text()
    assert 'Temple des Sept Résonances' in ui
    assert 'Citadelle sous le Verre Noir' in ui
    assert 'Monastère du Dernier Sceau' in ui
    assert 'func start_or_silex_deep_vestige()' in router
    assert 'func start_saan_deep_vestige()' in router
