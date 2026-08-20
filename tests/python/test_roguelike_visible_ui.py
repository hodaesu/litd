from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_main_scene_uses_roguelike_ui_layer():
    scene = (ROOT / "scenes" / "Main.tscn").read_text(encoding="utf-8")
    assert 'res://scripts/ui/main_v24.gd' in scene


def test_visible_expedition_uses_procedural_runtime():
    ui = (ROOT / "scripts" / "ui" / "main_v24.gd").read_text(encoding="utf-8")
    required = [
        "ExpeditionManager.start_expedition()",
        "ExpeditionManager.dungeon_layout()",
        "ExpeditionManager.enter_dungeon_room(room_id)",
        "ExpeditionManager.current_risk_profile()",
        "ExpeditionManager.deliberately_dim_light(1)",
        "ExpeditionManager.inventory_slots_used()",
        "ExpeditionManager.extraction_summary()",
        "ExpeditionManager.capture_check(capture_target, zone_id)",
        "ExpeditionManager.register_roguelike_capture(capture_target, zone_id)",
        "ExpeditionManager.return_to_hub(reason)",
    ]
    for contract in required:
        assert contract in ui


def test_visible_ui_exposes_push_your_luck_choices():
    ui = (ROOT / "scripts" / "ui" / "main_v24.gd").read_text(encoding="utf-8")
    assert "CONTINUER PLUS PROFOND" in ui
    assert "EXTRAIRE ET SÉCURISER" in ui
    assert "ÉTEINDRE 1 LUMIÈRE" in ui
    assert "MORT PERMANENTE" in ui
    assert "20 emplacements" in ui


def test_visible_capture_respects_roguelike_gate_before_creature_manager():
    ui = (ROOT / "scripts" / "ui" / "main_v24.gd").read_text(encoding="utf-8")
    gate = ui.index("ExpeditionManager.capture_check(capture_target, zone_id)")
    legacy_attempt = ui.index("CreatureManager.attempt_capture(capture_target)")
    registration = ui.index("ExpeditionManager.register_roguelike_capture(capture_target, zone_id)")
    assert gate < legacy_attempt < registration
