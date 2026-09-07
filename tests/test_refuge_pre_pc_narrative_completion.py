import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V06 = ROOT / "data" / "veilleurs" / "v06"
QUARTET = {"SAHEN_VARO", "MIRA_SEN", "NAREM_OSH", "YSRA_NAHAL"}


def load(name):
    return json.loads((V06 / name).read_text(encoding="utf-8"))


def catalog_ids():
    return {row[0] for row in load("refuge_event_catalog_v2.json")["events"]}


def test_alternate_voice_banks_cover_all_49_events_and_four_watchers_twice():
    social = load("refuge_voice_alternates_social_v1.json")
    knowledge = load("refuge_voice_alternates_knowledge_state_v1.json")
    assert social["event_count"] == 27
    assert knowledge["event_count"] == 22
    merged = {**social["events"], **knowledge["events"]}
    assert len(merged) == 49
    assert set(merged) == catalog_ids()
    line_count = 0
    for event_id, speakers in merged.items():
        assert set(speakers) == QUARTET, event_id
        for lines in speakers.values():
            assert len(lines) == 2
            assert all(line.strip() for line in lines)
            line_count += len(lines)
    assert line_count == 392


def test_alternates_do_not_reintroduce_legacy_quartet_names():
    text = json.dumps({
        "social": load("refuge_voice_alternates_social_v1.json"),
        "knowledge": load("refuge_voice_alternates_knowledge_state_v1.json"),
    }, ensure_ascii=False).lower()
    for legacy in ("nayra orun", "tarek senn", "aisha maren", "idris vael"):
        assert legacy not in text


def test_24_recruit_types_have_all_eight_contextual_micro_reactions():
    source = load("enemies_24_definitions.json")
    micro = load("recruit_micro_reactions_24_v1.json")
    expected_contexts = ["return", "idle", "trust_gain", "fear_spike", "grief", "care", "conflict", "departure"]
    assert micro["contexts"] == expected_contexts
    assert micro["count"] == len(micro["profiles"]) == source["count"] == 24
    source_ids = {e["entity_id"] for e in source["enemies"]}
    profile_ids = {p["entity_id"] for p in micro["profiles"]}
    assert source_ids == profile_ids
    for profile in micro["profiles"]:
        assert set(profile["reactions"]) == set(expected_contexts)
        for gesture, subtitle in profile["reactions"].values():
            assert gesture.strip()
            assert subtitle is None or subtitle.strip()


def test_micro_reactions_are_cosmetic_unless_event_outcome_changes_state():
    rules = load("recruit_micro_reactions_24_v1.json")["rules"]
    assert rules["never_interrupt_critical_choice"] is True
    assert rules["one_micro_reaction_per_entity_per_beat"] is True
    assert rules["reaction_is_cosmetic_unless_event_outcome_explicitly_changes_state"] is True


def test_final_vo_script_has_direction_for_every_catalog_scene():
    script = load("refuge_vo_script_final_v1.json")
    assert script["event_count"] == 49
    ids = [row[0] for row in script["events"]]
    assert len(ids) == len(set(ids)) == 49
    assert set(ids) == catalog_ids()
    profiles = set(script["direction_profiles"])
    for event_id, profile, intention, beats, interruption in script["events"]:
        assert profile in profiles, event_id
        assert intention.strip()
        assert beats
        assert interruption.strip()


def test_final_vo_script_locks_recording_and_mobile_subtitles():
    script = load("refuge_vo_script_final_v1.json")
    recording = script["recording_rules"]
    subtitles = script["subtitle_contract"]
    assert recording["record_alternates_as_separate_takes"] is True
    assert recording["no_improvised_lore_facts"] is True
    assert recording["pronunciation_sheet_required"] is True
    assert subtitles["max_lines"] == 2
    assert subtitles["hard_max_chars_per_line"] <= 48
    assert subtitles["source"] == "exact resolved spoken text"
    assert subtitles["nonlexical_sound_subtitle"] == "only when accessibility setting requests sound descriptions"


def test_pronunciation_sheet_contains_quartet_and_core_terms():
    sheet = load("refuge_pronunciation_sheet_v1.json")
    entries = {e["term"]: e for e in sheet["entries"]}
    for term in ("Sahen Varo", "Mira Sen", "Narem Osh", "Ysra Nahal", "Khar-Sen", "Rémanence", "Mémoriel", "Némésis"):
        assert term in entries
        assert entries[term]["ipa"].strip()
        assert entries[term]["actor_hint_fr"].strip()
    assert sheet["rules"]["pronunciation_changes_require_canonical_review"] is True


def test_localization_contract_preserves_litd_semantics():
    loc = load("refuge_localization_subtitle_contract_v1.json")
    rules = loc["rules"]
    assert rules["source_french_is_canonical_meaning"] is True
    assert rules["do_not_translate_relationship_axes_as_single_loyalty_score"] is True
    assert rules["do_not_translate_fear_as_loyalty"] is True
    assert rules["do_not_turn_hypothesis_into_fact"] is True
    assert rules["nonverbal_reactions_have_no_dialogue_subtitle"] is True
    glossary = {e["term_fr"] for e in loc["glossary"]}
    assert {"Rémanence", "Mémoriel", "Némésis", "Corps", "Esprit", "Politique", "Confiance", "Respect", "Peur", "Ressentiment"} <= glossary


def test_all_final_pre_pc_completion_requirements_have_real_files():
    script = load("refuge_vo_script_final_v1.json")
    required_files = [
        "refuge_event_catalog_v2.json",
        "refuge_veilleur_voice_contract_v1.json",
        "recruit_refuge_reactions_24_v1.json",
        "refuge_event_chains_v1.json",
        "refuge_event_staging_49_v1.json",
        "refuge_voice_alternates_social_v1.json",
        "refuge_voice_alternates_knowledge_state_v1.json",
        "recruit_micro_reactions_24_v1.json",
        "refuge_vo_script_final_v1.json",
        "refuge_pronunciation_sheet_v1.json",
        "refuge_localization_subtitle_contract_v1.json",
    ]
    assert all((V06 / path).exists() for path in required_files)
    assert len(script["pre_pc_complete_when"]) == 6
