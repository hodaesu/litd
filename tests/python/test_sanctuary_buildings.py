from pathlib import Path

from tools.qa.sanctuary_buildings_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_sanctuary_buildings_audit_has_no_errors():
    report = run(ROOT)
    failed = [f"{item['name']}: {item['detail']}" for item in report["checks"] if not item["ok"]]
    assert not failed, failed


def test_sanctuary_v15_keeps_mobile_layer_and_three_real_screens():
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")
    v15 = (ROOT / "scripts/ui/main_v15.gd").read_text(encoding="utf-8")
    assert 'res://scripts/ui/main_v15.gd' in scene
    assert 'extends "res://scripts/ui/main_v14.gd"' in v15
    for token in ["show_chapel", "show_tavern", "show_memorial"]:
        assert token in v15


def test_memorial_is_limited_per_chapter_and_tavern_chapel_cost_resources():
    v15 = (ROOT / "scripts/ui/main_v15.gd").read_text(encoding="utf-8")
    assert "GameState.gold -= CHAPEL_APPEASE_GOLD" in v15
    assert "GameState.supplies -= TAVERN_MEAL_SUPPLIES" in v15
    assert 'return "memorial_honored_%s" % CampaignState.current_chapter_id' in v15
    assert "CampaignState.set_chapter_flag(flag, true)" in v15
