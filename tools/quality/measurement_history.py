#!/usr/bin/env python3
"""Build a deterministic, compatibility-safe LITD measurement history.

Measurement candidates may contain different telemetry models/scenarios. This
module flattens them into report-level rows, deduplicates by candidate/report
identity, groups by comparison identity, and orders chronologically. It never
changes targets or Core state.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from hashlib import sha256
from pathlib import Path
from typing import Any

KIND = "LITD_MEASUREMENT_HISTORY"


def _hash(payload: Any) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def _identity_key(identity: dict[str, Any]) -> str:
    return json.dumps(identity or {}, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _time_key(value: Any) -> tuple[int, str]:
    if not isinstance(value, str) or not value:
        return (1, "")
    try:
        return (0, datetime.fromisoformat(value.replace("Z", "+00:00")).isoformat())
    except ValueError:
        return (1, value)


def build_history(candidates: list[dict[str, Any]]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    seen: set[tuple[str, str, str]] = set()
    rejected = 0

    for candidate in candidates:
        if candidate.get("kind") != "MEASUREMENT_CANDIDATE":
            rejected += 1
            continue
        candidate_hash = str(candidate.get("candidate_hash", ""))
        run_id = str(candidate.get("run_id", ""))
        recorded_at = candidate.get("recorded_at")
        for report in candidate.get("reports", []):
            if not isinstance(report, dict):
                continue
            identity = report.get("comparison_identity")
            metrics = report.get("canonical_metrics")
            if not isinstance(identity, dict) or not isinstance(metrics, dict):
                continue
            report_name = str(report.get("report", ""))
            key = (candidate_hash, report_name, _identity_key(identity))
            if key in seen:
                continue
            seen.add(key)
            rows.append({
                "candidate_hash": candidate_hash,
                "run_id": run_id,
                "recorded_at": recorded_at,
                "report": report_name,
                "comparison_identity": identity,
                "canonical_metrics": metrics,
            })

    rows.sort(key=lambda row: (_time_key(row.get("recorded_at")), row.get("run_id", ""), row.get("report", "")))

    groups: dict[str, dict[str, Any]] = {}
    for row in rows:
        key = _identity_key(row["comparison_identity"])
        bucket = groups.setdefault(key, {"comparison_identity": row["comparison_identity"], "measurements": []})
        bucket["measurements"].append(row)

    ordered_groups = sorted(groups.values(), key=lambda group: _identity_key(group["comparison_identity"]))
    result = {
        "kind": KIND,
        "status": "OK" if rows else "EMPTY",
        "candidate_count": len(candidates),
        "accepted_measurement_count": len(rows),
        "rejected_candidate_count": rejected,
        "group_count": len(ordered_groups),
        "groups": ordered_groups,
        "core_write_allowed": False,
        "automatic_target_change_allowed": False,
    }
    result["history_hash"] = _hash(result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Build compatibility-safe LITD measurement history")
    parser.add_argument("candidates", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    payloads = [json.loads(path.read_text(encoding="utf-8")) for path in args.candidates]
    result = build_history(payloads)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2), encoding="utf-8")
    print(json.dumps({"status": result["status"], "accepted_measurement_count": result["accepted_measurement_count"], "group_count": result["group_count"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
