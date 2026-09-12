import pytest

from tools.quality.guardian_change_gate import _hash, evaluate


def receipt():
    payload = {
        "kind": "LITD_VEILLEUR_REVIEW_RESOLUTION_RECEIPT",
        "project_id": "LITD",
        "target_route": "LITD_LIBRARY",
        "candidate_hash": "a" * 64,
        "evidence_id": "veilleur:test:1",
        "route": "LITD_LIBRARY",
        "outcome": "LITD_CHANGE_CANDIDATE_APPROVED_PENDING_GUARDIAN",
        "requires_guardian_review": True,
        "library_write_allowed": False,
        "core_write_allowed": False,
        "automatic_target_change_allowed": False,
    }
    payload["receipt_hash"] = _hash(payload)
    return payload


def submission(decision="ACCEPT_FOR_IMPLEMENTATION", source=None):
    source = source or receipt()
    return {
        "receipt_hash": source["receipt_hash"],
        "decision": decision,
        "decided_by": "governed-reviewer",
        "decided_at": "2026-09-12T07:00:00Z",
        "rationale": "The evidence is sufficient to justify a bounded implementation experiment.",
        "change_summary": "Adjust the relevant LITD implementation through a narrowly scoped code change.",
        "player_value": "The change is expected to improve clarity or player-facing reliability without changing canon silently.",
        "technical_value": "The bounded implementation provides a testable path with explicit CI evidence and rollback.",
        "risk": "The implementation could regress behavior outside the intended scope and therefore requires strict tests.",
        "reversibility": "The implementation is isolated to a dedicated PR and can be reverted by reverting that PR.",
        "affected_paths": ["scripts/core/example.gd"],
        "required_tests": ["python -m pytest -q tests/python/test_example.py", "godot --headless --path . --import --quit"],
        "rollback_plan": "Revert the implementation PR and rerun the exact required tests and measurement pipeline.",
        "evidence_refs": ["receipt:b" + "b" * 63],
    }


def test_acceptance_only_creates_bounded_plan():
    source = receipt()
    result = evaluate(source, submission(source=source))
    assert result["project_id"] == "LITD"
    assert result["target_route"] == "LITD_LIBRARY"
    assert result["status"] == "READY_FOR_BOUNDED_IMPLEMENTATION_PR"
    assert result["implementation_pr_allowed"] is True
    assert result["core_write_allowed"] is False
    assert result["automatic_code_write_allowed"] is False
    assert result["automatic_merge_allowed"] is False
    assert result["tests_must_pass_before_application"] is True


def test_rejection_has_no_implementation_plan():
    source = receipt()
    result = evaluate(source, submission("REJECT_CHANGE", source))
    assert result["status"] == "CHANGE_REJECTED"
    assert result["implementation_plan"] is None
    assert result["implementation_pr_allowed"] is False


def test_more_evidence_has_no_implementation_authority():
    source = receipt()
    result = evaluate(source, submission("REQUEST_MORE_EVIDENCE", source))
    assert result["status"] == "MORE_EVIDENCE_REQUIRED"
    assert result["implementation_pr_allowed"] is False


def test_cross_project_receipt_with_valid_hash_fails_closed():
    source = receipt()
    source["project_id"] = "COMPANY"
    source["target_route"] = "COMPANY_LIBRARY"
    source["receipt_hash"] = _hash({k: v for k, v in source.items() if k != "receipt_hash"})
    with pytest.raises(ValueError, match="project scope mismatch"):
        evaluate(source, submission(source=source))


def test_wrong_target_route_with_valid_hash_fails_closed():
    source = receipt()
    source["target_route"] = "GENERAL_LIBRARY"
    source["receipt_hash"] = _hash({k: v for k, v in source.items() if k != "receipt_hash"})
    with pytest.raises(ValueError, match="route scope mismatch"):
        evaluate(source, submission(source=source))


def test_receipt_hash_mismatch_fails_closed():
    source = receipt()
    data = submission(source=source)
    data["receipt_hash"] = "c" * 64
    with pytest.raises(ValueError, match="hash mismatch"):
        evaluate(source, data)


def test_non_guardian_pending_receipt_rejected():
    source = receipt()
    source["outcome"] = "LIBRARY_PROMOTION_APPROVED_PENDING_APPLICATION"
    source["receipt_hash"] = _hash({k: v for k, v in source.items() if k != "receipt_hash"})
    with pytest.raises(ValueError, match="not a Guardian-pending"):
        evaluate(source, submission(source=source))


def test_target_policy_path_is_forbidden():
    source = receipt()
    data = submission(source=source)
    data["affected_paths"] = ["docs/knowledge/design-targets.json"]
    with pytest.raises(ValueError, match="dedicated governance"):
        evaluate(source, data)


def test_tests_are_mandatory():
    source = receipt()
    data = submission(source=source)
    data["required_tests"] = []
    with pytest.raises(ValueError, match="required_tests"):
        evaluate(source, data)


def test_direct_core_authority_in_receipt_is_rejected():
    source = receipt()
    source["core_write_allowed"] = True
    source["receipt_hash"] = _hash({k: v for k, v in source.items() if k != "receipt_hash"})
    with pytest.raises(ValueError, match="authority violation"):
        evaluate(source, submission(source=source))


@pytest.mark.parametrize("path", ["../scripts/core/example.gd", "/scripts/core/example.gd", "./scripts/core/example.gd", "scripts\\core\\example.gd", ".git/config"])
def test_non_canonical_or_sensitive_paths_fail_closed(path):
    source = receipt()
    data = submission(source=source)
    data["affected_paths"] = [path]
    with pytest.raises(ValueError, match="non-canonical"):
        evaluate(source, data)


def test_tampered_resolution_receipt_with_stale_hash_fails_closed():
    source = receipt()
    data = submission(source=source)
    source["project_id"] = "COMPANY"
    with pytest.raises(ValueError, match="integrity mismatch"):
        evaluate(source, data)
