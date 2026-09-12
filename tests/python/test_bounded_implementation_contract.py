import pytest

from tools.quality.bounded_implementation_contract import _hash, evaluate


def gate():
    payload = {
        "kind": "LITD_GUARDIAN_CHANGE_GATE_RECEIPT",
        "status": "READY_FOR_BOUNDED_IMPLEMENTATION_PR",
        "implementation_pr_allowed": True,
        "source_candidate_hash": "b" * 64,
        "implementation_plan": {
            "affected_paths": ["scripts/core/example.gd", "tests/python/test_example.py"],
            "required_tests": ["python -m pytest -q tests/python/test_example.py"],
        },
        "core_write_allowed": False,
        "automatic_code_write_allowed": False,
        "automatic_merge_allowed": False,
        "automatic_target_change_allowed": False,
    }
    payload["gate_receipt_hash"] = _hash(payload)
    return payload


def evidence():
    return {
        "gate_receipt_hash": gate()["gate_receipt_hash"],
        "changed_paths": ["scripts/core/example.gd", "tests/python/test_example.py"],
        "test_results": [{"command": "python -m pytest -q tests/python/test_example.py", "status": "PASS"}],
        "pre_measurement": {
            "metric_family": "litd_balance_telemetry", "model_version": 2, "scenario": "first_veil_crypts",
            "seed_policy": "fixed", "seed_value": 20260821, "artifact_hash": "c" * 64,
        },
        "post_measurement": {
            "metric_family": "litd_balance_telemetry", "model_version": 2, "scenario": "first_veil_crypts",
            "seed_policy": "fixed", "seed_value": 20260821, "artifact_hash": "d" * 64,
        },
        "rollback_evidence_refs": ["git-revert-plan:example"],
        "implementation_commit_sha": "e" * 40,
    }


def test_valid_implementation_reaches_application_review_only():
    result = evaluate(gate(), evidence())
    assert result["status"] == "READY_FOR_APPLICATION_REVIEW"
    assert result["blockers"] == []
    assert result["automatic_application_allowed"] is False
    assert result["core_write_allowed"] is False


def test_changed_path_outside_guardian_scope_blocks():
    row = evidence(); row["changed_paths"].append("docs/knowledge/design-targets.json")
    result = evaluate(gate(), row)
    assert result["status"] == "IMPLEMENTATION_BLOCKED"
    assert "unexpected_changed_paths" in result["blockers"]


def test_missing_required_test_blocks():
    row = evidence(); row["test_results"] = []
    result = evaluate(gate(), row)
    assert "missing_required_tests" in result["blockers"]


def test_failed_required_test_blocks():
    row = evidence(); row["test_results"][0]["status"] = "FAIL"
    result = evaluate(gate(), row)
    assert "failed_required_tests" in result["blockers"]


def test_non_comparable_measurements_block():
    row = evidence(); row["post_measurement"]["seed_value"] = 1
    result = evaluate(gate(), row)
    assert "measurements_not_comparable" in result["blockers"]


def test_rollback_evidence_is_mandatory():
    row = evidence(); row["rollback_evidence_refs"] = []
    with pytest.raises(ValueError, match="rollback evidence"):
        evaluate(gate(), row)


def test_gate_authority_escalation_fails_closed():
    g = gate(); g["automatic_merge_allowed"] = True
    g["gate_receipt_hash"] = _hash({k: v for k, v in g.items() if k != "gate_receipt_hash"})
    with pytest.raises(ValueError, match="authority violation"):
        evaluate(g, evidence())


def test_tampered_gate_with_stale_hash_fails_closed():
    bad = gate()
    bad["implementation_plan"]["affected_paths"].append("scripts/core/hostile.gd")
    with pytest.raises(ValueError, match="integrity mismatch"):
        evaluate(bad, evidence())


def test_incomplete_measurement_identity_blocks():
    row = evidence()
    del row["pre_measurement"]["seed_value"]
    del row["post_measurement"]["seed_value"]
    result = evaluate(gate(), row)
    assert "measurements_not_comparable" in result["blockers"]


def test_duplicate_test_command_fails_closed():
    row = evidence()
    row["test_results"].append({"command": row["test_results"][0]["command"], "status": "FAIL"})
    with pytest.raises(ValueError, match="duplicate commands"):
        evaluate(gate(), row)


def test_invalid_measurement_hash_fails_closed():
    row = evidence()
    row["pre_measurement"]["artifact_hash"] = "G" * 64
    with pytest.raises(ValueError, match="lowercase hex"):
        evaluate(gate(), row)
