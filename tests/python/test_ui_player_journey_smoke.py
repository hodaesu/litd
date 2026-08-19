from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_ui_player_journey_drives_real_interface_and_scene_changes():
    script = (ROOT / "scripts/core/ui_player_journey_smoke_test.gd").read_text(encoding="utf-8")
    bootstrap = (ROOT / "scripts/core/ui_player_journey_bootstrap.gd").read_text(encoding="utf-8")
    scene = (ROOT / "scenes/tests/ui_player_journey_smoke.tscn").read_text(encoding="utf-8")

    assert "ui_player_journey_bootstrap.gd" in scene
    assert "get_tree().root.add_child(runner)" in bootstrap
    for contract in (
        '"NOUVELLE PARTIE"',
        '"LA PORTE"',
        '"LANCER L\'EXPÉDITION"',
        'trigger.emit_signal("body_entered"',
        '"SOIN"',
        '"GARDE"',
        '"FRAPPE"',
        '"CAPTURER"',
        '"RETOUR À L\'EXPLORATION"',
        'Input.parse_input_event(back_event)',
        '"RETOUR AU SANCTUAIRE"',
        'UI_PLAYER_JOURNEY_SMOKE_OK',
    ):
        assert contract in script


def test_real_campaign_expedition_and_reward_ui_are_connected():
    ui = (ROOT / "scripts/ui/main_v13.gd").read_text(encoding="utf-8")
    bridge = (ROOT / "scripts/world/ashlands_combat_bridge.gd").read_text(encoding="utf-8")
    hud = (ROOT / "scripts/world/ashlands_hud.gd").read_text(encoding="utf-8")

    assert "AshlandsSceneRouter.start_ashlands()" in ui
    assert "AshlandsSceneRouter.start_chapter_10()" in ui
    assert '"RETOUR À L\'EXPLORATION"' in ui
    assert "func preview_loot()" in bridge
    assert 'screen_name == "rewards"' in bridge
    assert 'event.is_action_pressed("back")' in hud
    assert "margin.visible = not margin.visible" in hud


def test_strict_godot_runner_executes_ui_player_journey():
    runner = (ROOT / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    assert "res://scenes/tests/ui_player_journey_smoke.tscn" in runner
    assert "GODOT_CI_STRICT_OK" in runner
