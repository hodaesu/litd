from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "scripts" / "core" / "les_veilleurs_narrative_catalog.gd"


def source():
    return SCRIPT_PATH.read_text(encoding="utf-8")


def test_catalog_loads_early_and_late_veilleurs_files():
    text = source()
    assert 'res://data/canon/les_veilleurs_acts_1_2.json' in text
    assert 'res://data/canon/les_veilleurs_acts_3_5.json' in text


def test_catalog_exposes_complete_narrative_api():
    text = source()
    for signature in [
        "static func act(",
        "static func all_acts(",
        "static func zone(",
        "static func transition(",
        "static func noncombat_encounter(",
        "static func recruit_event(",
        "static func remanence_bundle(",
        "static func hub_stages(",
        "static func hub_stage(",
        "static func finale(",
        "static func canon_guardrails(",
        "static func runtime_pending(",
    ]:
        assert signature in text


def test_catalog_merges_hub_and_runtime_pending_across_both_halves():
    text = source()
    assert 'early_catalog().get("hub_progression", [])' in text
    assert 'late_catalog().get("hub_progression_continuation", [])' in text
    assert 'for source: Dictionary in [early_catalog(), late_catalog()]' in text
    assert 'result.sort_custom' in text
