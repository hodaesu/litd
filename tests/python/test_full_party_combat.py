from pathlib import Path

from tools.qa.combat_turn_audit import run

ROOT = Path(__file__).resolve().parents[2]


def test_full_party_combat_audit_has_no_errors():
    report = run(ROOT)
    failed = [f"{item['name']}: {item['detail']}" for item in report["checks"] if not item["ok"]]
    assert not failed, failed


def test_all_hero_skill_stats_are_consumed():
    report = run(ROOT)
    assert report["missing_stats"] == []
    assert "damage_percent" in report["consumed_stats"]
    assert "execute_percent" in report["consumed_stats"]
    assert "max_hp" in report["consumed_stats"]
    assert "party_heal" in report["consumed_stats"]
    assert "madness_resistance" in report["consumed_stats"]
    assert "max_madness" in report["consumed_stats"]


def test_main_scene_routes_through_v15_to_v2_chain():
    scene = (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")
    assert 'res://scripts/ui/main_v15.gd' in scene
    sources = {}
    for version in range(2, 16):
        sources[version] = (ROOT / f"scripts/ui/main_v{version}.gd").read_text(encoding="utf-8")
    for child in range(15, 3, -1):
        assert f'extends "res://scripts/ui/main_v{child - 1}.gd"' in sources[child]
    assert 'extends "res://scripts/ui/main_v2.gd"' in sources[3]
    combat = sources[2]
    assert "func _active_round_hero()" in combat
    assert "func _finish_party_round()" in combat
    for source in sources.values():
        assert "alive_heroes()[0]" not in source
