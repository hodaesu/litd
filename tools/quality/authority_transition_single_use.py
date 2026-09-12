#!/usr/bin/env python3
"""Single-use wrappers for authority-bearing LITD governance transitions.

Pure validators remain deterministic and side-effect free. These wrappers validate
first, then atomically consume the registered upstream artifact only when the
transition actually advances governed authority. The consumption audit proof is
bound into the downstream artifact hash.

This module deliberately stops at the application decision. An authorized
application decision must next be consumed atomically by a distinct
MERGE_EXECUTION transition; post-merge closure must consume the resulting merge
receipt, not the application decision itself. Until that transition exists, #331
remains open and merge replay is not claimed as solved.
"""
from __future__ import annotations

from typing import Any

from tools.quality.application_decision_gate import (
    _hash as application_hash,
    _verify_embedded_hash as verify_application_source,
    evaluate as evaluate_application,
)
from tools.quality.bounded_implementation_contract import (
    _hash as evaluation_hash,
    _verify_embedded_hash as verify_gate_source,
    evaluate as evaluate_bounded,
)
from tools.quality.receipt_consumption_registry import (
    PROJECT_ID,
    TARGET_ROUTE,
    ReceiptConsumptionRegistry,
)

BOUNDED_CONSUMER = "BOUNDED_IMPLEMENTATION_CONTRACT"
APPLICATION_CONSUMER = "APPLICATION_DECISION_GATE"
NEXT_REQUIRED_CONSUMER = "MERGE_EXECUTION"


def _require_scope(payload: dict[str, Any], label: str) -> None:
    if payload.get("project_id") != PROJECT_ID:
        raise ValueError(f"{label} project scope mismatch")
    if payload.get("target_route") != TARGET_ROUTE:
        raise ValueError(f"{label} route scope mismatch")


def _claim_payload(source_hash: str, consumer: str, audit_hash: str) -> dict[str, str]:
    return {
        "source_receipt_hash": source_hash,
        "consumer": consumer,
        "audit_entry_hash": audit_hash,
        "status": "CONSUMED_ONCE",
    }


def register_guardian_gate(
    registry: ReceiptConsumptionRegistry,
    gate: dict[str, Any],
    *,
    context_hash: str,
) -> None:
    verify_gate_source(gate, "gate_receipt_hash")
    if gate.get("kind") != "LITD_GUARDIAN_CHANGE_GATE_RECEIPT":
        raise ValueError("invalid Guardian gate receipt kind")
    _require_scope(gate, "Guardian gate")
    if gate.get("status") != "READY_FOR_BOUNDED_IMPLEMENTATION_PR" or gate.get("implementation_pr_allowed") is not True:
        raise ValueError("Guardian gate is not authority-bearing")
    source_hash = gate.get("source_resolution_receipt_hash")
    if not isinstance(source_hash, str):
        raise ValueError("Guardian gate source resolution hash required")
    receipt_hash = gate["gate_receipt_hash"]
    registry.register_receipt(
        receipt_id=f"litd:guardian-gate:{receipt_hash}",
        receipt_hash=receipt_hash,
        receipt_kind=gate["kind"],
        source_hash=source_hash,
        context_hash=context_hash,
        expected_consumer=BOUNDED_CONSUMER,
    )


def evaluate_bounded_once(
    gate: dict[str, Any],
    evidence: dict[str, Any],
    registry: ReceiptConsumptionRegistry,
    *,
    current_context_hash: str,
    actor: str,
) -> dict[str, Any]:
    result = evaluate_bounded(gate, evidence)
    # A blocked evaluation advances no authority and must not burn the gate;
    # remediation can produce a corrected evidence set against the same plan.
    if result.get("status") != "READY_FOR_APPLICATION_REVIEW":
        return result
    claim = registry.consume(
        gate["gate_receipt_hash"],
        consumer=BOUNDED_CONSUMER,
        actor=actor,
        current_context_hash=current_context_hash,
    )
    if not claim.accepted:
        raise ValueError(f"single-use receipt rejected:{claim.reason}")
    result.pop("evaluation_hash", None)
    result["single_use_consumption"] = _claim_payload(
        gate["gate_receipt_hash"], BOUNDED_CONSUMER, claim.audit_entry_hash
    )
    result["evaluation_hash"] = evaluation_hash(result)
    return result


def register_implementation_evaluation(
    registry: ReceiptConsumptionRegistry,
    evaluation: dict[str, Any],
    *,
    context_hash: str,
) -> None:
    verify_application_source(evaluation, "evaluation_hash")
    if evaluation.get("kind") != "LITD_BOUNDED_IMPLEMENTATION_EVALUATION":
        raise ValueError("invalid bounded implementation evaluation kind")
    _require_scope(evaluation, "implementation evaluation")
    if evaluation.get("status") != "READY_FOR_APPLICATION_REVIEW" or evaluation.get("blockers") != []:
        raise ValueError("implementation evaluation is not authority-bearing")
    source_hash = evaluation.get("source_gate_receipt_hash")
    if not isinstance(source_hash, str):
        raise ValueError("implementation evaluation source gate hash required")
    receipt_hash = evaluation["evaluation_hash"]
    registry.register_receipt(
        receipt_id=f"litd:implementation-evaluation:{receipt_hash}",
        receipt_hash=receipt_hash,
        receipt_kind=evaluation["kind"],
        source_hash=source_hash,
        context_hash=context_hash,
        expected_consumer=APPLICATION_CONSUMER,
    )


def evaluate_application_once(
    evaluation: dict[str, Any],
    decision: dict[str, Any],
    registry: ReceiptConsumptionRegistry,
    *,
    current_context_hash: str,
) -> dict[str, Any]:
    result = evaluate_application(evaluation, decision)
    claim = registry.consume(
        evaluation["evaluation_hash"],
        consumer=APPLICATION_CONSUMER,
        actor=decision["decided_by"].strip(),
        current_context_hash=current_context_hash,
    )
    if not claim.accepted:
        raise ValueError(f"single-use receipt rejected:{claim.reason}")
    result.pop("application_decision_hash", None)
    result["single_use_consumption"] = _claim_payload(
        evaluation["evaluation_hash"], APPLICATION_CONSUMER, claim.audit_entry_hash
    )
    # The downstream application decision is intentionally not registered here:
    # it must be registered for the future MERGE_EXECUTION consumer so one
    # authorization cannot drive multiple merges.
    result["next_single_use_consumer_required"] = NEXT_REQUIRED_CONSUMER
    result["merge_execution_single_use_verified"] = False
    result["application_decision_hash"] = application_hash(result)
    return result
