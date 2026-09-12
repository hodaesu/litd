#!/usr/bin/env python3
"""Single-use wrapper around bounded implementation evaluation.

The wrapped bounded implementation validation remains pure. Only after the
Guardian gate receipt and implementation evidence pass all existing checks do
we atomically consume the registered Guardian gate receipt. The emitted
implementation evaluation is then re-hashed with the consumption audit proof,
so downstream application review is bound to the single-use claim.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from tools.quality.bounded_implementation_contract import _hash, _verify_embedded_hash, evaluate
from tools.quality.receipt_consumption_registry import (
    PROJECT_ID,
    TARGET_ROUTE,
    ReceiptConsumptionRegistry,
)

CONSUMER = "BOUNDED_IMPLEMENTATION_GATE"


def register_guardian_gate_receipt(
    registry: ReceiptConsumptionRegistry,
    gate: dict[str, Any],
    *,
    context_hash: str,
) -> None:
    """Register one Guardian gate receipt for later single-use consumption."""
    _verify_embedded_hash(gate, "gate_receipt_hash")
    if gate.get("kind") != "LITD_GUARDIAN_CHANGE_GATE_RECEIPT":
        raise ValueError("invalid Guardian gate receipt kind")
    if gate.get("project_id") != PROJECT_ID:
        raise ValueError("Guardian gate project scope mismatch")
    if gate.get("target_route") != TARGET_ROUTE:
        raise ValueError("Guardian gate route scope mismatch")
    source_hash = gate.get("source_candidate_hash")
    if not isinstance(source_hash, str) or len(source_hash) != 64:
        raise ValueError("Guardian gate source candidate hash required")
    receipt_hash = gate["gate_receipt_hash"]
    registry.register_receipt(
        receipt_id=f"litd:guardian-gate:{receipt_hash}",
        receipt_hash=receipt_hash,
        receipt_kind=gate["kind"],
        source_hash=source_hash,
        context_hash=context_hash,
        expected_consumer=CONSUMER,
    )


def evaluate_once(
    gate: dict[str, Any],
    evidence: dict[str, Any],
    registry: ReceiptConsumptionRegistry,
    *,
    current_context_hash: str,
    actor: str,
) -> dict[str, Any]:
    """Validate implementation evidence and consume its Guardian receipt once."""
    if not actor.strip():
        raise ValueError("actor is required")
    result = evaluate(gate, evidence)
    if result.get("status") != "READY_FOR_APPLICATION_REVIEW":
        return result

    claim = registry.consume(
        gate["gate_receipt_hash"],
        consumer=CONSUMER,
        actor=actor.strip(),
        current_context_hash=current_context_hash,
    )
    if not claim.accepted:
        raise ValueError(f"single-use receipt rejected:{claim.reason}")

    result.pop("evaluation_hash", None)
    result["single_use_consumption"] = {
        "source_receipt_hash": gate["gate_receipt_hash"],
        "consumer": CONSUMER,
        "audit_entry_hash": claim.audit_entry_hash,
        "status": "CONSUMED_ONCE",
    }
    result["evaluation_hash"] = _hash(result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gate", required=True)
    parser.add_argument("--evidence", required=True)
    parser.add_argument("--registry", required=True)
    parser.add_argument("--context-hash", required=True)
    parser.add_argument("--actor", required=True)
    parser.add_argument("--output", default="reports/bounded-implementation-single-use.json")
    args = parser.parse_args()

    gate = json.loads(Path(args.gate).read_text(encoding="utf-8"))
    evidence = json.loads(Path(args.evidence).read_text(encoding="utf-8"))
    registry = ReceiptConsumptionRegistry(args.registry)
    try:
        result = evaluate_once(
            gate,
            evidence,
            registry,
            current_context_hash=args.context_hash,
            actor=args.actor,
        )
    finally:
        registry.close()

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "single_use": "single_use_consumption" in result}, sort_keys=True))
    return 0 if result["status"] == "READY_FOR_APPLICATION_REVIEW" else 2


if __name__ == "__main__":
    raise SystemExit(main())
