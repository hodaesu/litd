#!/usr/bin/env python3
"""Single-use wrapper around the Guardian Change Gate.

The wrapped Guardian validation remains pure. Only after the input receipt and
submission pass all existing checks do we atomically consume the registered
receipt. The emitted Guardian receipt is then re-hashed with the consumption
audit proof, so downstream stages are bound to the single-use claim.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from tools.quality.guardian_change_gate import _hash, _verify_embedded_hash, evaluate
from tools.quality.receipt_consumption_registry import (
    PROJECT_ID,
    TARGET_ROUTE,
    ReceiptConsumptionRegistry,
)

CONSUMER = "GUARDIAN_CHANGE_GATE"


def register_resolution_receipt(
    registry: ReceiptConsumptionRegistry,
    receipt: dict[str, Any],
    *,
    context_hash: str,
) -> None:
    """Register one governed resolution for later single-use Guardian consumption."""
    _verify_embedded_hash(receipt, "receipt_hash")
    if receipt.get("kind") != "LITD_VEILLEUR_REVIEW_RESOLUTION_RECEIPT":
        raise ValueError("invalid resolution receipt kind")
    if receipt.get("project_id") != PROJECT_ID:
        raise ValueError("resolution receipt project scope mismatch")
    if receipt.get("target_route") != TARGET_ROUTE:
        raise ValueError("resolution receipt route scope mismatch")
    source_hash = receipt.get("candidate_hash")
    if not isinstance(source_hash, str):
        raise ValueError("resolution receipt candidate hash required")
    receipt_hash = receipt["receipt_hash"]
    registry.register_receipt(
        receipt_id=f"litd:veilleur-resolution:{receipt_hash}",
        receipt_hash=receipt_hash,
        receipt_kind=receipt["kind"],
        source_hash=source_hash,
        context_hash=context_hash,
        expected_consumer=CONSUMER,
    )


def evaluate_once(
    receipt: dict[str, Any],
    submission: dict[str, Any],
    registry: ReceiptConsumptionRegistry,
    *,
    current_context_hash: str,
) -> dict[str, Any]:
    """Validate a Guardian decision and consume its source receipt exactly once."""
    result = evaluate(receipt, submission)
    claim = registry.consume(
        receipt["receipt_hash"],
        consumer=CONSUMER,
        actor=submission["decided_by"].strip(),
        current_context_hash=current_context_hash,
    )
    if not claim.accepted:
        raise ValueError(f"single-use receipt rejected:{claim.reason}")

    result.pop("gate_receipt_hash", None)
    result["single_use_consumption"] = {
        "source_receipt_hash": receipt["receipt_hash"],
        "consumer": CONSUMER,
        "audit_entry_hash": claim.audit_entry_hash,
        "status": "CONSUMED_ONCE",
    }
    result["gate_receipt_hash"] = _hash(result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--receipt", required=True)
    parser.add_argument("--submission", required=True)
    parser.add_argument("--registry", required=True)
    parser.add_argument("--context-hash", required=True)
    parser.add_argument("--output", default="reports/guardian-change-gate-single-use.json")
    args = parser.parse_args()

    receipt = json.loads(Path(args.receipt).read_text(encoding="utf-8"))
    submission = json.loads(Path(args.submission).read_text(encoding="utf-8"))
    registry = ReceiptConsumptionRegistry(args.registry)
    try:
        result = evaluate_once(
            receipt,
            submission,
            registry,
            current_context_hash=args.context_hash,
        )
    finally:
        registry.close()

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"decision": result["decision"], "status": result["status"], "single_use": True}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
