#!/usr/bin/env python3
"""Select the newest compatible prior LITD measurement as comparison baseline.

Compatibility is intentionally strict. A baseline must describe the same metric
family, scenario, model version and seed policy. For fixed-seed simulations the
seed value must also match so before/after comparisons remain reproducible.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable


IDENTITY_KEYS = ("metric_family", "scenario", "model_version", "seed_policy")


def comparison_identity(payload: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise ValueError("telemetry_payload_must_be_object")
    scenario = payload.get("dungeon_id") or payload.get("scenario")
    model_version = payload.get("model_version", payload.get("schema_version"))
    seed = payload.get("seed")
    seed_policy = "fixed" if isinstance(seed, int) and not isinstance(seed, bool) else "unspecified"
    return {
        "metric_family": "litd_balance_telemetry",
        "scenario": scenario,
        "model_version": model_version,
        "seed_policy": seed_policy,
        "seed_value": seed if seed_policy == "fixed" else None,
    }


def identities_compatible(current: dict[str, Any], prior: dict[str, Any]) -> bool:
    if not all(current.get(key) == prior.get(key) for key in IDENTITY_KEYS):
        return False
    if current.get("seed_policy") == "fixed":
        return current.get("seed_value") == prior.get("seed_value")
    return True


def _recorded_at(candidate: dict[str, Any]) -> datetime:
    value = candidate.get("recorded_at")
    if not isinstance(value, str) or not value:
        return datetime.min
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).replace(tzinfo=None)
    except ValueError:
        return datetime.min


def _candidate_identities(candidate: dict[str, Any]) -> list[dict[str, Any]]:
    reports = candidate.get("reports", [])
    if not isinstance(reports, list):
        return []
    identities: list[dict[str, Any]] = []
    for report in reports:
        if isinstance(report, dict) and isinstance(report.get("comparison_identity"), dict):
            identities.append(report["comparison_identity"])
    return identities


def candidate_is_compatible(current: dict[str, Any], prior: dict[str, Any]) -> bool:
    current_ids = _candidate_identities(current)
    prior_ids = _candidate_identities(prior)
    if not current_ids or not prior_ids:
        return False
    # A candidate produced from multiple reports is compatible only if every
    # current report has a matching prior identity. We never compare unlike reports.
    return all(any(identities_compatible(cur, old) for old in prior_ids) for cur in current_ids)


def select_latest_compatible_baseline(
    current: dict[str, Any],
    prior_candidates: Iterable[dict[str, Any]],
) -> dict[str, Any] | None:
    compatible = [
        candidate for candidate in prior_candidates
        if isinstance(candidate, dict)
        and candidate.get("kind") == "MEASUREMENT_CANDIDATE"
        and candidate.get("candidate_hash") != current.get("candidate_hash")
        and candidate_is_compatible(current, candidate)
    ]
    if not compatible:
        return None
    compatible.sort(key=_recorded_at, reverse=True)
    return compatible[0]


def canonical_baseline_by_report(
    current: dict[str, Any], baseline: dict[str, Any] | None,
) -> dict[str, dict[str, float]]:
    if baseline is None:
        return {}
    result: dict[str, dict[str, float]] = {}
    baseline_reports = baseline.get("reports", [])
    if not isinstance(baseline_reports, list):
        return result
    for current_report in current.get("reports", []):
        if not isinstance(current_report, dict):
            continue
        current_identity = current_report.get("comparison_identity")
        if not isinstance(current_identity, dict):
            continue
        for old in baseline_reports:
            if not isinstance(old, dict) or not isinstance(old.get("comparison_identity"), dict):
                continue
            if identities_compatible(current_identity, old["comparison_identity"]):
                metrics = old.get("canonical_metrics", {})
                if isinstance(metrics, dict):
                    result[str(current_report.get("report", "<unknown>"))] = {
                        key: float(value) for key, value in metrics.items()
                        if isinstance(value, (int, float)) and not isinstance(value, bool)
                    }
                break
    return result


def load_candidates(paths: Iterable[str | Path]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for path in paths:
        payload = json.loads(Path(path).read_text(encoding="utf-8"))
        if isinstance(payload, dict):
            result.append(payload)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Select latest compatible LITD telemetry baseline")
    parser.add_argument("--current", type=Path, required=True)
    parser.add_argument("--prior", nargs="*", type=Path, default=[])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    current = json.loads(args.current.read_text(encoding="utf-8"))
    baseline = select_latest_compatible_baseline(current, load_candidates(args.prior))
    payload = {
        "status": "BASELINE_SELECTED" if baseline else "NO_COMPATIBLE_BASELINE",
        "baseline_candidate_hash": baseline.get("candidate_hash") if baseline else None,
        "baseline_run_id": baseline.get("run_id") if baseline else None,
        "canonical_baseline_by_report": canonical_baseline_by_report(current, baseline),
        "core_write_allowed": False,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, sort_keys=True, indent=2), encoding="utf-8")
    print(json.dumps({"status": payload["status"], "baseline_run_id": payload["baseline_run_id"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
