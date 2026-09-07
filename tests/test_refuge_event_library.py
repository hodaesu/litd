import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V06 = ROOT / "data" / "veilleurs" / "v06"

EVENT_FILES = [
    "refuge_events_social_v1.json",
    "refuge_events_knowledge_v1.json",
    "refuge_events_state_v1.json",
]


def load(name):
    return json.loads((V06 / name).read_text(encoding="utf-8"))


def all_events():
    events = []
    for name in EVENT_FILES:
        events.extend(load(name)["events"])
    return events


def test_refuge_catalog_is_authoritative_and_has_49_unique_events():
    events = all_events()
    ids = [event["id"] for event in events]
    catalog = load("refuge_event_catalog_v2.json")
    catalog_ids = [row[0] for row in catalog["events"]]
    assert len(events) == 49
    assert len(set(ids)) == 49
    assert catalog["total_active_events"] == 49
    assert set(catalog_ids) == set(ids)


def test_source_metadata_discrepancy_is_explicitly_corrected_not_hidden():
    social = load("refuge_events_social_v1.json")
    catalog = load("refuge_event_catalog_v2.json")
    override = catalog["source_metadata_override"]["refuge_events_social_v1.json"]
    assert len(social["events"]) == override["actual_event_count"] == 27
    counts = {}
    for event in social["events"]:
        counts[event["family"]] = counts.get(event["family"], 0) + 1
    assert counts == override["actual_families"] == {"conflict": 7, "rapprochement": 7, "grief": 6, "mutilation": 7}


def test_all_relationship_threshold_events_are_real_events():
    relationships = load("refuge_relationships_v1.json")
    event_ids = {event["id"] for event in all_events()}
    threshold_ids = {row["id"] for row in relationships["threshold_events"]}
    assert threshold_ids <= event_ids


def test_debate_library_has_three_events_per_pillar():
    knowledge = load("refuge_events_knowledge_v1.json")
    debates = [e for e in knowledge["events"] if e["family"] == "debate"]
    counts = {pillar: 0 for pillar in ("BODY", "MIND", "POLITICS")}
    for event in debates:
        counts[event["pillar"]] += 1
    assert len(debates) == 9
    assert counts == knowledge["debate_pillars"] == {"BODY": 3, "MIND": 3, "POLITICS": 3}


def test_memoriel_and_nemesis_counts_are_locked():
    knowledge = load("refuge_events_knowledge_v1.json")
    families = [event["family"] for event in knowledge["events"]]
    assert families.count("memoriel") == 4
    assert families.count("nemesis") == 4


def test_all_five_refuge_visual_states_have_one_transition_event():
    state = load("refuge_events_state_v1.json")
    expected = ["SURVIVRE", "ORGANISER", "COMPRENDRE", "REBATIR", "TRANSMETTRE"]
    assert state["visual_states"] == expected
    assert [event["refuge_state"] for event in state["events"]] == expected
    assert all(len(event["visible_consequences"]) >= 5 for event in state["events"])


def test_every_choice_resolves_to_declared_outcome_and_has_french_microtext():
    outcomes = load("refuge_event_outcome_library_v1.json")
    valid = set(outcomes["outcomes"])
    for event in all_events():
        assert event["intro_fr"].strip()
        assert len(event["dialogue_fr"]) >= 2
        assert all(line.strip() for line in event["dialogue_fr"])
        assert len(event["choices"]) >= 3
        for choice_id, label_fr, outcome_code, microtext_fr in event["choices"]:
            assert choice_id.strip()
            assert label_fr.strip()
            assert outcome_code in valid
            assert microtext_fr.strip()


def test_event_outcome_safety_invariants():
    outcomes = load("refuge_event_outcome_library_v1.json")
    rules = outcomes["rules"]
    assert rules["no_random_character_deletion"] is True
    assert rules["death_only_from_preexisting_death_record_or_explicit_critical_story_event"] is True
    assert rules["irreversible_choices_require_confirmation"] is True
    assert rules["saved_event_outcome_overrides_future_random_variant"] is True
    assert rules["knowledge_never_converts_to_gold"] is True


def test_grief_and_mutilation_never_restore_erased_history():
    social = load("refuge_events_social_v1.json")
    relevant = [e for e in social["events"] if e["family"] in {"grief", "mutilation"}]
    joined = json.dumps(relevant, ensure_ascii=False).lower()
    forbidden = ["resurrect", "revive", "erase injury history", "remove mutilation"]
    assert not any(term in joined for term in forbidden)


def test_state_events_match_refuge_recovery_visual_states():
    recovery = load("refuge_recovery_economy_v1.json")
    state = load("refuge_events_state_v1.json")
    assert state["visual_states"] == recovery["refuge"]["visual_states"]
