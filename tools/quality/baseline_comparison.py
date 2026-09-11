#!/usr/bin/env python3
"""Compare a LITD measurement candidate with its newest compatible baseline."""
from __future__ import annotations

import argparse
import json
from hashlib import sha256
from pathlib import Path
from typing import Any

from tools.quality.baseline_selector import (
    canonical_baseline_by_report,
    load_candidates,
    select_latest_compatible_baseline,
)
from tools.quality.design_target_evaluator import evaluate_design_targets, load_targets


def compare_candidate_to_baseline(
    current: dict[str, Any],
    prior_candidates: list[dict[str, Any]],
    registry: dict[str, Any],
) -> dict[str, Any]:
    baseline = select_latest_compatible_baseline(current, prior_candidates)
    if baseline is None:
        result = {
            "kind": "MEASUREMENT_BASELINE_COMPARISON",
            "status": "NO_COMPATIBLE_BASELINE",
            "current_candidate_hash": current.get("candidate_hash"),
            "current_run_id": current.get("run_id"),
            "baseline_candidate_hash": None,
            "baseline_run_id": None,
            "reports": [],
            "summary": {
                "closer_to_target": 0,
                "farther_from_target": 0,
                "in_target": 0,
                "blocking_regressions": 0,
            },
            "core_write_allowed": False,
        }
        result["comparison_hash"] = _comparison_hash(result)
        return result

    baselines = canonical_baseline_by_report(current, baseline)
    rows: list[dict[str, Any]] = []
    closer = farther = in_target = blocking = 0
    for report in current.get("reports", []):
        if not isinstance(report, dict):
            continue
        report_name = str(report.get("report", "<unknown>"))
        current_metrics = report.get("canonical_metrics", {})
        if not isinstance(current_metrics, dict):
            current_metrics = {}
        evaluation = evaluate_design_targets(
            current=current_metrics,
            baseline=baselines.get(report_name, {}),
            registry=registry,
        )
        for item in evaluation["evaluations"]:
            verdict = item["verdict"]
            if verdict == "CLOSER_TO_TARGET":
                closer += 1
            elif verdict == "FARTHER_FROM_TARGET":
                farther += 1
            elif verdict == "IN_TARGET":
                in_target += 1
        blocking += int(evaluation["summary"]["blocking_regressions"])
        rows.append({
            "report": report_name,
            "comparison_identity": report.get("comparison_identity"),
            "design_target_evaluation": evaluation,
        })

    if blocking:
        overall = "DESIGN_REGRESSION"
    elif farther:
        overall = "MIXED_OR_NONBLOCKING_REGRESSION"
    elif closer or in_target:
        overall = "ALIGNED_OR_IMPROVING"
    else:
        overall = "INCONCLUSIVE"

    result = {
        "kind": "MEASUREMENT_BASELINE_COMPARISON",
        "status": "BASELINE_COMPARISON_COMPLETE",
        "overall_verdict": overall,
        "current_candidate_hash": current.get("candidate_hash"),
        "current_run_id": current.get("run_id"),
        "baseline_candidate_hash": baseline.get("candidate_hash"),
        "baseline_run_id": baseline.get("run_id"),
        "reports": rows,
        "summary": {
            "closer_to_target": closer,
            "farther_from_target": farther,
            "in_target": in_target,
            "blocking_regressions": blocking,
        },
        "core_write_allowed": False,
    }
    result["comparison_hash"] = _comparison_hash(result)
    return result


def _comparison_hash(payload: dict[str, Any]) -> str:
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(canonical.encode("utf-8")).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare a LITD measurement candidate to compatible history")
    parser.add_argument("--current", type=Path, required=True)
    parser.add_argument("--prior", nargs="*", type=Path, default=[])
    parser.add_argument("--targets", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    current = json.loads(args.current.read_text(encoding="utf-8"))
    registry = load_targets(args.targets)
    comparison = compare_candidate_to_baseline(current, load_candidates(args.prior), registry)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(comparison, sort_keys=True, indent=2), encoding="utf-8")
    print(json.dumps({
        "status": comparison["status"],
        "overall_verdict": comparison.get("overall_verdict"),
        "baseline_run_id": comparison.get("baseline_run_id"),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
