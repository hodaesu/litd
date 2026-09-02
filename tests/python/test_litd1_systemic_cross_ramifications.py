from __future__ import annotations

import json
from pathlib import Path

from tools.qa.systemic_cross_ramifications_audit import audit_systemic_cross_ramifications


ROOT = Path(__file__).resolve().parents[2]
CROSS_PATH = ROOT / "universe/lore/contextual_quest_cross_ramifications.json"
QUESTS_PATH = ROOT / "universe/lore/theatrical_contextual_quests.json"
DOC_PATH = ROOT / "docs/LITD1_CROISEMENTS_SYSTEMIQUES_DES_9_QUETES_V1.md"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_systemic_cross_audit_passes() -> None:
    report = audit_systemic_cross_ramifications(ROOT)
    assert report["ok"], report
    assert report["summary"]["source_choices"] == 26
    assert report["summary"]["cross_events"] == 18
    assert report["summary"]["families"] == 7
    assert report["summary"]["cascades"] == 4


def test_every_source_choice_participates_in_at_least_one_crossing() -> None:
    quests = load(QUESTS_PATH)
    cross = load(CROSS_PATH)
    expected = {
        (quest["id"], choice["id"])
        for quest in quests["quests"]
        for choice in quest["choices"]
    }
    used = {
        tuple(pair)
        for event in cross["cross_events"]
        for pair in event.get("all_choices", [])
    }
    assert len(expected) == 26
    assert used == expected


def test_crossings_need_more_than_one_real_cause() -> None:
    data = load(CROSS_PATH)
    assert data["core_rules"]["cross_event_requires_multiple_causes"] is True
    for event in data["cross_events"]:
        cause_count = (
            len(event.get("all_choices", []))
            + len(event.get("external_triggers", []))
            + (1 if event.get("requires_prior_contextual_choice") is True else 0)
        )
        assert cause_count >= 2, event["id"]


def test_no_new_morality_reputation_or_relationship_score() -> None:
    data = load(CROSS_PATH)
    core = data["core_rules"]
    assert core["new_universal_meter"] is False
    assert core["global_morality_score"] is False
    assert core["relationship_effects_are_not_approval_scores"] is True
    encoded_events = json.dumps(data["cross_events"], ensure_ascii=False).lower()
    for forbidden in ["reputation_score", "alignment_score", "morality_score", "score_delta", "relationship_delta"]:
        assert forbidden not in encoded_events


def test_rumor_collisions_keep_sources_and_can_remain_unresolved() -> None:
    data = load(CROSS_PATH)
    assert data["core_rules"]["rumor_collision_preserves_sources"] is True
    assert data["core_rules"]["contradiction_can_remain_unresolved"] is True
    modes = {mode for event in data["cross_events"] for mode in event["rumor_modes"]}
    assert {"confirmed", "direct", "reported", "variable", "unreliable"} <= modes


def test_saen_precedent_does_not_make_all_nonhuman_consciousness_the_same() -> None:
    data = load(CROSS_PATH)
    ids = {event["id"]: event for event in data["cross_events"]}
    refusal = ids["cross.consent.refusal_precedent_meets_new_refusal"]
    uncertain = ids["cross.consent.reversible_protocol_meets_uncertain_response"]
    assert refusal["external_triggers"] == ["new_nonhuman_consciousness_clear_refusal"]
    assert uncertain["external_triggers"] == ["new_nonhuman_consciousness_uncertain_response"]
    doc = DOC_PATH.read_text(encoding="utf-8")
    assert "Mais la nouvelle conscience n'est pas Saen." in doc
    assert "L'absence de refus compréhensible n'est pas une preuve de consentement" in doc


def test_lysandra_and_zeje_create_method_not_absolute_truth() -> None:
    data = load(CROSS_PATH)
    ids = {event["id"]: event for event in data["cross_events"]}
    assert "cross.epistemic.clinical_record_and_probable_identity" in ids
    assert "cross.epistemic.layered_archive_and_unknown_identity" in ids
    doc = DOC_PATH.read_text(encoding="utf-8")
    assert "PROBABLE" in doc
    assert "INCONNU" in doc
    assert "archive de l'incertitude" in doc


def test_effrie_crossings_keep_dragon_cosmology_open() -> None:
    data = load(CROSS_PATH)
    effrie_events = [event for event in data["cross_events"] if event["id"].startswith("cross.dragon.")]
    assert len(effrie_events) == 3
    doc = DOC_PATH.read_text(encoding="utf-8")
    assert "Aucun Vharren, Pacte ancestral, ascendance draconique, langue draconique ou lien au Voile n'est confirmé" in doc


def test_named_death_affects_relationships_without_becoming_a_verdict() -> None:
    data = load(CROSS_PATH)
    event = next(e for e in data["cross_events"] if e["id"] == "cross.relationship.named_death_after_difficult_choice")
    assert event["external_triggers"] == ["contextual_named_death"]
    assert event["requires_prior_contextual_choice"] is True
    assert set(event["hero_followups"]) == {
        "hero.aurelien", "hero.effrie", "hero.lya", "hero.mathilde",
        "hero.marec", "hero.zeje", "hero.anouk",
    }
    assert data["core_rules"]["relationship_effects_are_not_approval_scores"] is True


def test_litd1_crossings_never_cause_past_games() -> None:
    data = load(CROSS_PATH)
    assert data["core_rules"]["past_games_can_be_caused_by_litd1"] is False
    doc = DOC_PATH.read_text(encoding="utf-8")
    assert "ne peut jamais causer rétroactivement" in doc
