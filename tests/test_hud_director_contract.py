from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def test_hud_director_contract_encodes_progressive_disclosure() -> None:
    contract = _load("data/hud_director_contract.json")
    assert contract["version"] == 1
    assert set(contract["information_levels"]) == {"0", "1", "2", "3", "4"}
    assert contract["exploration"]["default_level"] == 0
    assert contract["combat"]["default_level"] == 3
    assert contract["inspection"]["voluntary_only"] is True


def test_hud_priorities_prevent_low_value_interruptions() -> None:
    contract = _load("data/hud_director_contract.json")
    priorities = contract["priorities"]
    assert priorities["CRITICAL"]["weight"] > priorities["ACTIONABLE"]["weight"]
    assert priorities["ACTIONABLE"]["weight"] > priorities["CONTEXT"]["weight"]
    assert priorities["CONTEXT"]["weight"] > priorities["INFORMATION"]["weight"]
    assert priorities["INFORMATION"]["defer_when_critical"] is True
    assert priorities["DECORATIVE"]["never_interrupts"] is True


def test_combat_hud_is_limited_and_statuses_are_aggregated() -> None:
    combat = _load("data/hud_director_contract.json")["combat"]
    assert combat["visual_groups_max"] == 3
    assert combat["actions_visible_max"] <= 6
    assert combat["status_icons_visible_max"] == 2
    assert combat["status_overflow_format"] == "+N"
    assert combat["irreversible_action"] == "select_then_confirm"


def test_world_first_and_accessibility_rules_are_explicit() -> None:
    contract = _load("data/hud_director_contract.json")
    assert contract["core_rule"]["no_permanent_minimap"] is True
    assert contract["core_rule"]["no_permanent_quest_tracker"] is True
    assert contract["palette"]["information_never_color_only"] is True
    assert contract["accessibility"]["normal_contrast_ratio_min"] >= 4.5
    assert contract["accessibility"]["high_contrast_target"] >= 7.0
    assert contract["touch"]["touch_target_min_px"] >= 48


def test_runtime_and_smoke_are_wired() -> None:
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    runtime = (ROOT / "scripts/ui/hud_director.gd").read_text(encoding="utf-8")
    ci = (ROOT / "tools/build/run_godot_ci.sh").read_text(encoding="utf-8")
    assert 'HUDDirector="*res://scripts/ui/hud_director.gd"' in project
    for required in ["route_event", "summarize_statuses", "request_action", "consume_journal_backlog"]:
        assert f"func {required}" in runtime
    assert "res://scenes/tests/hud_director_smoke.tscn" in ci
