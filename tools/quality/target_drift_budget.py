#!/usr/bin/env python3
"""Longitudinal drift analysis for LITD canonical design targets.

The module compares a current target registry against a frozen canonical
baseline and optional approved per-target drift budgets. It never authorizes a
Core write. Missing/unapproved budgets produce REVIEW_REQUIRED rather than an
invented tolerance.
"""
from __future__ import annotations

import argparse
import json
from hashlib import sha256
from pathlib import Path
from typing import Any

SUPPORTED_TYPES = {"max", "min", "window"}
APPROVED = "APPROVED"


def _canonical_hash(payload: Any) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def _number(value: Any) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def relaxation_ratio(baseline: dict[str, Any], current: dict[str, Any]) -> dict[str, Any]:
    """Return normalized cumulative relaxation from baseline to current.

    Ratio 0 means no relaxation. Positive values mean more permissive.
    Negative values mean stricter. Window targets measure total outward
    expansion relative to the original window width; inward movement subtracts
    from the score so tightening can offset earlier relaxation.
    """
    kind = baseline.get("type")
    if kind != current.get("type") or kind not in SUPPORTED_TYPES:
        return {"status": "UNSUPPORTED", "ratio": None, "reason": "type_changed_or_unsupported"}

    if kind == "max":
        old = _number(baseline.get("max")); new = _number(current.get("max"))
        if old is None or new is None or old == 0:
            return {"status": "UNSUPPORTED", "ratio": None, "reason": "invalid_max_baseline"}
        ratio = (new - old) / abs(old)
    elif kind == "min":
        old = _number(baseline.get("min")); new = _number(current.get("min"))
        if old is None or new is None or old == 0:
            return {"status": "UNSUPPORTED", "ratio": None, "reason": "invalid_min_baseline"}
        ratio = (old - new) / abs(old)
    else:
        old_min = _number(baseline.get("min")); old_max = _number(baseline.get("max"))
        new_min = _number(current.get("min")); new_max = _number(current.get("max"))
        if None in {old_min, old_max, new_min, new_max}:
            return {"status": "UNSUPPORTED", "ratio": None, "reason": "invalid_window"}
        width = old_max - old_min
        if width <= 0:
            return {"status": "UNSUPPORTED", "ratio": None, "reason": "invalid_baseline_window"}
        lower_relax = old_min - new_min
        upper_relax = new_max - old_max
        ratio = (lower_relax + upper_relax) / width

    if abs(ratio) < 1e-12:
        label = "EQUIVALENT"
    elif ratio > 0:
        label = "MORE_PERMISSIVE"
    else:
        label = "STRICTER"
    return {"status": label, "ratio": ratio, "reason": None}


def _budget_for(target_id: str, budgets: dict[str, Any]) -> dict[str, Any] | None:
    row = budgets.get("targets", {}).get(target_id)
    if not isinstance(row, dict) or row.get("status") != APPROVED:
        return None
    value = _number(row.get("max_cumulative_relaxation_ratio"))
    if value is None or value < 0:
        return None
    return {**row, "max_cumulative_relaxation_ratio": value}


def evaluate_drift_budget(
    baseline_registry: dict[str, Any],
    current_registry: dict[str, Any],
    budgets: dict[str, Any],
) -> dict[str, Any]:
    baseline_targets = baseline_registry.get("targets", {})
    current_targets = current_registry.get("targets", {})
    rows: list[dict[str, Any]] = []
    blocking: list[str] = []
    review: list[str] = []

    for target_id in sorted(set(baseline_targets) | set(current_targets)):
        baseline = baseline_targets.get(target_id)
        current = current_targets.get(target_id)
        if not isinstance(baseline, dict) or not isinstance(current, dict):
            rows.append({"target_id": target_id, "status": "TARGET_SET_CHANGED", "ratio": None, "budget": None})
            review.append(target_id)
            continue
        drift = relaxation_ratio(baseline, current)
        budget = _budget_for(target_id, budgets)
        status = drift["status"]
        budget_value = None if budget is None else budget["max_cumulative_relaxation_ratio"]
        exceeded = False
        if status == "MORE_PERMISSIVE":
            if budget is None:
                review.append(target_id)
            elif drift["ratio"] is not None and drift["ratio"] > budget_value + 1e-12:
                exceeded = True
                blocking.append(target_id)
        elif status == "UNSUPPORTED":
            review.append(target_id)

        rows.append({
            "target_id": target_id,
            "severity": current.get("severity", baseline.get("severity")),
            "provisional": bool(current.get("provisional", baseline.get("provisional", False))),
            "status": status,
            "cumulative_relaxation_ratio": drift["ratio"],
            "budget": budget_value,
            "budget_status": None if budget is None else budget.get("status"),
            "budget_exceeded": exceeded,
            "reason": drift["reason"],
        })

    if blocking:
        overall = "DRIFT_BUDGET_EXCEEDED"
    elif review:
        overall = "REVIEW_REQUIRED"
    elif any(row.get("status") == "MORE_PERMISSIVE" for row in rows):
        overall = "WITHIN_APPROVED_BUDGET"
    else:
        overall = "NO_PERMISSIVE_DRIFT"

    result = {
        "kind": "LITD_LONGITUDINAL_TARGET_DRIFT",
        "status": overall,
        "baseline_hash": _canonical_hash(baseline_registry),
        "current_hash": _canonical_hash(current_registry),
        "budget_registry_hash": _canonical_hash(budgets),
        "targets": rows,
        "summary": {
            "target_count": len(rows),
            "blocking_count": len(blocking),
            "review_required_count": len(review),
            "blocking_targets": blocking,
            "review_targets": review,
        },
        "core_write_allowed": False,
    }
    result["analysis_hash"] = _canonical_hash(result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate cumulative LITD target drift against approved budgets")
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--current", type=Path, required=True)
    parser.add_argument("--budgets", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
    current = json.loads(args.current.read_text(encoding="utf-8"))
    budgets = json.loads(args.budgets.read_text(encoding="utf-8"))
    result = evaluate_drift_budget(baseline, current, budgets)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2), encoding="utf-8")
    print(json.dumps({"status": result["status"], **result["summary"]}, sort_keys=True))
    return 1 if result["status"] == "DRIFT_BUDGET_EXCEEDED" else 0


if __name__ == "__main__":
    raise SystemExit(main())
