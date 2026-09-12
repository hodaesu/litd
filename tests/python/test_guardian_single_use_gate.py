from pathlib import Path

import pytest

from tools.quality.guardian_change_gate import _hash
from tools.quality.guardian_single_use_gate import evaluate_once, register_resolution_receipt
from tools.quality.receipt_consumption_registry import ReceiptConsumptionRegistry

CONTEXT_HASH = "9" * 64


def receipt() -> dict:
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


def submission(source: dict, decision: str = "ACCEPT_FOR_IMPLEMENTATION") -> dict:
    return {
        "receipt_hash": source["receipt_hash"],
        "decision": decision,
        "decided_by": "governed-reviewer",
        "decided_at": "2026-09-12T12:30:00Z",
        "rationale": "The evidence is sufficient to justify exactly one governed Guardian decision.",
        "change_summary": "Apply one narrowly bounded implementation change under the approved LITD governance scope.",
        "player_value": "The bounded change is expected to improve reliability while preserving explicit governance controls.",
        "technical_value": "The implementation remains isolated, testable, measurable and reversible before application.",
        "risk": "A regression or stale decision could otherwise escape the intended scope and must therefore fail closed.",
        "reversibility": "The implementation remains isolated to a dedicated change and can be reverted with retained evidence.",
        "affected_paths": ["scripts/core/example.gd"],
        "required_tests": ["python -m pytest -q tests/python/test_example.py"],
        "rollback_plan": "Revert the bounded implementation commit and rerun the exact required tests and measurements.",
        "evidence_refs": ["receipt:evidence:1"],
    }


def prepare(tmp_path: Path):
    db = tmp_path / "single-use.sqlite3"
    registry = ReceiptConsumptionRegistry(db)
    source = receipt()
    register_resolution_receipt(registry, source, context_hash=CONTEXT_HASH)
    return registry, source


def test_guardian_acceptance_consumes_source_receipt_once(tmp_path: Path):
    registry, source = prepare(tmp_path)
    try:
        result = evaluate_once(source, submission(source), registry, current_context_hash=CONTEXT_HASH)
        assert result["status"] == "READY_FOR_BOUNDED_IMPLEMENTATION_PR"
        assert result["single_use_consumption"]["status"] == "CONSUMED_ONCE"
        assert result["single_use_consumption"]["source_receipt_hash"] == source["receipt_hash"]
        assert registry.consumption_count(source["receipt_hash"]) == 1
        assert registry.verify_audit_chain() is True
    finally:
        registry.close()


def test_second_guardian_decision_on_same_receipt_is_replay(tmp_path: Path):
    registry, source = prepare(tmp_path)
    try:
        evaluate_once(source, submission(source), registry, current_context_hash=CONTEXT_HASH)
        second = submission(source, "REQUEST_MORE_EVIDENCE")
        with pytest.raises(ValueError, match="replay_detected"):
            evaluate_once(source, second, registry, current_context_hash=CONTEXT_HASH)
        assert registry.consumption_count(source["receipt_hash"]) == 1
    finally:
        registry.close()


def test_invalid_guardian_submission_does_not_burn_receipt(tmp_path: Path):
    registry, source = prepare(tmp_path)
    try:
        bad = submission(source)
        bad["required_tests"] = []
        with pytest.raises(ValueError, match="required_tests"):
            evaluate_once(source, bad, registry, current_context_hash=CONTEXT_HASH)
        assert registry.consumption_count(source["receipt_hash"]) == 0
        valid = evaluate_once(source, submission(source), registry, current_context_hash=CONTEXT_HASH)
        assert valid["status"] == "READY_FOR_BOUNDED_IMPLEMENTATION_PR"
    finally:
        registry.close()


def test_stale_context_blocks_guardian_without_consuming(tmp_path: Path):
    registry, source = prepare(tmp_path)
    try:
        with pytest.raises(ValueError, match="stale_context"):
            evaluate_once(source, submission(source), registry, current_context_hash="8" * 64)
        assert registry.consumption_count(source["receipt_hash"]) == 0
    finally:
        registry.close()


def test_revoked_receipt_cannot_authorize_guardian(tmp_path: Path):
    registry, source = prepare(tmp_path)
    try:
        registry.invalidate_receipt(
            source["receipt_hash"],
            kind="REVOKED",
            reason="The upstream evidence was revoked before Guardian consumption.",
            actor="governance-admin",
        )
        with pytest.raises(ValueError, match="receipt_revoked"):
            evaluate_once(source, submission(source), registry, current_context_hash=CONTEXT_HASH)
        assert registry.consumption_count(source["receipt_hash"]) == 0
    finally:
        registry.close()


def test_consumption_proof_is_bound_into_guardian_receipt_hash(tmp_path: Path):
    registry, source = prepare(tmp_path)
    try:
        result = evaluate_once(source, submission(source), registry, current_context_hash=CONTEXT_HASH)
        original = result["gate_receipt_hash"]
        result["single_use_consumption"]["audit_entry_hash"] = "0" * 64
        result["gate_receipt_hash"] = _hash({k: v for k, v in result.items() if k != "gate_receipt_hash"})
        assert result["gate_receipt_hash"] != original
    finally:
        registry.close()
