from pathlib import Path

ROOT = Path(__file__).parents[1]


def test_canonical_player_entry_uses_neutral_runtime():
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    bridge = (ROOT / "scripts/world/veilleurs_playable_bridge.gd").read_text(encoding="utf-8")
    ui = (ROOT / "scripts/ui/veilleurs_vertical_slice.gd").read_text(encoding="utf-8")
    scene = (ROOT / "scenes/veilleurs/vertical_slice.tscn").read_text(encoding="utf-8")

    assert 'VeilleursPlayableBridge="*res://scripts/world/veilleurs_playable_bridge.gd"' in project
    assert 'launch_button.text = "LES VEILLEURS"' in bridge
    assert "VeilleursRuntime" in bridge
    assert "vs001" not in bridge.lower()
    assert "VeilleursRuntime.runtime" in ui
    assert "SaveManager.save_game()" in ui
    assert "SaveManager.load_game()" in ui
    assert "scripts/ui/veilleurs_vertical_slice.gd" in scene


def test_legacy_bridge_is_resume_only_in_normal_boot():
    legacy = (ROOT / "scripts/world/veilleurs_vs001_playable_bridge.gd").read_text(encoding="utf-8")
    assert "LES VEILLEURS · VS001" not in legacy
    assert "LaunchVeilleursVS001" not in legacy
    assert "_install_launch_ui" not in legacy
    assert "resume_playable()" in legacy
    assert 'SaveManager.last_operation == "load"' in legacy


def test_production_scene_has_no_legacy_dependency():
    for relative in (
        "scripts/ui/veilleurs_vertical_slice.gd",
        "scripts/world/veilleurs_playable_bridge.gd",
        "scenes/veilleurs/vertical_slice.tscn",
    ):
        text = (ROOT / relative).read_text(encoding="utf-8").lower()
        assert "vs001" not in text, f"production player entry leaked legacy dependency: {relative}"
