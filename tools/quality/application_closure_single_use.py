#!/usr/bin/env python3
"""Single-use post-merge closure bound to a merge execution receipt.

The application decision is consumed by MERGE_EXECUTION. This wrapper then
registers and consumes the resulting merge receipt exactly once when post-merge
measurement and provenance close successfully. Blocked closure evidence does not
burn the merge receipt and may be corrected.
"""
from __future__ import annotations

from typing import Any

from tools.quality.application_closure_contract import _hash, evaluate as evaluate_closure
from tools.quality.merge_execution_gate import verify_merge_execution_receipt
from tools.quality.receipt_consumption_registry import ReceiptConsumptionRegistry

CONSUMER = "APPLICATION_CLOSURE_CONTRACT"


def register_merge_execution_receipt(
    registry: ReceiptConsumptionRegistry,
    receipt: dict[str, Any],
    *,
    context_hash: str,
) -> None:
    verify_merge_execution_receipt(receipt)
    receipt_hash = receipt["merge_execution_hash"]
    source_hash = receipt.get("source_application_decision_hash")
    if not isinstance(source_hash, str):
        raise ValueError("merge execution source application decision hash required")
    registry.register_receipt(
        receipt_id=f"litd:merge-execution:closure:{receipt_hash}",
        receipt_hash=receipt_hash,
        receipt_kind=receipt["kind"],
        source_hash=source_hash,
        context_hash=context_hash,
        expected_consumer=CONSUMER,
    )


def evaluate_closure_once(
    decision: dict[str, Any],
    merge_receipt: dict[str, Any],
    evidence: dict[str, Any],
    registry: ReceiptConsumptionRegistry,
    *,
    current_context_hash: str,
    actor: str,
) -> dict[str, Any]:
    verify_merge_execution_receipt(merge_receipt)
    if merge_receipt.get("source_application_decision_hash") != decision.get("application_decision_hash"):
        raise ValueError("merge receipt is not bound to this application decision")
    if evidence.get("merge_execution_hash") != merge_receipt["merge_execution_hash"]:
        raise ValueError("merge execution hash mismatch")
    if evidence.get("merged_pr_number") != merge_receipt.get("pull_request_number"):
        raise ValueError("merged PR number mismatch")
    if evidence.get("repository") != merge_receipt.get("repository"):
        raise ValueError("closure repository does not match merge receipt")
    if evidence.get("merged_source_commit_sha") != merge_receipt.get("authorized_head_sha"):
        raise ValueError("merged source SHA does not match single-use merge authorization")

    result = evaluate_closure(decision, evidence)
    if result.get("status") != "APPLIED_MEASURED_PROVENANCE_VERIFIED":
        return result

    claim = registry.consume(
        merge_receipt["merge_execution_hash"],
        consumer=CONSUMER,
        actor=actor,
        current_context_hash=current_context_hash,
    )
    if not claim.accepted:
        raise ValueError(f"single-use receipt rejected:{claim.reason}")

    result.pop("closure_hash", None)
    result["source_merge_execution_hash"] = merge_receipt["merge_execution_hash"]
    result["single_use_consumption"] = {
        "source_receipt_hash": merge_receipt["merge_execution_hash"],
        "consumer": CONSUMER,
        "audit_entry_hash": claim.audit_entry_hash,
        "status": "CONSUMED_ONCE",
    }
    result["merge_authorization_single_use_verified"] = True
    result["external_merge_enforcement_verified"] = bool(
        merge_receipt.get("external_merge_enforcement_verified") is True
    )
    result["closure_hash"] = _hash(result)
    return result
