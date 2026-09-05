from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "scripts" / "core" / "les_veilleurs_narrative_catalog.gd"


def source():
    return SCRIPT_PATH.read_text(encoding="utf-8")


def test_catalog_loads_early_late_and_quartet_files():
    text = source()
    assert 'res://data/canon/les_veilleurs_acts_1_2.json' in text
    assert 'res://data/canon/les_veilleurs_acts_3_5.json' in text
    assert 'res://data/canon/les_veilleurs_quartet.json' in text


def test_catalog_exposes_complete_narrative_and_quartet_api():
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
        "static func quartet_catalog(",
        "static func quartet(",
        "static func character(",
        "static func party_contract(",
        "static func finale(",
        "static func canon_guardrails(",
        "static func runtime_pending(",
    ]:
        assert signature in text


def test_catalog_merges_hub_guardrails_and_runtime_pending_across_sources():
    text = source()
    assert 'early_catalog().get("hub_progression", [])' in text
    assert 'late_catalog().get("hub_progression_continuation", [])' in text
    assert '_append_unique_strings(result, late_catalog().get("canon_guardrails", []))' in text
    assert '_append_unique_strings(result, quartet_catalog().get("rules", []))' in text
    assert 'for source: Dictionary in [early_catalog(), late_catalog(), quartet_catalog()]' in text
    assert 'result.sort_custom' in text


def test_character_lookup_accepts_id_or_name_without_mutating_source():
    text = source()
    assert 'value.get("id", "")' in text
    assert 'value.get("name", "")' in text
    assert 'return value.duplicate(true)' in text
