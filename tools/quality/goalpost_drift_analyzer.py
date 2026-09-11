#!/usr/bin/env python3
"""Detect moving-goalpost risk by crossing target history with real measurements.

This analyzer is advisory/governance-only. It never changes targets and never
writes to the Core. A signal means human/Core review is required.
"""
from __future__ import annotations

import argparse
import json
from hashlib import sha256
from pathlib import Path
from typing import Any

from tools.quality.target_drift_budget import relaxation_ratio

KIND = "LITD_GOALPOST_DRIFT_REPORT"


def _hash(payload: Any) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def _metric_series(measurements: list[dict[str, Any]], target_id: str) -> list[float]:
    values: list[float] = []
    for row in measurements:
        metrics = row.get("canonical_metrics", {})
        value = metrics.get(target_id) if isinstance(metrics, dict) else None
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            values.append(float(value))
    return values


def analyze(snapshots: list[dict[str, Any]], measurements: list[dict[str, Any]]) -> dict[str, Any]:
    ordered = sorted(snapshots, key=lambda row: row.get("sequence", 0))
    if len(ordered) < 2:
        result = {"kind": KIND, "status": "INCONCLUSIVE", "reason": "insufficient_target_history", "signals": [], "core_write_allowed": False}
        result["report_hash"] = _hash(result)
        return result

    first, last = ordered[0], ordered[-1]
    signals: list[dict[str, Any]] = []
    reviewed = 0
    for target_id in sorted(set(first.get("targets", {})) & set(last.get("targets", {}))):
        baseline_target = first["targets"].get(target_id)
        current_target = last["targets"].get(target_id)
        if not isinstance(baseline_target, dict) or not isinstance(current_target, dict):
            continue
        drift = relaxation_ratio(baseline_target, current_target)
        if drift.get("status") != "MORE_PERMISSIVE":
            continue
        reviewed += 1
        values = _metric_series(measurements, target_id)
        if len(values) < 2:
            signals.append({"target_id": target_id, "verdict": "INCONCLUSIVE", "reason": "insufficient_measurements", "target_relaxation_ratio": drift.get("ratio"), "measurement_count": len(values)})
            continue

        start, end = values[0], values[-1]
        # Improvement is evaluated relative to target semantics, not raw sign.
        kind = baseline_target.get("kind")
        if kind == "max":
            improved = end < start
        elif kind == "min":
            improved = end > start
        elif kind == "window":
            low, high = float(baseline_target["min"]), float(baseline_target["max"])
            distance = lambda x: 0.0 if low <= x <= high else (low - x if x < low else x - high)
            improved = distance(end) < distance(start)
        else:
            signals.append({"target_id": target_id, "verdict": "INCONCLUSIVE", "reason": "unsupported_target_kind", "target_relaxation_ratio": drift.get("ratio"), "measurement_count": len(values)})
            continue

        verdict = "NO_GOALPOST_SIGNAL" if improved else "GOALPOST_DRIFT_REVIEW_REQUIRED"
        signals.append({
            "target_id": target_id,
            "verdict": verdict,
            "target_relaxation_ratio": drift.get("ratio"),
            "measurement_count": len(values),
            "first_measurement": start,
            "latest_measurement": end,
            "measurement_improved_against_original_target": improved,
        })

    flagged = sum(row["verdict"] == "GOALPOST_DRIFT_REVIEW_REQUIRED" for row in signals)
    result = {
        "kind": KIND,
        "status": "REVIEW_REQUIRED" if flagged else ("OK" if reviewed else "NO_PERMISSIVE_TARGET_DRIFT"),
        "summary": {"permissive_targets_reviewed": reviewed, "goalpost_signals": flagged},
        "signals": signals,
        "authority": "advisory_only_core_or_human_decision_required",
        "core_write_allowed": False,
        "automatic_target_change_allowed": False,
    }
    result["report_hash"] = _hash(result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Cross LITD target history with canonical telemetry")
    parser.add_argument("--snapshots", nargs="+", type=Path, required=True)
    parser.add_argument("--measurements", nargs="+", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    snapshots = [json.loads(p.read_text(encoding="utf-8")) for p in args.snapshots]
    measurements: list[dict[str, Any]] = []
    for path in args.measurements:
        payload = json.loads(path.read_text(encoding="utf-8"))
        if payload.get("kind") == "MEASUREMENT_CANDIDATE":
            for report in payload.get("reports", []):
                measurements.append(report)
        else:
            measurements.append(payload)
    report = analyze(snapshots, measurements)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, sort_keys=True, indent=2), encoding="utf-8")
    print(json.dumps({"status": report["status"], **report.get("summary", {})}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
