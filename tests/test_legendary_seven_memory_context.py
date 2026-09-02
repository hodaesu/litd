from __future__ import annotations

import json
from pathlib import Path

from tools.qa.legendary_seven_memory_context_audit import audit_legendary_seven_memory_context

ROOT = Path(__file__).resolve().parents[1]
CONTEXTS = ROOT / "data/narrative/legendary_seven_relationship_memory_contexts.json"
AFTERLIVES = ROOT / "data/narrative/systemic_cross_afterlives.json"


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def test_memory_context_audit_is_green() -> None:
    report = audit_legendary_seven_memory_context(ROOT)
    assert report["ok"], report["errors"]


def test_every_systemic_relationship_topic_has_context_for_all_seven() -> None:
    contexts = _load(CONTEXTS)
    afterlives = _load(AFTERLIVES)
    expected = set()
    for section_name in ("family_profiles", "cascade_profiles"):
        for profile in afterlives[section_name].values():
            topic = profile.get("relationship_topic", "")
            if topic:
                expected.add(topic)
    assert set(contexts["topics"]) == expected
    assert len(expected) == 11
    for profile in contexts["topics"].values():
        assert len(profile["voices"]) == 7
        assert all(text.strip() for text in profile["voices"].values())


def test_exact_memory_overrides_cover_high_impact_aurelien_mathilde_cases() -> None:
    contexts = _load(CONTEXTS)
    required = {
        "cross_food_local_security_and_grain_bridge",
        "cross_funeral_body_return_and_medical_corridor",
        "cross_epistemic_clinical_record_and_probable_identity",
        "cross_azravel_evidence_and_protected_registry",
        "cross_relationship_named_death_after_difficult_choice",
        "cascade_winter_refugee_pressure",
    }
    assert required.issubset(contexts["event_overrides"])
    for source_id in required:
        line = contexts["event_overrides"][source_id]["pair_lines"]["aurelien_mathilde"]
        assert line["speaker_id"] in {"hero.aurelien", "hero.mathilde"}
        assert line["text"].strip()
