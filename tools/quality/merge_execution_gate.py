#!/usr/bin/env python3
"""Single-use pre-merge authorization for governed LITD application decisions.

The gate binds one authorized application decision to one repository, pull request,
head SHA and observed base SHA. It consumes the application decision atomically
before a separate GitHub merge action. The caller must still execute the merge
with expected-head-SHA protection and preserve GitHub evidence.

This prototype does not itself configure GitHub branch protection, so #331 remains
open until the real merge path is forced to require this receipt.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any

from tools.quality.application_decision_gate import _hash, _verify_embedded_hash
from tools.quality.receipt_consumption_registry import (
    PROJECT_ID,
    TARGET_ROUTE,
    ReceiptConsumptionRegistry,
)

CONSUMER = "MERGE_EXECUTION"
REPOSITORY = "hodaesu/litd"


def _hex(value: Any, length: int) -> bool:
    return isinstance(value, str) and len(value) == length and all(ch in "0123456789abcdef" for ch in value)


def _aware_iso(value: Any) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return dt.tzinfo is not None and dt.utcoffset() is not None


def _nonempty_unique_strings(value: Any, field: str) -> list[str]:
    if not isinstance(value, list) or not value or not all(isinstance(item, str) and item.strip() for item in value):
        raise ValueError(f"{field} must be a non-empty string list")
    if len(value) != len(set(value)):
        raise ValueError(f"{field} must not contain duplicates")
    return value


def verify_application_decision(decision: dict[str, Any]) -> None:
    _verify_embedded_hash(decision, "application_decision_hash")
    if decision.get("kind") != "LITD_APPLICATION_DECISION_RECEIPT":
        raise ValueError("invalid application decision receipt kind")
    if decision.get("project_id") != PROJECT_ID:
        raise ValueError("application decision project scope mismatch")
    if decision.get("target_route") != TARGET_ROUTE:
        raise ValueError("application decision route scope mismatch")
    if decision.get("outcome") != "APPLICATION_AUTHORIZED_PENDING_SEPARATE_MERGE":
        raise ValueError("application decision is not merge-authorized")
    if decision.get("merge_authorized") is not True:
        raise ValueError("merge authorization invariant missing")
    if decision.get("merge_must_be_separate_action") is not True:
        raise ValueError("separate merge invariant missing")
    if decision.get("automatic_merge_allowed") is not False:
        raise ValueError("automatic merge authority forbidden")
    if not _hex(decision.get("implementation_commit_sha"), 40):
        raise ValueError("implementation_commit_sha must be 40 lowercase hex")
    if not _hex(decision.get("source_evaluation_hash"), 64):
        raise ValueError("source_evaluation_hash must be 64 lowercase hex")


def register_application_decision(
    registry: ReceiptConsumptionRegistry,
    decision: dict[str, Any],
    *,
    context_hash: str,
) -> None:
    verify_application_decision(decision)
    receipt_hash = decision["application_decision_hash"]
    registry.register_receipt(
        receipt_id=f"litd:application-decision:merge:{receipt_hash}",
        receipt_hash=receipt_hash,
        receipt_kind=decision["kind"],
        source_hash=decision["source_evaluation_hash"],
        context_hash=context_hash,
        expected_consumer=CONSUMER,
    )


def authorize_merge_once(
    decision: dict[str, Any],
    request: dict[str, Any],
    registry: ReceiptConsumptionRegistry,
    *,
    current_context_hash: str,
) -> dict[str, Any]:
    verify_application_decision(decision)
    required = {
        "application_decision_hash",
        "repository",
        "pull_request_number",
        "observed_head_sha",
        "observed_base_sha",
        "github_mergeable",
        "all_required_checks_successful",
        "required_check_evidence_refs",
        "approval_evidence_refs",
        "requested_by",
        "requested_at",
    }
    missing = sorted(required - set(request))
    if missing:
        raise ValueError("missing merge execution fields:" + ",".join(missing))
    if request["application_decision_hash"] != decision["application_decision_hash"]:
        raise ValueError("application decision hash mismatch")
    if request["repository"] != REPOSITORY:
        raise ValueError("merge repository mismatch")
    if not isinstance(request["pull_request_number"], int) or request["pull_request_number"] <= 0:
        raise ValueError("pull_request_number must be positive integer")
    if not _hex(request["observed_head_sha"], 40):
        raise ValueError("observed_head_sha must be 40 lowercase hex")
    if not _hex(request["observed_base_sha"], 40):
        raise ValueError("observed_base_sha must be 40 lowercase hex")
    if request["observed_head_sha"] != decision["implementation_commit_sha"]:
        raise ValueError("observed PR head is not the authorized implementation SHA")
    if request["github_mergeable"] is not True:
        raise ValueError("GitHub must report PR mergeable")
    if request["all_required_checks_successful"] is not True:
        raise ValueError("all required checks must be successful")
    checks = _nonempty_unique_strings(request["required_check_evidence_refs"], "required_check_evidence_refs")
    approvals = _nonempty_unique_strings(request["approval_evidence_refs"], "approval_evidence_refs")
    if not isinstance(request["requested_by"], str) or not request["requested_by"].strip():
        raise ValueError("requested_by required")
    if not _aware_iso(request["requested_at"]):
        raise ValueError("requested_at must be timezone-aware ISO-8601")

    claim = registry.consume(
        decision["application_decision_hash"],
        consumer=CONSUMER,
        actor=request["requested_by"].strip(),
        current_context_hash=current_context_hash,
    )
    if not claim.accepted:
        raise ValueError(f"single-use receipt rejected:{claim.reason}")

    receipt = {
        "kind": "LITD_MERGE_EXECUTION_RECEIPT",
        "project_id": PROJECT_ID,
        "target_route": TARGET_ROUTE,
        "status": "READY_FOR_SEPARATE_GITHUB_MERGE",
        "source_application_decision_hash": decision["application_decision_hash"],
        "source_evaluation_hash": decision["source_evaluation_hash"],
        "repository": REPOSITORY,
        "pull_request_number": request["pull_request_number"],
        "authorized_head_sha": request["observed_head_sha"],
        "observed_base_sha": request["observed_base_sha"],
        "required_check_evidence_refs": list(checks),
        "approval_evidence_refs": list(approvals),
        "requested_by": request["requested_by"].strip(),
        "requested_at": request["requested_at"],
        "single_use_consumption": {
            "source_receipt_hash": decision["application_decision_hash"],
            "consumer": CONSUMER,
            "audit_entry_hash": claim.audit_entry_hash,
            "status": "CONSUMED_ONCE",
        },
        "merge_once_authorized": True,
        "github_merge_action_required": True,
        "expected_head_sha_enforcement_required": True,
        "post_merge_measurement_required": True,
        "provenance_checkpoint_required": True,
        "external_merge_enforcement_verified": False,
        "core_write_allowed": False,
        "automatic_merge_allowed": False,
        "automatic_target_change_allowed": False,
        "authority": "single_use_merge_execution_receipt_only_external_github_merge_is_separate",
    }
    receipt["merge_execution_hash"] = _hash(receipt)
    return receipt


def verify_merge_execution_receipt(receipt: dict[str, Any]) -> None:
    _verify_embedded_hash(receipt, "merge_execution_hash")
    if receipt.get("kind") != "LITD_MERGE_EXECUTION_RECEIPT":
        raise ValueError("invalid merge execution receipt kind")
    if receipt.get("project_id") != PROJECT_ID or receipt.get("target_route") != TARGET_ROUTE:
        raise ValueError("merge execution scope mismatch")
    if receipt.get("status") != "READY_FOR_SEPARATE_GITHUB_MERGE":
        raise ValueError("merge execution receipt not ready")
    if receipt.get("merge_once_authorized") is not True:
        raise ValueError("single merge authorization invariant missing")
    if receipt.get("automatic_merge_allowed") is not False:
        raise ValueError("automatic merge authority forbidden")
    if receipt.get("expected_head_sha_enforcement_required") is not True:
        raise ValueError("expected head SHA enforcement invariant missing")
