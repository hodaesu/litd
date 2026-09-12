from pathlib import Path

import pytest

from tools.quality.application_decision_gate import _hash as application_hash
from tools.quality.authority_transition_single_use import (
    evaluate_application_once,
    evaluate_bounded_once,
    evaluate_closure_once,
    register_application_decision_for_closure,
    register_guardian_gate,
    register_implementation_evaluation,
)
from tools.quality.bounded_implementation_contract import _hash as bounded_hash
from tools.quality.receipt_consumption_registry import ReceiptConsumptionRegistry

CONTEXT_HASH = "9" * 64


def gate() -> dict:
    payload = {
        "kind": "LITD_GUARDIAN_CHANGE_GATE_RECEIPT",
        "project_id": "LITD",
        "target_route": "LITD_LIBRARY",
        "source_resolution_receipt_hash": "a" * 64,
        "source_candidate_hash": "b" * 64,
        "status": "READY_FOR_BOUNDED_IMPLEMENTATION_PR",
        "implementation_pr_allowed": True,
        "implementation_plan": {
            "affected_paths": ["scripts/core/example.gd", "tests/python/test_example.py"],
            "required_tests": ["python -m pytest -q tests/python/test_example.py"],
        },
        "core_write_allowed": False,
        "automatic_code_write_allowed": False,
        "automatic_merge_allowed": False,
        "automatic_target_change_allowed": False,
    }
    payload["gate_receipt_hash"] = bounded_hash(payload)
    return payload


def implementation_evidence(source: dict) -> dict:
    return {
        "gate_receipt_hash": source["gate_receipt_hash"],
        "changed_paths": ["scripts/core/example.gd", "tests/python/test_example.py"],
        "test_results": [{"command": "python -m pytest -q tests/python/test_example.py", "status": "PASS"}],
        "pre_measurement": {
            "metric_family": "litd_balance_telemetry",
            "model_version": 2,
            "scenario": "first_veil_crypts",
            "seed_policy": "fixed",
            "seed_value": 42,
            "artifact_hash": "c" * 64,
        },
        "post_measurement": {
            "metric_family": "litd_balance_telemetry",
            "model_version": 2,
            "scenario": "first_veil_crypts",
            "seed_policy": "fixed",
            "seed_value": 42,
            "artifact_hash": "d" * 64,
        },
        "rollback_evidence_refs": ["rollback:test"],
        "implementation_commit_sha": "e" * 40,
    }


def evaluation() -> dict:
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
        "measurements_comparable": True,
        "application_requires_separate_decision": True,
        "rollback_verification_required_before_application": True,
        "core_write_allowed": False,
        "automatic_merge_allowed": False,
        "automatic_application_allowed": False,
        "automatic_target_change_allowed": False,
    }
    payload["evaluation_hash"] = application_hash(payload)
    return payload


def application_decision(source: dict) -> dict:
    return {
        "evaluation_hash": source["evaluation_hash"],
        "decision": "APPLY_CHANGE",
        "decided_by": "application-reviewer",
        "decided_at": "2026-09-12T16:00:00Z",
        "rationale": "The bounded implementation passed review and is authorized for one governed application decision.",
        "implementation_commit_sha": source["implementation_commit_sha"],
        "pre_measurement_hash": source["pre_measurement_hash"],
        "post_measurement_hash": source["post_measurement_hash"],
        "measurement_assessment": "NO_BLOCKING_REGRESSION",
        "rollback_verified": True,
        "evidence_refs": ["bounded-evaluation:test"],
    }


def closure_evidence(decision: dict) -> dict:
    return {
        "application_decision_hash": decision["application_decision_hash"],
        "repository": "hodaesu/litd",
        "merged_source_commit_sha": decision["implementation_commit_sha"],
        "merged_commit_sha": "f" * 40,
        "merge_evidence_refs": ["pr:999", "merge:f"],
        "post_merge_assessment": "NO_BLOCKING_REGRESSION",
        "measurement_provenance_run_id": 123,
        "measurement_source_commit_sha": "f" * 40,
        "measurement_artifact_hashes": ["1" * 64],
        "checkpoint_source_commit_sha": "f" * 40,
        "checkpoint_source_run_id": 123,
        "checkpoint_hash": "2" * 64,
        "checkpoint_project_id": "LITD",
        "checkpoint_target_route": "LITD_LIBRARY",
        "sigstore_bundle_hash": "3" * 64,
        "checkpoint_signature_verified": True,
        "checkpoint_transparency_log_verified": True,
        "checkpoint_workflow_identity": "https://github.com/hodaesu/litd/.github/workflows/provenance-checkpoint.yml@refs/heads/main",
        "checkpoint_oidc_issuer": "https://token.actions.githubusercontent.com",
        "checkpoint_evidence_refs": ["artifact:signed-checkpoint", "rekor:123"],
    }


def test_ready_bounded_evaluation_consumes_guardian_gate_once(tmp_path: Path):
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    source = gate()
    try:
        register_guardian_gate(registry, source, context_hash=CONTEXT_HASH)
        first = evaluate_bounded_once(
            source,
            implementation_evidence(source),
            registry,
            current_context_hash=CONTEXT_HASH,
            actor="implementation-evaluator",
        )
        assert first["status"] == "READY_FOR_APPLICATION_REVIEW"
        assert first["single_use_consumption"]["status"] == "CONSUMED_ONCE"
        assert registry.consumption_count(source["gate_receipt_hash"]) == 1
        with pytest.raises(ValueError, match="replay_detected"):
            evaluate_bounded_once(
                source,
                implementation_evidence(source),
                registry,
                current_context_hash=CONTEXT_HASH,
                actor="implementation-evaluator-2",
            )
    finally:
        registry.close()


