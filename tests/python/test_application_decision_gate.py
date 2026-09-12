import json
from hashlib import sha256

import pytest

from tools.quality.application_decision_gate import evaluate


def _hash(payload):
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def implementation_evaluation():
    row = {
        "kind": "LITD_BOUNDED_IMPLEMENTATION_EVALUATION",
        "status": "READY_FOR_APPLICATION_REVIEW",
        "source_gate_receipt_hash": "a" * 64,
        "source_candidate_hash": "b" * 64,
        "implementation_commit_sha": "c" * 40,
        "unexpected_changed_paths": [],
        "missing_required_tests": [],
        "failed_required_tests": [],
        "measurements_comparable": True,
        "pre_measurement_hash": "d" * 64,
        "post_measurement_hash": "e" * 64,
        "rollback_evidence_refs": ["rollback:test"],
        "blockers": [],
        "application_requires_separate_decision": True,
        "rollback_verification_required_before_application": True,
        "core_write_allowed": False,
        "automatic_merge_allowed": False,
        "automatic_application_allowed": False,
        "automatic_target_change_allowed": False,
        "authority": "implementation_evidence_only_separate_application_decision_required",
    }
    row["evaluation_hash"] = _hash(row)
    return row


def decision(choice="APPLY_CHANGE", evaluation=None):
    evaluation = evaluation or implementation_evaluation()
    return {
        "evaluation_hash": evaluation["evaluation_hash"],
        "decision": choice,
        "decided_by": "governed-reviewer",
        "decided_at": "2026-09-12T08:20:00Z",
        "rationale": "All bounded implementation evidence has been reviewed against the approved Guardian plan.",
        "implementation_commit_sha": evaluation["implementation_commit_sha"],
        "pre_measurement_hash": evaluation["pre_measurement_hash"],
        "post_measurement_hash": evaluation["post_measurement_hash"],
        "measurement_assessment": "NO_BLOCKING_REGRESSION",
        "rollback_verified": True,
        "evidence_refs": ["bounded-evaluation:test"],
    }


def test_apply_change_only_authorizes_separate_merge():
    evaluation = implementation_evaluation()
    result = evaluate(evaluation, decision(evaluation=evaluation))
    assert result["outcome"] == "APPLICATION_AUTHORIZED_PENDING_SEPARATE_MERGE"
    assert result["merge_authorized"] is True
    assert result["merge_must_be_separate_action"] is True
    assert result["automatic_merge_allowed"] is False
    assert result["automatic_application_allowed"] is False
    assert result["core_write_allowed"] is False


def test_apply_requires_no_blocking_regression():
    evaluation = implementation_evaluation()
    row = decision(evaluation=evaluation); row["measurement_assessment"] = "BLOCKING_REGRESSION"
    with pytest.raises(ValueError, match="NO_BLOCKING_REGRESSION"):
        evaluate(evaluation, row)


def test_apply_requires_verified_rollback():
    evaluation = implementation_evaluation()
    row = decision(evaluation=evaluation); row["rollback_verified"] = False
    with pytest.raises(ValueError, match="verified rollback"):
        evaluate(evaluation, row)


def test_reject_can_record_blocking_regression():
    evaluation = implementation_evaluation()
    row = decision("REJECT_IMPLEMENTATION", evaluation); row["measurement_assessment"] = "BLOCKING_REGRESSION"
    result = evaluate(evaluation, row)
    assert result["outcome"] == "IMPLEMENTATION_REJECTED"
    assert result["merge_authorized"] is False


def test_request_more_evidence_can_record_inconclusive_measurement():
    evaluation = implementation_evaluation()
    row = decision("REQUEST_MORE_EVIDENCE", evaluation); row["measurement_assessment"] = "INCONCLUSIVE"
    result = evaluate(evaluation, row)
    assert result["outcome"] == "MORE_EVIDENCE_REQUIRED"


def test_mismatched_commit_fails_closed():
    evaluation = implementation_evaluation()
    row = decision(evaluation=evaluation); row["implementation_commit_sha"] = "0" * 40
    with pytest.raises(ValueError, match="commit SHA mismatch"):
        evaluate(evaluation, row)


def test_mismatched_measurement_hash_fails_closed():
    evaluation = implementation_evaluation()
    row = decision(evaluation=evaluation); row["post_measurement_hash"] = "0" * 64
    with pytest.raises(ValueError, match="post measurement hash mismatch"):
        evaluate(evaluation, row)


def test_tampered_evaluation_with_stale_hash_fails_closed():
    evaluation = implementation_evaluation()
    row = decision(evaluation=evaluation)
    evaluation["post_measurement_hash"] = "0" * 64
    with pytest.raises(ValueError, match="integrity mismatch"):
        evaluate(evaluation, row)


def test_missing_measurement_comparability_fails_closed():
    evaluation = implementation_evaluation()
    evaluation["measurements_comparable"] = False
    evaluation["evaluation_hash"] = _hash({k: v for k, v in evaluation.items() if k != "evaluation_hash"})
    with pytest.raises(ValueError, match="comparable measurements"):
        evaluate(evaluation, decision(evaluation=evaluation))


def test_missing_rollback_evidence_fails_closed():
    evaluation = implementation_evaluation()
    evaluation["rollback_evidence_refs"] = []
    evaluation["evaluation_hash"] = _hash({k: v for k, v in evaluation.items() if k != "evaluation_hash"})
    with pytest.raises(ValueError, match="rollback evidence"):
        evaluate(evaluation, decision(evaluation=evaluation))


def test_upstream_authority_escalation_fails_closed():
    evaluation = implementation_evaluation()
    evaluation["automatic_merge_allowed"] = True
    evaluation["evaluation_hash"] = _hash({k: v for k, v in evaluation.items() if k != "evaluation_hash"})
    with pytest.raises(ValueError, match="authority violation"):
        evaluate(evaluation, decision(evaluation=evaluation))


def test_blocked_implementation_cannot_reach_application_decision():
    evaluation = implementation_evaluation()
    evaluation["status"] = "IMPLEMENTATION_BLOCKED"
    evaluation["evaluation_hash"] = _hash({k: v for k, v in evaluation.items() if k != "evaluation_hash"})
    with pytest.raises(ValueError, match="not ready"):
        evaluate(evaluation, decision(evaluation=evaluation))
