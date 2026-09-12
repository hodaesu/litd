import pytest

from tools.quality.application_decision_gate import _hash, evaluate


def implementation_evaluation():
    payload = {
        "kind": "LITD_BOUNDED_IMPLEMENTATION_EVALUATION",
        "project_id": "LITD",
        "target_route": "LITD_LIBRARY",
        "status": "READY_FOR_APPLICATION_REVIEW",
        "source_gate_receipt_hash": "a" * 64,
        "source_candidate_hash": "b" * 64,
        "implementation_commit_sha": "c" * 40,
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
    }
    payload["evaluation_hash"] = _hash(payload)
    return payload


def decision(choice="APPLY_CHANGE", source=None):
    source = source or implementation_evaluation()
    return {
        "evaluation_hash": source["evaluation_hash"],
        "decision": choice,
        "decided_by": "governed-reviewer",
        "decided_at": "2026-09-12T08:20:00Z",
        "rationale": "All bounded implementation evidence has been reviewed against the approved Guardian plan.",
        "implementation_commit_sha": source["implementation_commit_sha"],
        "pre_measurement_hash": source["pre_measurement_hash"],
        "post_measurement_hash": source["post_measurement_hash"],
        "measurement_assessment": "NO_BLOCKING_REGRESSION",
        "rollback_verified": True,
        "evidence_refs": ["bounded-evaluation:test"],
    }


def test_apply_change_only_authorizes_separate_merge():
    source = implementation_evaluation()
    result = evaluate(source, decision(source=source))
    assert result["project_id"] == "LITD"
    assert result["target_route"] == "LITD_LIBRARY"
    assert result["outcome"] == "APPLICATION_AUTHORIZED_PENDING_SEPARATE_MERGE"
    assert result["merge_authorized"] is True
    assert result["merge_must_be_separate_action"] is True
    assert result["automatic_merge_allowed"] is False
    assert result["automatic_application_allowed"] is False
    assert result["core_write_allowed"] is False


def test_cross_project_evaluation_with_valid_hash_fails_closed():
    source = implementation_evaluation()
    source["project_id"] = "COMPANY"
    source["target_route"] = "COMPANY_LIBRARY"
    source["evaluation_hash"] = _hash({k: v for k, v in source.items() if k != "evaluation_hash"})
    with pytest.raises(ValueError, match="project scope mismatch"):
        evaluate(source, decision(source=source))


def test_wrong_target_route_with_valid_hash_fails_closed():
    source = implementation_evaluation()
    source["target_route"] = "GENERAL_LIBRARY"
    source["evaluation_hash"] = _hash({k: v for k, v in source.items() if k != "evaluation_hash"})
    with pytest.raises(ValueError, match="route scope mismatch"):
        evaluate(source, decision(source=source))


def test_apply_requires_no_blocking_regression():
    source = implementation_evaluation(); row = decision(source=source); row["measurement_assessment"] = "BLOCKING_REGRESSION"
    with pytest.raises(ValueError, match="NO_BLOCKING_REGRESSION"):
        evaluate(source, row)


def test_apply_requires_verified_rollback():
    source = implementation_evaluation(); row = decision(source=source); row["rollback_verified"] = False
    with pytest.raises(ValueError, match="verified rollback"):
        evaluate(source, row)


def test_reject_can_record_blocking_regression():
    source = implementation_evaluation(); row = decision("REJECT_IMPLEMENTATION", source); row["measurement_assessment"] = "BLOCKING_REGRESSION"
    result = evaluate(source, row)
    assert result["outcome"] == "IMPLEMENTATION_REJECTED"
    assert result["merge_authorized"] is False


def test_request_more_evidence_can_record_inconclusive_measurement():
    source = implementation_evaluation(); row = decision("REQUEST_MORE_EVIDENCE", source); row["measurement_assessment"] = "INCONCLUSIVE"
    result = evaluate(source, row)
    assert result["outcome"] == "MORE_EVIDENCE_REQUIRED"


def test_mismatched_commit_fails_closed():
    source = implementation_evaluation(); row = decision(source=source); row["implementation_commit_sha"] = "0" * 40
    with pytest.raises(ValueError, match="commit SHA mismatch"):
        evaluate(source, row)


def test_mismatched_measurement_hash_fails_closed():
    source = implementation_evaluation(); row = decision(source=source); row["post_measurement_hash"] = "0" * 64
    with pytest.raises(ValueError, match="post measurement hash mismatch"):
        evaluate(source, row)


def test_upstream_authority_escalation_fails_closed():
    source = implementation_evaluation(); source["automatic_merge_allowed"] = True
    source["evaluation_hash"] = _hash({k: v for k, v in source.items() if k != "evaluation_hash"})
    with pytest.raises(ValueError, match="authority violation"):
        evaluate(source, decision(source=source))


def test_blocked_implementation_cannot_reach_application_decision():
    source = implementation_evaluation(); source["status"] = "IMPLEMENTATION_BLOCKED"
    source["evaluation_hash"] = _hash({k: v for k, v in source.items() if k != "evaluation_hash"})
    with pytest.raises(ValueError, match="not ready"):
        evaluate(source, decision(source=source))


def test_tampered_evaluation_with_stale_hash_fails_closed():
    source = implementation_evaluation(); row = decision(source=source)
    source["project_id"] = "COMPANY"
    with pytest.raises(ValueError, match="integrity mismatch"):
        evaluate(source, row)
