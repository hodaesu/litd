from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_exploration_hud_is_invisible_by_default_and_event_driven():
    director = read("scripts/ui/hud_director.gd")
    context = read("scripts/ui/context_hud.gd")
    assert 'LEVEL_WORLD_ONLY := 0' in director
    assert 'exploration_overlay_requested' in director
    assert 'EXPLORATION_CHANNELS' in director
    assert 'request_exploration_overlay' in director
    assert 'TransientExplorationHUD' in context
    assert '_exploration_overlay.visible = false' in context


def test_exploration_information_has_bounded_lifetimes():
    director = read("scripts/ui/hud_director.gd")
    for channel in ["status", "interaction", "selection", "notification", "quest", "danger"]:
        assert f'"{channel}"' in director
    assert "EXPLORATION_DEFAULT_TTL" in director
    assert "show_transient" in director


def test_status_is_explicit_and_cross_input_ready():
    project = read("project.godot")
    context = read("scripts/ui/context_hud.gd")
    assert "status_hud=" in project
    assert "InputEventKey" in project
    assert "InputEventJoypadButton" in project
    assert 'event.is_action_pressed("status_hud")' in context
    assert "request_party_status" in context


def test_combat_and_full_menus_clear_exploration_overlay():
    context = read("scripts/ui/context_hud.gd")
    assert 'HUD_VISIBLE_SCREENS' in context
    assert '_hide_exploration_overlay()' in context
    assert '"inventory", "equipment", "skill_trees", "journal", "settings", "inspection"' in context


def test_cinders_remain_world_guidance_without_hud_marker():
    director = read("scripts/ui/hud_director.gd")
    assert '"cendre"' in director
    assert '"hud_marker": false' in director


def test_quest_updates_use_contextual_overlay():
    quests = read("scripts/core/side_quest_runtime.gd")
    assert "HUDDirector.notify_quest" in quests


def test_fear_and_hope_are_postures_not_visible_gauges():
    context = read("scripts/ui/context_hud.gd")
    psychology = read("scripts/core/psychology_runtime.gd")
    assert "Peur %d" not in context
    assert "psychological_posture_label" in context
    assert "fear_band_label" in psychology
    assert "hope_band_label" in psychology


def test_fear_penalizes_and_hope_rewards_combat():
    psychology = read("scripts/core/psychology_runtime.gd")
    combat_ui = read("scripts/ui/main.gd")
    data = read("data/psychology_events.json")
    assert '"hope_bands"' in data
    assert '"precision": -' in data
    assert '"precision": 4' in data
    assert "PsychologyRuntime.combat_modifiers(hero)" in combat_ui
    assert 'result["damage_bonus"]' in combat_ui
