from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_main_scene_uses_descendants_hall_layer():
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")
    assert 'res://scripts/ui/main_v26.gd' in scene


def test_descendants_hall_keeps_progressive_disclosure_contract():
    ui = (ROOT / "scripts/ui/main_v26.gd").read_text(encoding="utf-8")
    assert 'extends "res://scripts/ui/main_v25.gd"' in ui
    assert 'func show_descendants_hall()' in ui
    assert 'MUR DES EXPÉDITIONS' in ui
    assert 'VITRINE DES RELIQUES' in ui
    assert 'selected_descent_chronicle_index' in ui
    assert 'runtime.chronicle_entries()' in ui
    assert 'runtime.collection()' in ui
    assert 'combat_bonus' in (ROOT / "scripts/core/first_descent_runtime.gd").read_text(encoding="utf-8")
