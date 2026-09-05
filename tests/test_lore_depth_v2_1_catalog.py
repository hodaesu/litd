from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "core" / "lore_depth_v2_1_catalog.gd"


def source() -> str:
    return SCRIPT.read_text(encoding="utf-8")


def test_catalog_loads_all_v2_1_sources():
    text = source()
    for path in [
        "res://universe/lore/city_district_history_v2.json",
        "res://universe/lore/late_foreign_microhistory_v2.json",
        "res://universe/lore/regional_daily_life_v2_1.json",
        "res://universe/lore/encyclopedia_depth_v2_1_manifest.json",
    ]:
        assert path in text


def test_catalog_exposes_runtime_queries():
    text = source()
    for signature in [
        "static func city_districts(",
        "static func district(",
        "static func late_polity(",
        "static func late_foreign_city(",
        "static func satellite_settlement(",
        "static func trade(",
        "static func everyday_object(",
        "static func quest_bridge(",
        "static func continuity_guardrails(",
        "static func intentionally_open(",
    ]:
        assert signature in text


def test_catalog_returns_deep_copies_for_records():
    text = source()
    assert "return item.duplicate(true)" in text
    assert "return city.duplicate(true)" in text