def test_blocked_bounded_evaluation_does_not_burn_gate(tmp_path: Path):
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    source = gate()
    try:
        register_guardian_gate(registry, source, context_hash=CONTEXT_HASH)
        blocked = implementation_evidence(source)
        blocked["post_measurement"]["seed_value"] = 99
        result = evaluate_bounded_once(
            source, blocked, registry, current_context_hash=CONTEXT_HASH, actor="implementation-evaluator"
        )
        assert result["status"] == "IMPLEMENTATION_BLOCKED"
        assert "single_use_consumption" not in result
        assert registry.consumption_count(source["gate_receipt_hash"]) == 0
        fixed = evaluate_bounded_once(
            source,
            implementation_evidence(source),
            registry,
            current_context_hash=CONTEXT_HASH,
            actor="implementation-evaluator",
        )
        assert fixed["status"] == "READY_FOR_APPLICATION_REVIEW"
        assert registry.consumption_count(source["gate_receipt_hash"]) == 1
    finally:
        registry.close()


def test_application_decision_consumes_evaluation_once(tmp_path: Path):
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    source = evaluation()
    try:
        register_implementation_evaluation(registry, source, context_hash=CONTEXT_HASH)
        first = evaluate_application_once(
            source, application_decision(source), registry, current_context_hash=CONTEXT_HASH
        )
        assert first["outcome"] == "APPLICATION_AUTHORIZED_PENDING_SEPARATE_MERGE"
        assert first["single_use_consumption"]["status"] == "CONSUMED_ONCE"
        assert registry.consumption_count(source["evaluation_hash"]) == 1
        second = application_decision(source)
        second["decision"] = "REQUEST_MORE_EVIDENCE"
        second["measurement_assessment"] = "INCONCLUSIVE"
        with pytest.raises(ValueError, match="replay_detected"):
            evaluate_application_once(source, second, registry, current_context_hash=CONTEXT_HASH)
    finally:
        registry.close()


def test_stale_application_evaluation_is_not_consumed(tmp_path: Path):
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    source = evaluation()
    try:
        register_implementation_evaluation(registry, source, context_hash=CONTEXT_HASH)
        with pytest.raises(ValueError, match="stale_context"):
            evaluate_application_once(
                source, application_decision(source), registry, current_context_hash="8" * 64
            )
        assert registry.consumption_count(source["evaluation_hash"]) == 0
    finally:
        registry.close()


def test_successful_closure_consumes_decision_but_explicitly_does_not_prove_single_merge(tmp_path: Path):
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    source_evaluation = evaluation()
    try:
        register_implementation_evaluation(registry, source_evaluation, context_hash=CONTEXT_HASH)
        decision = evaluate_application_once(
            source_evaluation,
            application_decision(source_evaluation),
            registry,
            current_context_hash=CONTEXT_HASH,
        )
        register_application_decision_for_closure(registry, decision, context_hash=CONTEXT_HASH)
        result = evaluate_closure_once(
            decision,
            closure_evidence(decision),
            registry,
            current_context_hash=CONTEXT_HASH,
            actor="closure-reviewer",
        )
        assert result["status"] == "APPLIED_MEASURED_PROVENANCE_VERIFIED"
        assert result["single_use_consumption"]["status"] == "CONSUMED_ONCE"
        assert result["merge_execution_single_use_verified"] is False
        assert result["merge_execution_single_use_gap"] == "SEPARATE_MERGE_EXECUTION_CONSUMER_REQUIRED"
        with pytest.raises(ValueError, match="replay_detected"):
            evaluate_closure_once(
                decision,
                closure_evidence(decision),
                registry,
                current_context_hash=CONTEXT_HASH,
                actor="closure-reviewer-2",
            )
    finally:
        registry.close()


def test_blocked_closure_does_not_burn_application_decision(tmp_path: Path):
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    source_evaluation = evaluation()
    try:
        register_implementation_evaluation(registry, source_evaluation, context_hash=CONTEXT_HASH)
        decision = evaluate_application_once(
            source_evaluation,
            application_decision(source_evaluation),
            registry,
            current_context_hash=CONTEXT_HASH,
        )
        register_application_decision_for_closure(registry, decision, context_hash=CONTEXT_HASH)
        blocked_evidence = closure_evidence(decision)
        blocked_evidence["post_merge_assessment"] = "BLOCKING_REGRESSION"
        blocked = evaluate_closure_once(
            decision,
            blocked_evidence,
            registry,
            current_context_hash=CONTEXT_HASH,
            actor="closure-reviewer",
        )
        assert blocked["status"] == "POST_MERGE_CLOSURE_BLOCKED"
        assert "single_use_consumption" not in blocked
        assert registry.consumption_count(decision["application_decision_hash"]) == 0
        fixed = evaluate_closure_once(
            decision,
            closure_evidence(decision),
            registry,
            current_context_hash=CONTEXT_HASH,
            actor="closure-reviewer",
        )
        assert fixed["status"] == "APPLIED_MEASURED_PROVENANCE_VERIFIED"
        assert registry.consumption_count(decision["application_decision_hash"]) == 1
    finally:
        registry.close()
