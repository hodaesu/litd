#!/usr/bin/env python3
"""Compare compatible LITD measurement candidates against a baseline.

Produces conservative verdicts: IMPROVED, REGRESSED, NO_SIGNIFICANT_CHANGE,
or INCONCLUSIVE. It never promotes a measurement into Core by itself.
"""
from __future__ import annotations

from dataclasses import dataclass
from math import sqrt
from typing import Any

VERDICTS = {"IMPROVED", "REGRESSED", "NO_SIGNIFICANT_CHANGE", "INCONCLUSIVE"}


@dataclass(frozen=True)
class MetricComparison:
    metric: str
    baseline: float
    current: float
    delta: float
    relative_delta: float | None
    verdict: str
    reason: str


def _compatible(a: dict[str, Any], b: dict[str, Any]) -> bool:
    keys = ("metric_family", "model_version", "scenario", "seed_policy")
    return all(a.get(key) == b.get(key) for key in keys)


def _stderr(entry: dict[str, Any]) -> float | None:
    n = entry.get("samples")
    sd = entry.get("stddev")
    if isinstance(n, (int, float)) and isinstance(sd, (int, float)) and n and n > 1 and sd >= 0:
        return float(sd) / sqrt(float(n))
    return None


def compare_metric(
    *,
    metric: str,
    baseline: dict[str, Any],
    current: dict[str, Any],
    direction: str,
    practical_threshold: float = 0.0,
    z_threshold: float = 1.96,
) -> MetricComparison:
    if direction not in {"higher_is_better", "lower_is_better", "target_neutral"}:
        raise ValueError("invalid_metric_direction")
    if not _compatible(baseline, current):
        return MetricComparison(metric, 0.0, 0.0, 0.0, None, "INCONCLUSIVE", "incompatible_baseline")

    try:
        before = float(baseline["value"])
        after = float(current["value"])
    except (KeyError, TypeError, ValueError):
        return MetricComparison(metric, 0.0, 0.0, 0.0, None, "INCONCLUSIVE", "missing_numeric_value")

    delta = after - before
    relative = None if before == 0 else delta / abs(before)
    if abs(delta) <= practical_threshold:
        return MetricComparison(metric, before, after, delta, relative, "NO_SIGNIFICANT_CHANGE", "below_practical_threshold")

    se_before = _stderr(baseline)
    se_after = _stderr(current)
    if se_before is not None and se_after is not None:
        combined = sqrt(se_before**2 + se_after**2)
        if combined > 0 and abs(delta) < z_threshold * combined:
            return MetricComparison(metric, before, after, delta, relative, "NO_SIGNIFICANT_CHANGE", "within_sampling_uncertainty")

    if direction == "target_neutral":
        return MetricComparison(metric, before, after, delta, relative, "INCONCLUSIVE", "neutral_metric_requires_target_window")

    improved = delta > 0 if direction == "higher_is_better" else delta < 0
    verdict = "IMPROVED" if improved else "REGRESSED"
    return MetricComparison(metric, before, after, delta, relative, verdict, "directional_change_beyond_threshold")


def compare_measurement_sets(
    baseline: dict[str, dict[str, Any]],
    current: dict[str, dict[str, Any]],
    policy: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    results: list[dict[str, Any]] = []
    verdicts: list[str] = []
    for metric, rules in policy.items():
        if metric not in baseline or metric not in current:
            row = MetricComparison(metric, 0.0, 0.0, 0.0, None, "INCONCLUSIVE", "metric_missing_from_baseline_or_current")
        else:
            row = compare_metric(
                metric=metric,
                baseline=baseline[metric],
                current=current[metric],
                direction=rules.get("direction", "target_neutral"),
                practical_threshold=float(rules.get("practical_threshold", 0.0)),
                z_threshold=float(rules.get("z_threshold", 1.96)),
            )
        results.append(row.__dict__)
        verdicts.append(row.verdict)

    if "REGRESSED" in verdicts:
        overall = "REGRESSED"
    elif "INCONCLUSIVE" in verdicts:
        overall = "INCONCLUSIVE"
    elif "IMPROVED" in verdicts:
        overall = "IMPROVED"
    else:
        overall = "NO_SIGNIFICANT_CHANGE"
    return {
        "status": "MEASUREMENT_COMPARISON",
        "overall_verdict": overall,
        "metrics": results,
        "core_write_allowed": False,
    }
