#!/usr/bin/env python3
"""Governed bridge from autonomous Veilleur discovery into ingress + Trieur.

The bridge validates and records evidence, applies the conservative library
router, and emits review candidates. It never writes to a library or the Core.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from tools.quality.evidence_ledger import EvidenceLedger
from tools.quality.library_trieur import route_information
from tools.quality.veilleur_v2_ingest import validate_and_record


def _impact_scopes(event: dict[str, Any]) -> list[str]:
    text = " ".join([
        str(event.get("title", "")),
        str(event.get("summary", "")),
        " ".join(event.get("domain_hints", []) if isinstance(event.get("domain_hints"), list) else []),
    ]).casefold()
    mapping = {
        "runtime": ("performance", "optimization", "runtime"),
        "security": ("security", "cybersecurity", "vulnerability", "cve"),
        "engine": ("godot", "gdscript", "engine"),
        "tooling": ("python", "ci", "testing", "workflow"),
        "visual": ("blender", "shader", "rendering", "animation"),
        "gameplay": ("game design", "combat", "loot", "expédition", "extraction"),
    }
    scopes = [scope for scope, markers in mapping.items() if any(marker in text for marker in markers)]
    return scopes or ["knowledge"]


def process_batch(batch: dict[str, Any], ledger: EvidenceLedger) -> dict[str, Any]:
    if not ledger.verify_chain():
        raise ValueError("restored evidence ledger chain verification failed")
    if batch.get("kind") != "LITD_VEILLEUR_DISCOVERY_BATCH":
        raise ValueError("invalid discovery batch kind")
    if batch.get("core_write_allowed") is not False:
        raise ValueError("discovery batch attempted Core authority")
    if batch.get("automatic_library_write_allowed") is not False:
        raise ValueError("discovery batch attempted library authority")

    rows: list[dict[str, Any]] = []
    candidates = batch.get("candidates")
    if not isinstance(candidates, list):
        raise ValueError("discovery candidates must be a list")

    for event in candidates:
        ingest = validate_and_record(event, ledger)
        row: dict[str, Any] = {
            "evidence_id": event.get("evidence_id") if isinstance(event, dict) else None,
            "ingress_status": ingest.status,
            "ingress_reason": ingest.reason,
            "canonical_hash": ingest.canonical_hash,
            "core_write_allowed": False,
            "automatic_library_write_allowed": False,
        }
        if not ingest.accepted:
            row.update({
                "route": "QUARANTINED",
                "route_confidence": 0.0,
                "route_reason": f"ingress_{ingest.status.casefold()}",
                "library_candidate": False,
                "impact_analysis": {
                    "status": "NOT_APPLICABLE",
                    "requires_review": False,
                    "scopes": [],
                },
            })
            rows.append(row)
            continue

        text = f"{event['title']}\n{event['summary']}\n{' '.join(event['domain_hints'])}"
        routing = route_information(text, source_verified=event.get("source_verified") is True)
        is_candidate = routing.route.value in {"GENERAL_LIBRARY", "LITD_LIBRARY"}
        litd_candidate = routing.route.value == "LITD_LIBRARY"
        row.update({
            "route": routing.route.value,
            "route_confidence": routing.confidence,
            "route_reason": routing.reason,
            "cross_reference": routing.cross_reference,
            "library_candidate": is_candidate,
            "impact_analysis": {
                "status": "REVIEW_REQUIRED" if litd_candidate else ("GENERAL_KNOWLEDGE_ONLY" if is_candidate else "QUARANTINED"),
                "requires_review": litd_candidate,
                "scopes": _impact_scopes(event) if is_candidate else [],
                "core_change_candidate_allowed": False,
            },
        })
        rows.append(row)

    if not ledger.verify_chain():
        raise ValueError("evidence ledger chain verification failed")

    summary = {
        "general_library_candidates": sum(r.get("route") == "GENERAL_LIBRARY" for r in rows),
        "litd_library_candidates": sum(r.get("route") == "LITD_LIBRARY" for r in rows),
        "quarantined": sum(r.get("route") == "QUARANTINED" for r in rows),
        "duplicates": sum(r.get("ingress_status") == "DUPLICATE" for r in rows),
        "impact_reviews_required": sum(r.get("impact_analysis", {}).get("requires_review") is True for r in rows),
    }
    return {
        "kind": "LITD_VEILLEUR_TRIAGE_BATCH",
        "status": "READY_FOR_GOVERNED_LIBRARY_REVIEW",
        "source_generated_at": batch.get("generated_at"),
        "summary": summary,
        "items": rows,
        "ledger_chain_valid": True,
        "core_write_allowed": False,
        "automatic_library_write_allowed": False,
        "automatic_core_change_candidate_allowed": False,
        "next_stage": "GOVERNED_LIBRARY_REVIEW_AND_IMPACT_DECISION",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--ledger", default="reports/veilleur-evidence-ledger.sqlite3")
    parser.add_argument("--output", default="reports/veilleur-triage.json")
    args = parser.parse_args()

    batch = json.loads(Path(args.input).read_text(encoding="utf-8"))
    ledger_path = Path(args.ledger)
    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    ledger = EvidenceLedger(ledger_path)
    try:
        report = process_batch(batch, ledger)
    finally:
        ledger.close()
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(report["summary"], sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
