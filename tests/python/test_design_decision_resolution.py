from __future__ import annotations

import pytest

from tools.quality.design_decision_resolution import validate_resolution


def _base(**overrides):
    payload = {
        "candidate_hash": "abc123",
        "decision": "REQUEST_IMPLEMENTATION_FIX",
        "rationale": "Le changement dégrade une cible canonique critique.",
        "decided_by": "reviewer@example",
        "decided_at": "2026-09-11T09:15:00+02:00",
        "evidence_refs": ["artifact:design-regression-gate"],
    }
    payload.update(overrides)
    return payload


def test_valid_resolution_is_hashed_and_cannot_write_core():
    receipt = validate_resolution(_base())
    assert receipt["kind"] == "LITD_DESIGN_DECISION_RESOLUTION"
    assert receipt["decision"] == "REQUEST_IMPLEMENTATION_FIX"
    assert receipt["core_write_allowed"] is False
    assert receipt["requires_new_change_and_tests"] is True
    assert len(receipt["resolution_hash"]) == 64


def test_reject_change_does_not_require_new_change():
    receipt = validate_resolution(_base(decision="REJECT_CHANGE"))
    assert receipt["requires_new_change_and_tests"] is False


def test_more_evidence_does_not_authorize_core_change():
    receipt = validate_resolution(_base(decision="REQUEST_MORE_EVIDENCE"))
    assert receipt["core_write_allowed"] is False
    assert receipt["requires_new_change_and_tests"] is False


def test_target_revision_still_requires_new_change_and_tests():
    receipt = validate_resolution(_base(decision="PROPOSE_TARGET_REVISION"))
    assert receipt["requires_new_change_and_tests"] is True
    assert receipt["core_write_allowed"] is False


def test_direct_core_write_is_rejected():
    with pytest.raises(ValueError, match="direct_core_write_forbidden"):
        validate_resolution(_base(core_write_allowed=True))


def test_unknown_decision_is_rejected():
    with pytest.raises(ValueError, match="unsupported_decision"):
        validate_resolution(_base(decision="APPLY_CORE_CHANGE"))


def test_naive_timestamp_is_rejected():
    with pytest.raises(ValueError, match="decided_at_requires_timezone"):
        validate_resolution(_base(decided_at="2026-09-11T09:15:00"))


def test_short_rationale_is_rejected():
    with pytest.raises(ValueError, match="rationale_too_short"):
        validate_resolution(_base(rationale="non"))
