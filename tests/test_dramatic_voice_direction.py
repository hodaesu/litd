from __future__ import annotations

from tools.voice.acting_take_review import review_template
from tools.voice.build_dramatic_voice_registry import build_registry
from tools.voice.build_voice_performance_plan import build_performance_plan


def test_every_directed_line_has_playable_dramatic_fields() -> None:
    registry = build_registry()
    assert registry["entry_count"] >= 45
    for entry in registry["entries"]:
        assert entry["objective"]
        assert entry["obstacle"]
        assert entry["action"]
        assert entry["subtext"]
        assert entry["listener"]
        assert entry["preceding_thought"]
        assert entry["listening_trigger"]
        assert entry["silence"]
        assert entry["breath"]
        assert entry["beats"]
        assert entry["contradiction"]
        assert entry["post_line_state"]
        assert entry["beats"][0]["start"] == 0.0
        assert entry["beats"][-1]["end"] == 1.0


def test_important_lines_have_multiple_controlled_interpretations() -> None:
    registry = build_registry()
    important = [entry for entry in registry["entries"] if entry["important"]]
    assert len(important) >= 12
    for entry in important:
        assert len(entry["variants"]) >= 2
        assert {variant["id"] for variant in entry["variants"]}.issuperset({"contained_truth", "exposed_fissure"})
        assert all(0.9 <= float(variant["speed_multiplier"]) <= 1.1 for variant in entry["variants"])


def test_fourth_wall_awareness_happens_inside_the_line() -> None:
    registry = build_registry()
    meta = [
        entry for entry in registry["entries"]
        if entry["fourth_wall"] and entry["meta_level"] in {"direct", "abyssal"}
    ]
    assert meta
    assert all(any(beat.get("awareness_shift") is True for beat in entry["beats"]) for entry in meta)
    by_id = {entry["line_id"]: entry for entry in registry["entries"]}
    assert by_id["fw_dar_direct_02"]["direction_origin"] == "explicit_override"
    assert by_id["fw_dar_abyss_02"]["power"]["end"] == "mutual_observation"


def test_performance_plan_keeps_backend_truth_and_acting_metadata() -> None:
    plan = build_performance_plan()
    assert plan["version"] == 3
    assert plan["dramatic_direction"]["enabled"] is True
    assert plan["dramatic_direction"]["no_claim_of_neural_retraining"] is True
    assert plan["entries"]
    for entry in plan["entries"]:
        assert entry["acting_direction"]["performance_rule"]
        if entry["acting_direction"]["important"]:
            assert len(entry["interpretation_variants"]) >= 2
            assert all(0.65 <= float(variant["suggested_melotts_speed"]) <= 1.25 for variant in entry["interpretation_variants"])


def test_acting_review_template_scores_truth_not_emotional_showiness() -> None:
    template = review_template("fw_dar_direct_02")
    criteria = template["rubric"]["criteria"]
    assert "playable_objective_clarity" in criteria
    assert "active_listening" in criteria
    assert "subtext_truth" in criteria
    assert "beat_transition_truth" in criteria
    assert len(template["variant_reviews"]) >= 2
    assert "plus vraie" in template["selection"]["reason"]
