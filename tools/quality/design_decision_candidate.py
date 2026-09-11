#!/usr/bin/env python3
"""Create a review-only decision candidate from blocking LITD design regressions.

This module never edits the Core or gameplay data. It converts measured blocking
regressions into a traceable review object that a human/governance step may accept,
reject, investigate, or use to request a new implementation.
"""
from __future__ import annotations

import argparse
import json
from hashlib import sha256
from pathlib import Path
from typing import Any


def _blocking_items(comparison: dict[str, Any]) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for report in comparison.get("reports", []):
        if not isinstance(report, dict):
            continue
        evaluation = report.get("design_target_evaluation", {})
        for row in evaluation.get("evaluations", []):
            if not isinstance(row, dict):
                continue
            if (
                row.get("verdict") == "FARTHER_FROM_TARGET"
                and row.get("severity") == "high"
                and not bool(row.get("provisional", False))
            ):
                items.append({
                    "report": report.get("report"),
                    "metric": row.get("metric"),
                    "baseline": row.get("baseline"),
                    "current": row.get("current"),
                    "target": row.get("target"),
                    "verdict": row.get("verdict"),
                    "severity": row.get("severity"),
                })
    return items


def build_decision_candidate(comparisons: list[dict[str, Any]]) -> dict[str, Any]:
    causes: list[dict[str, Any]] = []
    evidence: list[dict[str, Any]] = []
    for comparison in comparisons:
        rows = _blocking_items(comparison)
        if rows:
            causes.extend(rows)
            evidence.append({
                "comparison_hash": comparison.get("comparison_hash"),
                "current_candidate_hash": comparison.get("current_candidate_hash"),
                "baseline_candidate_hash": comparison.get("baseline_candidate_hash"),
                "current_run_id": comparison.get("current_run_id"),
                "baseline_run_id": comparison.get("baseline_run_id"),
            })

    if not causes:
        payload: dict[str, Any] = {
            "kind": "LITD_DESIGN_REVIEW_CANDIDATE",
            "status": "NO_DECISION_REQUIRED",
            "causes": [],
            "evidence": [],
            "review_questions": [],
            "requires_human_or_governed_decision": False,
            "core_write_allowed": False,
        }
    else:
        payload = {
            "kind": "LITD_DESIGN_REVIEW_CANDIDATE",
            "status": "REQUIRES_DECISION",
            "causes": causes,
            "evidence": evidence,
            "review_questions": [
                "La cible canonique est-elle toujours valide ?",
                "La régression est-elle un effet voulu et documenté du changement ?",
                "Faut-il corriger l'implémentation plutôt que modifier la cible ?",
                "Une nouvelle mesure comparable est-elle nécessaire avant décision ?",
            ],
            "allowed_decisions": [
                "REJECT_CHANGE",
                "REQUEST_IMPLEMENTATION_FIX",
                "REQUEST_MORE_EVIDENCE",
                "PROPOSE_TARGET_REVISION",
            ],
            "requires_human_or_governed_decision": True,
            "core_write_allowed": False,
        }

    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    payload["candidate_hash"] = sha256(canonical.encode("utf-8")).hexdigest()
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Build review-only decision candidate from LITD design comparisons")
    parser.add_argument("comparisons", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    comparisons = [json.loads(path.read_text(encoding="utf-8")) for path in args.comparisons]
    result = build_decision_candidate(comparisons)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "causes": len(result["causes"])}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
