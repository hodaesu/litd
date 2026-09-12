import pytest

from tools.quality.bounded_implementation_contract import _hash, evaluate


def gate():
    payload = {
        "kind": "LITD_GUARDIAN_CHANGE_GATE_RECEIPT",
        "project_id": "LITD",
        "target_route": "LITD_LIBRARY",
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


def evidence(source=None):
    source = source or gate()
    return {
        "gate_receipt_hash": source["gate_receipt_hash"],
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
    source = gate()
    result = evaluate(source, evidence(source))
    assert result["project_id"] == "LITD"
    assert result["target_route"] == "LITD_LIBRARY"
    assert result["status"] == "READY_FOR_APPLICATION_REVIEW"
    assert result["blockers"] == []
    assert result["automatic_application_allowed"] is False
    assert result["core_write_allowed"] is False


def test_cross_project_gate_with_valid_hash_fails_closed():
    source = gate()
    source["project_id"] = "COMPANY"
    source["target_route"] = "COMPANY_LIBRARY"
    source["gate_receipt_hash"] = _hash({k: v for k, v in source.items() if k != "gate_receipt_hash"})
    with pytest.raises(ValueError, match="project scope mismatch"):
        evaluate(source, evidence(source))


def test_wrong_target_route_with_valid_hash_fails_closed():
    source = gate()
    source["target_route"] = "GENERAL_LIBRARY"
    source["gate_receipt_hash"] = _hash({k: v for k, v in source.items() if k != "gate_receipt_hash"})
    with pytest.raises(ValueError, match="route scope mismatch"):
        evaluate(source, evidence(source))


def test_changed_path_outside_guardian_scope_blocks():
    source = gate(); row = evidence(source); row["changed_paths"].append("docs/knowledge/design-targets.json")
    result = evaluate(source, row)
    assert result["status"] == "IMPLEMENTATION_BLOCKED"
    assert "unexpected_changed_paths" in result["blockers"]


def test_missing_required_test_blocks():
    source = gate(); row = evidence(source); row["test_results"] = []
    result = evaluate(source, row)
    assert "missing_required_tests" in result["blockers"]


def test_failed_required_test_blocks():
    source = gate(); row = evidence(source); row["test_results"][0]["status"] = "FAIL"
    result = evaluate(source, row)
    assert "failed_required_tests" in result["blockers"]


def test_non_comparable_measurements_block():
    source = gate(); row = evidence(source); row["post_measurement"]["seed_value"] = 1
    result = evaluate(source, row)
    assert "measurements_not_comparable" in result["blockers"]


def test_rollback_evidence_is_mandatory():
    source = gate(); row = evidence(source); row["rollback_evidence_refs"] = []
    with pytest.raises(ValueError, match="rollback evidence"):
        evaluate(source, row)


def test_gate_authority_escalation_fails_closed():
    source = gate(); source["automatic_merge_allowed"] = True
    source["gate_receipt_hash"] = _hash({k: v for k, v in source.items() if k != "gate_receipt_hash"})
    with pytest.raises(ValueError, match="authority violation"):
        evaluate(source, evidence(source))


def test_tampered_gate_with_stale_hash_fails_closed():
    source = gate(); row = evidence(source)
    source["project_id"] = "COMPANY"
    with pytest.raises(ValueError, match="integrity mismatch"):
        evaluate(source, row)


def test_incomplete_measurement_identity_blocks():
    source = gate(); row = evidence(source)
    del row["pre_measurement"]["seed_value"]
    del row["post_measurement"]["seed_value"]
    result = evaluate(source, row)
    assert "measurements_not_comparable" in result["blockers"]


def test_duplicate_test_command_fails_closed():
    source = gate(); row = evidence(source)
    row["test_results"].append({"command": row["test_results"][0]["command"], "status": "FAIL"})
    with pytest.raises(ValueError, match="duplicate commands"):
        evaluate(source, row)


def test_invalid_measurement_hash_fails_closed():
    source = gate(); row = evidence(source)
    row["pre_measurement"]["artifact_hash"] = "G" * 64
    with pytest.raises(ValueError, match="lowercase hex"):
        evaluate(source, row)
