from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_runtime_player_smoke_covers_real_player_operations():
    script = (ROOT / "scripts/core/runtime_player_smoke_test.gd").read_text(encoding="utf-8")
    scene = (ROOT / "scenes/tests/runtime_player_smoke.tscn").read_text(encoding="utf-8")
    assert "runtime_player_smoke_test.gd" in scene
    for contract in (
        "AshlandsSceneRouter.has_zone",
        "PackedScene",
        "ExpeditionManager.start_expedition",
        "EquipmentManager.grant_random_party_weapon",
        "CreatureManager.attempt_capture",
        "CreatureManager.companion_turn",
        "SaveManager.save_game()",
        "SaveManager.load_game()",
        "FileAccess.file_exists(SaveManager.SAVE_PATH)",
        "RUNTIME_PLAYER_SMOKE_OK",
    ):
        assert contract in script


def test_strict_godot_runner_executes_runtime_player_smoke():
    runner = (ROOT / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    assert "res://scenes/tests/runtime_player_smoke.tscn" in runner
    assert "GODOT_CI_STRICT_OK" in runner
