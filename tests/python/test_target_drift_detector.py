from tools.quality.target_drift_detector import (
    EQUIVALENT,
    MIXED,
    MORE_PERMISSIVE,
    STRICTER,
    classify_target_change,
    evaluate_revision_proposal,
)


def test_max_lower_is_stricter_and_higher_is_more_permissive():
    assert classify_target_change({"type": "max", "max": 10}, {"type": "max", "max": 8}) == STRICTER
    assert classify_target_change({"type": "max", "max": 10}, {"type": "max", "max": 12}) == MORE_PERMISSIVE


def test_min_higher_is_stricter_and_lower_is_more_permissive():
    assert classify_target_change({"type": "min", "min": 5}, {"type": "min", "min": 7}) == STRICTER
    assert classify_target_change({"type": "min", "min": 5}, {"type": "min", "min": 3}) == MORE_PERMISSIVE


def test_window_narrowing_is_stricter_and_widening_is_more_permissive():
    assert classify_target_change({"type": "window", "min": 4, "max": 10}, {"type": "window", "min": 5, "max": 9}) == STRICTER
    assert classify_target_change({"type": "window", "min": 4, "max": 10}, {"type": "window", "min": 3, "max": 11}) == MORE_PERMISSIVE


def test_window_tradeoff_is_mixed():
    assert classify_target_change({"type": "window", "min": 4, "max": 10}, {"type": "window", "min": 5, "max": 11}) == MIXED


def test_equivalent_target_is_equivalent():
    assert classify_target_change({"type": "max", "max": 10}, {"type": "max", "max": 10}) == EQUIVALENT


def test_permissive_change_blocks_without_strong_justification_and_two_evidence_refs():
    payload = {
        "target_ids": ["combat.boss_rounds"],
        "old_values": {"combat.boss_rounds": {"type": "window", "min": 5.5, "max": 10.5}},
        "new_values": {"combat.boss_rounds": {"type": "window", "min": 5.5, "max": 12.0}},
        "permissiveness_justification": "too short",
        "permissiveness_evidence_refs": ["one"],
    }
    result = evaluate_revision_proposal(payload)
    assert result["status"] == "BLOCK"
    assert "target_standard_becomes_more_permissive" in result["reasons"]
    assert result["core_write_allowed"] is False


def test_permissive_change_can_be_reviewed_when_explicitly_justified_but_not_auto_applied():
    payload = {
        "target_ids": ["combat.boss_rounds"],
        "old_values": {"combat.boss_rounds": {"type": "window", "min": 5.5, "max": 10.5}},
        "new_values": {"combat.boss_rounds": {"type": "window", "min": 5.5, "max": 12.0}},
        "permissiveness_justification": "Independent playtest evidence shows that the intended multi-phase boss cadence now requires a wider upper bound while preserving challenge, readability and retreat decisions.",
        "permissiveness_evidence_refs": ["playtest:2026-09-a", "telemetry:run-123"],
    }
    result = evaluate_revision_proposal(payload)
    assert result["status"] == "PASS"
    assert result["requires_explicit_justification"] is True
    assert result["core_write_allowed"] is False
