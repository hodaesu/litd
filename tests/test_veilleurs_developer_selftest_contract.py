from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "data/veilleurs/developer_selftest_contract.json"
MAIN_SCENE = ROOT / "scenes/Main.tscn"
RUNNER = ROOT / "tools/playtest/run_veilleurs_first_playtest.py"
OVERLAY = ROOT / "scripts/qa/developer_selftest_overlay.gd"


def test_developer_selftest_contract_is_focus_locked() -> None:
    data = json.loads(CONTRACT.read_text(encoding="utf-8"))
    assert data["mode"] == "developer_selftest"
    assert data["target_duration_minutes"] == [30, 45]
    assert data["canonical_watchers"] == ["Sahen Varo", "Mira Sen", "Narem Osh", "Ysra Nahal"]
    assert [row["id"] for row in data["steps"]] == [
        "sanctuary_preparation",
        "short_exploration",
        "combat_readability",
        "position_anatomy",
        "fear_madness",
        "elite_recombination",
        "final_consequence",
        "sanctuary_return",
    ]
    rules = data["rules"]
    assert rules["human_gate_promotion_allowed"] is False
    assert rules["developer_selftest_is_not_naive_playtest"] is True
    assert rules["no_new_content_to_fix_comprehension"] is True
    assert rules["normal_game_must_remain_unchanged_when_selftest_flag_absent"] is True


def test_developer_overlay_is_opt_in_only() -> None:
    scene = MAIN_SCENE.read_text(encoding="utf-8")
    overlay = OVERLAY.read_text(encoding="utf-8")
    runner = RUNNER.read_text(encoding="utf-8")

    assert "developer_selftest_overlay.gd" in scene
    assert "--developer-selftest" in overlay
    assert "OS.get_cmdline_user_args()" in overlay
    assert 'DEVELOPER_SELFTEST_ID = "developer-selftest"' in runner
    assert 'launch_command += ["--", "--developer-selftest"]' in runner
    assert "human_gate_promotion_allowed\": false" in overlay
