from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_mobile_ui_keeps_aspect_and_routes_through_v15():
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")
    v14 = (ROOT / "scripts/ui/main_v14.gd").read_text(encoding="utf-8")
    v15 = (ROOT / "scripts/ui/main_v15.gd").read_text(encoding="utf-8")
    assert 'window/stretch/mode="canvas_items"' in project
    assert 'window/stretch/aspect="keep"' in project
    assert 'res://scripts/ui/main_v15.gd' in scene
    assert 'extends "res://scripts/ui/main_v14.gd"' in v15
    assert 'extends "res://scripts/ui/main_v13.gd"' in v14


def test_mobile_touch_targets_and_bounds_are_guarded():
    v14 = (ROOT / "scripts/ui/main_v14.gd").read_text(encoding="utf-8")
    assert "MOBILE_MIN_TOUCH_HEIGHT: float = 48.0" in v14
    assert "MOBILE_MIN_TOUCH_WIDTH: float = 96.0" in v14
    assert "_clamp_free_button" in v14
    assert "_keep_last_button_with_text" in v14


def test_mobile_touch_smoke_is_in_strict_godot_ci():
    runner = (ROOT / "scripts/core/mobile_touch_smoke_test.gd").read_text(encoding="utf-8")
    scene = (ROOT / "scenes/tests/mobile_touch_smoke.tscn").read_text(encoding="utf-8")
    ci = (ROOT / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    for device in ["iphone_compact_landscape", "iphone_standard_landscape", "iphone_large_landscape"]:
        assert device in runner
    for screen in ["chapel", "tavern", "memorial"]:
        assert f'"{screen}"' in runner
    assert "InputEventScreenTouch" in runner
    assert "MOBILE_TOUCH_SMOKE_OK" in runner
    assert "mobile_touch_smoke_bootstrap.gd" in scene
    assert "mobile_touch_smoke.tscn" in ci
