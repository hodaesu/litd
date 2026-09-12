import pytest

from tools.quality.bounded_implementation_contract import _hash
from tools.quality.bounded_implementation_single_use_gate import (
    CONSUMER,
    evaluate_once,
    register_guardian_gate_receipt,
)
from tools.quality.receipt_consumption_registry import ReceiptConsumptionRegistry


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


def evidence(source):
    return {
        "gate_receipt_hash": source["gate_receipt_hash"],
        "changed_paths": ["scripts/core/example.gd", "tests/python/test_example.py"],
        "test_results": [{"command": "python -m pytest -q tests/python/test_example.py", "status": "PASS"}],
        "pre_measurement": {
            "metric_family": "litd_balance_telemetry",
            "model_version": 2,
            "scenario": "first_veil_crypts",
            "seed_policy": "fixed",
            "seed_value": 20260821,
            "artifact_hash": "c" * 64,
        },
        "post_measurement": {
            "metric_family": "litd_balance_telemetry",
            "model_version": 2,
            "scenario": "first_veil_crypts",
            "seed_policy": "fixed",
            "seed_value": 20260821,
            "artifact_hash": "d" * 64,
        },
        "rollback_evidence_refs": ["git-revert-plan:example"],
        "implementation_commit_sha": "e" * 40,
    }


def test_guardian_gate_is_consumed_once_and_bound_into_evaluation(tmp_path):
    source = gate()
    context = "1" * 64
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    try:
        register_guardian_gate_receipt(registry, source, context_hash=context)
        result = evaluate_once(
            source,
            evidence(source),
            registry,
            current_context_hash=context,
            actor="implementation-reviewer",
        )
        assert result["status"] == "READY_FOR_APPLICATION_REVIEW"
        assert result["single_use_consumption"]["consumer"] == CONSUMER
        assert result["single_use_consumption"]["status"] == "CONSUMED_ONCE"
        assert len(result["single_use_consumption"]["audit_entry_hash"]) == 64
        unsigned = {k: v for k, v in result.items() if k != "evaluation_hash"}
        assert result["evaluation_hash"] == _hash(unsigned)
        assert registry.consumption_count(source["gate_receipt_hash"]) == 1
        assert registry.verify_audit_chain() is True
    finally:
        registry.close()


def test_identical_replay_is_rejected(tmp_path):
    source = gate()
    context = "2" * 64
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    try:
        register_guardian_gate_receipt(registry, source, context_hash=context)
        evaluate_once(source, evidence(source), registry, current_context_hash=context, actor="first")
        with pytest.raises(ValueError, match="replay_detected"):
            evaluate_once(source, evidence(source), registry, current_context_hash=context, actor="second")
        assert registry.consumption_count(source["gate_receipt_hash"]) == 1
    finally:
        registry.close()


def test_stale_context_is_rejected(tmp_path):
    source = gate()
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    try:
        register_guardian_gate_receipt(registry, source, context_hash="3" * 64)
        with pytest.raises(ValueError, match="stale_context"):
            evaluate_once(source, evidence(source), registry, current_context_hash="4" * 64, actor="reviewer")
        assert registry.consumption_count(source["gate_receipt_hash"]) == 0
    finally:
        registry.close()


def test_invalid_implementation_does_not_consume_guardian_receipt(tmp_path):
    source = gate()
    context = "5" * 64
    row = evidence(source)
    row["test_results"][0]["status"] = "FAIL"
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    try:
        register_guardian_gate_receipt(registry, source, context_hash=context)
        result = evaluate_once(source, row, registry, current_context_hash=context, actor="reviewer")
        assert result["status"] == "IMPLEMENTATION_BLOCKED"
        assert "single_use_consumption" not in result
        assert registry.consumption_count(source["gate_receipt_hash"]) == 0
    finally:
        registry.close()


def test_wrong_scope_cannot_be_registered(tmp_path):
    source = gate()
    source["project_id"] = "COMPANY"
    source["target_route"] = "COMPANY_LIBRARY"
    source["gate_receipt_hash"] = _hash({k: v for k, v in source.items() if k != "gate_receipt_hash"})
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    try:
        with pytest.raises(ValueError, match="project scope mismatch"):
            register_guardian_gate_receipt(registry, source, context_hash="6" * 64)
    finally:
        registry.close()
