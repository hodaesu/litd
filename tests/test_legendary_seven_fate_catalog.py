from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "core" / "legendary_seven_fate_catalog.gd"


def source() -> str:
    return SCRIPT.read_text(encoding="utf-8")


def test_catalog_loads_fates_and_precedence_manifest():
    text = source()
    assert "res://universe/lore/legendary_seven_post_campaign_fates.json" in text
    assert "res://universe/lore/legendary_seven_post_campaign_manifest.json" in text


def test_catalog_exposes_fate_queries():
    text = source()
    for signature in [
        "static func shared_fate(",
        "static func hero_fate(",
        "static func formation_order(",
        "static func later_memory(",
        "static func still_open(",
        "static func precedence(",
    ]:
        assert signature in text


def test_catalog_returns_deep_copies():
    text = source()
    assert "return item.duplicate(true)" in text
    assert "return value.duplicate(true)" in text
