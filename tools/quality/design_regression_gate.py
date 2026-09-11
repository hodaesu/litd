#!/usr/bin/env python3
"""Fail CI only on proven high-severity, non-provisional LITD design regressions.

The gate consumes immutable comparison artifacts produced by baseline_comparison.
It never mutates Core. Missing/inconclusive comparisons do not fabricate a failure.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def blocking_regressions(comparison: dict[str, Any]) -> list[dict[str, Any]]:
    evaluation = comparison.get("design_target_evaluation")
    if not isinstance(evaluation, dict):
        return []
    rows = evaluation.get("evaluations", [])
    if not isinstance(rows, list):
        return []
    blocked: list[dict[str, Any]] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        if (
            row.get("verdict") == "FARTHER_FROM_TARGET"
            and row.get("severity") == "high"
            and row.get("provisional") is not True
        ):
            blocked.append(row)
    return blocked


def evaluate_gate(comparisons: list[dict[str, Any]]) -> dict[str, Any]:
    failures: list[dict[str, Any]] = []
    for comparison in comparisons:
        rows = blocking_regressions(comparison)
        if rows:
            failures.append({
                "current_run_id": comparison.get("current_run_id"),
                "baseline_run_id": comparison.get("baseline_run_id"),
                "comparison_hash": comparison.get("comparison_hash"),
                "regressions": rows,
            })
    return {
        "status": "DESIGN_REGRESSION_GATE",
        "blocked": bool(failures),
        "failure_count": len(failures),
        "failures": failures,
        "core_write_allowed": False,
    }


def load_comparisons(paths: list[str | Path]) -> list[dict[str, Any]]:
    payloads: list[dict[str, Any]] = []
    for path in paths:
        payload = json.loads(Path(path).read_text(encoding="utf-8"))
        if not isinstance(payload, dict):
            raise ValueError(f"comparison_must_be_object:{path}")
        payloads.append(payload)
    return payloads


def main() -> int:
    parser = argparse.ArgumentParser(description="Block CI on proven high-severity LITD design regressions")
    parser.add_argument("comparisons", nargs="+", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = evaluate_gate(load_comparisons(args.comparisons))
    rendered = json.dumps(result, sort_keys=True, indent=2, ensure_ascii=False)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 1 if result["blocked"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
