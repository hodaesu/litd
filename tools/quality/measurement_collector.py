#!/usr/bin/env python3
"""Collect real LITD QA/telemetry reports into provenance-ready measurement payloads."""
from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from hashlib import sha256
from pathlib import Path
from typing import Any


NUMERIC_HINTS = (
    "rate", "ratio", "average", "avg", "mean", "median", "p95", "p99",
    "duration", "round", "turn", "room", "expedition", "death", "retreat",
    "success", "failure", "error", "warning", "fps", "ms", "latency",
    "memory", "cpu", "loot", "damage", "healing", "balance", "score",
)


def _flatten_numeric(value: Any, prefix: str = "") -> dict[str, float]:
    metrics: dict[str, float] = {}
    if isinstance(value, bool):
        return metrics
    if isinstance(value, (int, float)):
        key = prefix or "value"
        lowered = key.casefold()
        if any(hint in lowered for hint in NUMERIC_HINTS):
            metrics[key] = float(value)
        return metrics
    if isinstance(value, dict):
        for key, child in value.items():
            child_prefix = f"{prefix}.{key}" if prefix else str(key)
            metrics.update(_flatten_numeric(child, child_prefix))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            child_prefix = f"{prefix}[{index}]" if prefix else f"[{index}]"
            metrics.update(_flatten_numeric(child, child_prefix))
    return metrics


def _alerts(payload: Any) -> dict[str, int]:
    counts = {"high": 0, "medium": 0, "low": 0, "other": 0}
    if not isinstance(payload, dict):
        return counts
    rows = payload.get("alerts", [])
    if not isinstance(rows, list):
        return counts
    for row in rows:
        severity = str(row.get("severity", "other")).casefold() if isinstance(row, dict) else "other"
        counts[severity if severity in counts else "other"] += 1
    return counts


def _file_hash(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def collect_report(path: str | Path) -> dict[str, Any]:
    report = Path(path)
    payload = json.loads(report.read_text(encoding="utf-8"))
    return {
        "report": report.name,
        "report_sha256": _file_hash(report),
        "metrics": _flatten_numeric(payload),
        "alerts": _alerts(payload),
    }


def build_measurement_candidate(report_paths: list[str | Path], *, env: dict[str, str] | None = None) -> dict[str, Any]:
    env = env or os.environ
    reports = [collect_report(path) for path in report_paths]
    commit_sha = env.get("GITHUB_SHA", "")
    run_id = env.get("GITHUB_RUN_ID", "")
    run_attempt = env.get("GITHUB_RUN_ATTEMPT", "")
    workflow = env.get("GITHUB_WORKFLOW", "")
    job = env.get("GITHUB_JOB", "")
    repository = env.get("GITHUB_REPOSITORY", "")
    missing = [name for name, value in {
        "GITHUB_SHA": commit_sha,
        "GITHUB_RUN_ID": run_id,
        "GITHUB_RUN_ATTEMPT": run_attempt,
        "GITHUB_WORKFLOW": workflow,
        "GITHUB_JOB": job,
        "GITHUB_REPOSITORY": repository,
    }.items() if not value]
    if missing:
        raise ValueError(f"missing_github_environment:{','.join(sorted(missing))}")

    high_alerts = sum(row["alerts"]["high"] for row in reports)
    medium_alerts = sum(row["alerts"]["medium"] for row in reports)
    metric_count = sum(len(row["metrics"]) for row in reports)
    candidate = {
        "kind": "MEASUREMENT_CANDIDATE",
        "repository": repository,
        "commit_sha": commit_sha,
        "run_id": run_id,
        "run_attempt": run_attempt,
        "workflow": workflow,
        "job": job,
        "recorded_at": datetime.now(timezone.utc).isoformat(),
        "summary": {
            "report_count": len(reports),
            "metric_count": metric_count,
            "high_alerts": high_alerts,
            "medium_alerts": medium_alerts,
            "eligible_for_promotion": high_alerts == 0,
        },
        "reports": reports,
        "promotion_rule": "requires_matching_CORE_DECISION_COMMIT_TEST_chain",
    }
    canonical = json.dumps(candidate, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    candidate["candidate_hash"] = sha256(canonical.encode("utf-8")).hexdigest()
    return candidate


def main() -> int:
    parser = argparse.ArgumentParser(description="Build provenance-ready LITD measurement candidate")
    parser.add_argument("reports", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    candidate = build_measurement_candidate(args.reports)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(candidate, sort_keys=True, indent=2), encoding="utf-8")
    print(json.dumps(candidate["summary"], sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
