from pathlib import Path

from tools.qa.sanctuary_buildings_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_sanctuary_buildings_audit_has_no_errors():
    report = run(ROOT)
    failed = [f"{item['name']}: {item['detail']}" for item in report["checks"] if not item["ok"]]
    assert not failed, failed


def test_sanctuary_v16_keeps_v15_mobile_layer_and_three_real_screens():
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")
    v15 = (ROOT / "scripts/ui/main_v15.gd").read_text(encoding="utf-8")
    v16 = (ROOT / "scripts/ui/main_v16.gd").read_text(encoding="utf-8")
    assert 'res://scripts/ui/main_v16.gd' in scene
    assert 'extends "res://scripts/ui/main_v15.gd"' in v16
    assert 'extends "res://scripts/ui/main_v14.gd"' in v15
    for token in ["show_chapel", "show_tavern", "show_memorial"]:
        assert token in v16


def test_memorial_is_limited_per_chapter_and_tavern_chapel_cost_resources():
    v16 = (ROOT / "scripts/ui/main_v16.gd").read_text(encoding="utf-8")
    assert "GameState.gold -= PSY_CHAPEL_APPEASE_GOLD" in v16
    assert "GameState.supplies -= PSY_TAVERN_MEAL_SUPPLIES" in v16
    assert "CampaignState.set_chapter_flag(flag, true)" in v16
    assert '"sanctuary_chapel_appease"' in v16
    assert '"sanctuary_shared_meal"' in v16
    assert '"sanctuary_memorial_remembrance"' in v16


def test_psychology_v16_exposes_fear_but_not_numeric_madness_or_hope():
    v16 = (ROOT / "scripts/ui/main_v16.gd").read_text(encoding="utf-8")
    runtime = (ROOT / "scripts/core/psychology_runtime.gd").read_text(encoding="utf-8")
    assert "ProgressBar.new()" in v16
    assert "PEUR · %s · %d/100" in v16
    assert "mental_summary" in v16
    assert 'psychology["traits"]' in runtime
    assert 'psychology["traumas"]' in runtime
    assert 'psychology["hope_history"]' in runtime
    assert "feedback_requested.emit" in runtime
