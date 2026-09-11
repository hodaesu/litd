#!/usr/bin/env python3
"""Evaluate LITD measurements against explicit design targets.

This layer answers a different question than before/after comparison: not merely
whether a metric moved, but whether it moved toward or away from the intended
design window. It never writes to Core.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

TARGET_VERDICTS = {"IN_TARGET", "CLOSER_TO_TARGET", "FARTHER_FROM_TARGET", "UNCHANGED_DISTANCE", "INCONCLUSIVE"}


@dataclass(frozen=True)
class TargetEvaluation:
    metric: str
    baseline: float | None
    current: float | None
    baseline_distance: float | None
    current_distance: float | None
    verdict: str
    target: dict[str, Any]
    severity: str
    provisional: bool
    reason: str


def load_targets(path: str | Path) -> dict[str, Any]:
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    if payload.get("status") != "CANONICAL_DESIGN_TARGETS":
        raise ValueError("invalid_design_target_registry")
    if not isinstance(payload.get("targets"), dict):
        raise ValueError("missing_design_targets")
    return payload


def _distance(value: float, rule: dict[str, Any]) -> float:
    kind = rule.get("type")
    if kind == "window":
        low, high = float(rule["min"]), float(rule["max"])
        if low <= value <= high:
            return 0.0
        return low - value if value < low else value - high
    if kind == "max":
        maximum = float(rule["max"])
        return max(0.0, value - maximum)
    if kind == "min":
        minimum = float(rule["min"])
        return max(0.0, minimum - value)
    raise ValueError(f"invalid_target_type:{kind}")


def evaluate_metric_against_target(
    metric: str,
    *,
    baseline: float | int | None,
    current: float | int | None,
    rule: dict[str, Any],
    epsilon: float = 1e-9,
) -> TargetEvaluation:
    severity = str(rule.get("severity", "medium"))
    provisional = bool(rule.get("provisional", False))
    if current is None or isinstance(current, bool):
        return TargetEvaluation(metric, None if baseline is None else float(baseline), None, None, None, "INCONCLUSIVE", rule, severity, provisional, "missing_current_measurement")
    try:
        current_value = float(current)
        baseline_value = None if baseline is None else float(baseline)
    except (TypeError, ValueError):
        return TargetEvaluation(metric, None, None, None, None, "INCONCLUSIVE", rule, severity, provisional, "non_numeric_measurement")

    current_distance = _distance(current_value, rule)
    if current_distance <= epsilon:
        verdict = "IN_TARGET"
        reason = "current_measurement_inside_design_target"
        baseline_distance = None if baseline_value is None else _distance(baseline_value, rule)
    elif baseline_value is None:
        verdict = "INCONCLUSIVE"
        reason = "outside_target_without_compatible_baseline"
        baseline_distance = None
    else:
        baseline_distance = _distance(baseline_value, rule)
        improvement = baseline_distance - current_distance
        if improvement > epsilon:
            verdict = "CLOSER_TO_TARGET"
            reason = "distance_to_design_target_decreased"
        elif improvement < -epsilon:
            verdict = "FARTHER_FROM_TARGET"
            reason = "distance_to_design_target_increased"
        else:
            verdict = "UNCHANGED_DISTANCE"
            reason = "distance_to_design_target_unchanged"

    return TargetEvaluation(
        metric=metric,
        baseline=baseline_value,
        current=current_value,
        baseline_distance=baseline_distance,
        current_distance=current_distance,
        verdict=verdict,
        target=rule,
        severity=severity,
        provisional=provisional,
        reason=reason,
    )


def evaluate_design_targets(
    *,
    current: dict[str, float | int],
    baseline: dict[str, float | int] | None,
    registry: dict[str, Any],
) -> dict[str, Any]:
    baseline = baseline or {}
    evaluations: list[dict[str, Any]] = []
    blocking_regressions = 0
    in_target = 0
    closer = 0
    inconclusive = 0

    for metric, rule in registry["targets"].items():
        row = evaluate_metric_against_target(
            metric,
            baseline=baseline.get(metric),
            current=current.get(metric),
            rule=rule,
        )
        evaluations.append(row.__dict__)
        if row.verdict == "IN_TARGET":
            in_target += 1
        elif row.verdict == "CLOSER_TO_TARGET":
            closer += 1
        elif row.verdict == "INCONCLUSIVE":
            inconclusive += 1
        elif row.verdict == "FARTHER_FROM_TARGET" and row.severity == "high" and not row.provisional:
            blocking_regressions += 1

    if blocking_regressions:
        overall = "DESIGN_REGRESSION"
    elif in_target or closer:
        overall = "ALIGNED_OR_IMPROVING"
    else:
        overall = "INCONCLUSIVE"

    return {
        "status": "DESIGN_TARGET_EVALUATION",
        "overall_verdict": overall,
        "summary": {
            "targets": len(registry["targets"]),
            "in_target": in_target,
            "closer_to_target": closer,
            "inconclusive": inconclusive,
            "blocking_regressions": blocking_regressions,
        },
        "evaluations": evaluations,
        "core_write_allowed": False,
    }
