#!/usr/bin/env python3
"""Create a traceable review candidate from LITD goalpost-drift signals.

This module is advisory/governance-only. It never edits canonical targets, gameplay
content, or the Core. A review candidate exists only to force an explicit governed
or human decision when telemetry shows a permissive target drift without measured
improvement toward the original target.
"""
from __future__ import annotations

import argparse
import json
from hashlib import sha256
from pathlib import Path
from typing import Any

KIND = "LITD_GOALPOST_REVIEW_CANDIDATE"
ALLOWED_DECISIONS = [
    "REJECT_TARGET_RELAXATION",
    "REQUEST_IMPLEMENTATION_FIX",
    "REQUEST_MORE_EVIDENCE",
    "PROPOSE_TARGET_REVISION",
]


def _canonical_hash(payload: dict[str, Any]) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def _review_signals(report: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for signal in report.get("signals", []):
        if not isinstance(signal, dict):
            continue
        if signal.get("verdict") != "GOALPOST_DRIFT_REVIEW_REQUIRED":
            continue
        rows.append({
            "target_id": signal.get("target_id"),
            "target_relaxation_ratio": signal.get("target_relaxation_ratio"),
            "measurement_count": signal.get("measurement_count"),
            "first_measurement": signal.get("first_measurement"),
            "latest_measurement": signal.get("latest_measurement"),
            "measurement_improved_against_original_target": signal.get("measurement_improved_against_original_target"),
            "comparison_identity": signal.get("comparison_identity"),
            "verdict": signal.get("verdict"),
        })
    return rows


def build_goalpost_review_candidate(report: dict[str, Any]) -> dict[str, Any]:
    causes = _review_signals(report)
    if not causes:
        payload: dict[str, Any] = {
            "kind": KIND,
            "status": "NO_DECISION_REQUIRED",
            "causes": [],
            "evidence": [],
            "review_questions": [],
            "requires_human_or_governed_decision": False,
            "automatic_target_change_allowed": False,
            "core_write_allowed": False,
        }
    else:
        payload = {
            "kind": KIND,
            "status": "REQUIRES_DECISION",
            "causes": causes,
            "evidence": [{
                "goalpost_report_hash": report.get("report_hash"),
                "measurement_source": report.get("measurement_source"),
                "goalpost_report_status": report.get("status"),
                "signal_count": len(causes),
            }],
            "review_questions": [
                "La cible a-t-elle été assouplie pour une raison de design indépendante des résultats mesurés ?",
                "La mesure réelle progresse-t-elle suffisamment vers l'objectif original pour justifier de conserver l'assouplissement ?",
                "Faut-il corriger l'implémentation plutôt que modifier davantage la cible ?",
                "Faut-il obtenir des mesures comparables supplémentaires avant toute décision ?",
            ],
            "allowed_decisions": ALLOWED_DECISIONS,
            "requires_human_or_governed_decision": True,
            "automatic_target_change_allowed": False,
            "core_write_allowed": False,
        }

    payload["candidate_hash"] = _canonical_hash(payload)
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Build governed review candidate from LITD goalpost drift report")
    parser.add_argument("goalpost_report", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    report = json.loads(args.goalpost_report.read_text(encoding="utf-8"))
    candidate = build_goalpost_review_candidate(report)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(candidate, sort_keys=True, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"status": candidate["status"], "causes": len(candidate["causes"])}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
