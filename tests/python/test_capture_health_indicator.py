from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_capture_readiness_is_centralized_and_respects_unlock_and_threshold():
    manager = (ROOT / "scripts/core/creature_manager.gd").read_text()
    assert "func capture_readiness(enemy: Dictionary) -> Dictionary:" in manager
    assert 'ContentScopeDirector.is_unlocked("capture")' in manager
    assert 'hp_ratio > hp_threshold' in manager
    assert 'GameState.essence < essence_cost' in manager
    assert 'result["ready"] = true' in manager


def test_enemy_health_bar_has_accessible_capture_indicator():
    ui = (ROOT / "scripts/ui/main.gd").read_text()
    assert "func make_enemy_health_bar(enemy: Dictionary) -> VBoxContainer:" in ui
    assert "CreatureManager.capture_readiness(enemy)" in ui
    assert 'fill.bg_color = Color(0.42, 0.78, 0.66)' in ui
    assert '◇ CAPTURABLE' in ui
    assert "make_enemy_health_bar(e)" in ui


def test_indicator_handles_insufficient_essence_without_false_ready_state():
    ui = (ROOT / "scripts/ui/main.gd").read_text()
    assert 'str(readiness.get("state", "")) == "no_essence"' in ui
    assert 'CAPTURABLE · ESSENCE %d' in ui
    assert "assez d’Essence" in ui
