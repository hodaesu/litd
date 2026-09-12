from pathlib import Path

import pytest

from tools.quality.application_decision_gate import _hash
from tools.quality.application_closure_single_use import (
    evaluate_closure_once,
    register_merge_execution_receipt,
)
from tools.quality.merge_execution_gate import (
    authorize_merge_once,
    register_application_decision,
    verify_merge_execution_receipt,
)
from tools.quality.receipt_consumption_registry import ReceiptConsumptionRegistry

CONTEXT_HASH = "9" * 64


def decision() -> dict:
    payload = {
        "kind": "LITD_APPLICATION_DECISION_RECEIPT",
        "project_id": "LITD",
        "target_route": "LITD_LIBRARY",
        "source_evaluation_hash": "a" * 64,
        "source_candidate_hash": "b" * 64,
        "implementation_commit_sha": "c" * 40,
        "outcome": "APPLICATION_AUTHORIZED_PENDING_SEPARATE_MERGE",
        "merge_authorized": True,
        "merge_must_be_separate_action": True,
        "post_merge_measurement_required": True,
        "provenance_checkpoint_required": True,
        "core_write_allowed": False,
        "automatic_merge_allowed": False,
        "automatic_application_allowed": False,
        "automatic_target_change_allowed": False,
    }
    payload["application_decision_hash"] = _hash(payload)
    return payload


def merge_request(source: dict) -> dict:
    return {
        "application_decision_hash": source["application_decision_hash"],
        "repository": "hodaesu/litd",
        "pull_request_number": 999,
        "observed_head_sha": source["implementation_commit_sha"],
        "observed_base_sha": "d" * 40,
        "github_mergeable": True,
        "all_required_checks_successful": True,
        "required_check_evidence_refs": ["check:ci:123", "check:guardian:456"],
        "approval_evidence_refs": ["approval:human:789"],
        "requested_by": "governed-merger",
        "requested_at": "2026-09-12T16:30:00Z",
    }


def closure_evidence(source: dict, merge_receipt: dict) -> dict:
    return {
        "application_decision_hash": source["application_decision_hash"],
        "merge_execution_hash": merge_receipt["merge_execution_hash"],
        "merged_pr_number": merge_receipt["pull_request_number"],
        "repository": "hodaesu/litd",
        "merged_source_commit_sha": source["implementation_commit_sha"],
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


def prepare_merge(registry: ReceiptConsumptionRegistry):
    source = decision()
    register_application_decision(registry, source, context_hash=CONTEXT_HASH)
    receipt = authorize_merge_once(
        source,
        merge_request(source),
        registry,
        current_context_hash=CONTEXT_HASH,
    )
    return source, receipt


def test_wrong_head_fails_before_consuming_application_decision(tmp_path: Path):
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    source = decision()
    try:
        register_application_decision(registry, source, context_hash=CONTEXT_HASH)
        request = merge_request(source)
        request["observed_head_sha"] = "e" * 40
        with pytest.raises(ValueError, match="not the authorized implementation SHA"):
            authorize_merge_once(source, request, registry, current_context_hash=CONTEXT_HASH)
        assert registry.consumption_count(source["application_decision_hash"]) == 0
    finally:
        registry.close()


def test_merge_authorization_consumes_application_decision_once(tmp_path: Path):
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    source = decision()
    try:
        register_application_decision(registry, source, context_hash=CONTEXT_HASH)
        first = authorize_merge_once(
            source, merge_request(source), registry, current_context_hash=CONTEXT_HASH
        )
        verify_merge_execution_receipt(first)
        assert first["status"] == "READY_FOR_SEPARATE_GITHUB_MERGE"
        assert first["single_use_consumption"]["status"] == "CONSUMED_ONCE"
        assert first["authorized_head_sha"] == source["implementation_commit_sha"]
        assert first["expected_head_sha_enforcement_required"] is True
        assert first["external_merge_enforcement_verified"] is False
        assert registry.consumption_count(source["application_decision_hash"]) == 1
        with pytest.raises(ValueError, match="replay_detected"):
            authorize_merge_once(
                source, merge_request(source), registry, current_context_hash=CONTEXT_HASH
            )
    finally:
        registry.close()


def test_stale_context_cannot_create_merge_authorization(tmp_path: Path):
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    source = decision()
    try:
        register_application_decision(registry, source, context_hash=CONTEXT_HASH)
        with pytest.raises(ValueError, match="stale_context"):
            authorize_merge_once(
                source, merge_request(source), registry, current_context_hash="8" * 64
            )
        assert registry.consumption_count(source["application_decision_hash"]) == 0
    finally:
        registry.close()


def test_successful_closure_consumes_merge_receipt_once(tmp_path: Path):
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    try:
        source, merge_receipt = prepare_merge(registry)
        register_merge_execution_receipt(registry, merge_receipt, context_hash=CONTEXT_HASH)
        result = evaluate_closure_once(
            source,
            merge_receipt,
            closure_evidence(source, merge_receipt),
            registry,
            current_context_hash=CONTEXT_HASH,
            actor="closure-reviewer",
        )
        assert result["status"] == "APPLIED_MEASURED_PROVENANCE_VERIFIED"
        assert result["source_merge_execution_hash"] == merge_receipt["merge_execution_hash"]
        assert result["merge_authorization_single_use_verified"] is True
        assert result["external_merge_enforcement_verified"] is False
        assert registry.consumption_count(merge_receipt["merge_execution_hash"]) == 1
        with pytest.raises(ValueError, match="replay_detected"):
            evaluate_closure_once(
                source,
                merge_receipt,
                closure_evidence(source, merge_receipt),
                registry,
                current_context_hash=CONTEXT_HASH,
                actor="closure-reviewer-2",
            )
    finally:
        registry.close()


def test_blocked_closure_does_not_burn_merge_receipt(tmp_path: Path):
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    try:
        source, merge_receipt = prepare_merge(registry)
        register_merge_execution_receipt(registry, merge_receipt, context_hash=CONTEXT_HASH)
        blocked_evidence = closure_evidence(source, merge_receipt)
        blocked_evidence["post_merge_assessment"] = "BLOCKING_REGRESSION"
        blocked = evaluate_closure_once(
            source,
            merge_receipt,
            blocked_evidence,
            registry,
            current_context_hash=CONTEXT_HASH,
            actor="closure-reviewer",
        )
        assert blocked["status"] == "POST_MERGE_CLOSURE_BLOCKED"
        assert registry.consumption_count(merge_receipt["merge_execution_hash"]) == 0
        fixed = evaluate_closure_once(
            source,
            merge_receipt,
            closure_evidence(source, merge_receipt),
            registry,
            current_context_hash=CONTEXT_HASH,
            actor="closure-reviewer",
        )
        assert fixed["status"] == "APPLIED_MEASURED_PROVENANCE_VERIFIED"
        assert registry.consumption_count(merge_receipt["merge_execution_hash"]) == 1
    finally:
        registry.close()


def test_tampered_merge_receipt_is_rejected_before_closure(tmp_path: Path):
    registry = ReceiptConsumptionRegistry(tmp_path / "registry.sqlite3")
    try:
        source, merge_receipt = prepare_merge(registry)
        merge_receipt["pull_request_number"] = 1000
        with pytest.raises(ValueError, match="integrity mismatch"):
            register_merge_execution_receipt(registry, merge_receipt, context_hash=CONTEXT_HASH)
    finally:
        registry.close()
