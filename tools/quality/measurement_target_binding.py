#!/usr/bin/env python3
"""Bind telemetry measurements to the target snapshot effective at measurement time.

The binding is fail-closed: invalid/naive timestamps, duplicate snapshot effective
instants, measurements before the first snapshot, or any temporal ambiguity remain
unbound and therefore cannot support a goalpost decision. This module never writes
to Core or changes targets.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
from hashlib import sha256
from pathlib import Path
from typing import Any

KIND = "LITD_MEASUREMENT_TARGET_BINDING"


def _hash(payload: Any) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def _parse_aware(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if dt.tzinfo is None or dt.utcoffset() is None:
        return None
    return dt


def build_binding(snapshots: list[dict[str, Any]], history: dict[str, Any]) -> dict[str, Any]:
    ordered = sorted(snapshots, key=lambda row: row.get("sequence", 0))
    timeline: list[tuple[datetime, dict[str, Any]]] = []
    errors: list[str] = []
    seen_times: set[str] = set()

    for snapshot in ordered:
        dt = _parse_aware(snapshot.get("recorded_at"))
        if dt is None:
            errors.append(f"snapshot_{snapshot.get('sequence')}:invalid_or_naive_recorded_at")
            continue
        key = dt.isoformat()
        if key in seen_times:
            errors.append(f"snapshot_{snapshot.get('sequence')}:ambiguous_effective_time")
            continue
        seen_times.add(key)
        timeline.append((dt, snapshot))

    timeline.sort(key=lambda item: item[0])
    if len(timeline) != len(ordered):
        status = "INVALID_TARGET_TIMELINE"
    else:
        status = "OK"

    bindings: list[dict[str, Any]] = []
    bound = unbound = 0
    for group in history.get("groups", []):
        if not isinstance(group, dict):
            continue
        identity = group.get("comparison_identity") if isinstance(group.get("comparison_identity"), dict) else None
        for measurement in group.get("measurements", []):
            if not isinstance(measurement, dict):
                continue
            recorded = _parse_aware(measurement.get("recorded_at"))
            base = {
                "candidate_hash": measurement.get("candidate_hash"),
                "run_id": measurement.get("run_id"),
                "report": measurement.get("report"),
                "recorded_at": measurement.get("recorded_at"),
                "comparison_identity": identity,
                "canonical_metrics": measurement.get("canonical_metrics", {}),
            }
            if status != "OK":
                base.update({"binding_status": "UNBOUND", "reason": "invalid_target_timeline"})
                unbound += 1
                bindings.append(base)
                continue
            if recorded is None:
                base.update({"binding_status": "UNBOUND", "reason": "invalid_or_naive_measurement_time"})
                unbound += 1
                bindings.append(base)
                continue
            eligible = [(dt, snap) for dt, snap in timeline if dt <= recorded]
            if not eligible:
                base.update({"binding_status": "UNBOUND", "reason": "measurement_precedes_first_target_snapshot"})
                unbound += 1
                bindings.append(base)
                continue
            effective_dt, snapshot = eligible[-1]
            base.update({
                "binding_status": "BOUND",
                "target_sequence": snapshot.get("sequence"),
                "target_snapshot_hash": snapshot.get("snapshot_hash"),
                "target_registry_hash": snapshot.get("registry_hash"),
                "target_effective_from": effective_dt.isoformat(),
            })
            bound += 1
            bindings.append(base)

    result = {
        "kind": KIND,
        "status": status,
        "target_snapshot_count": len(ordered),
        "bound_measurement_count": bound,
        "unbound_measurement_count": unbound,
        "errors": errors,
        "bindings": bindings,
        "core_write_allowed": False,
        "automatic_target_change_allowed": False,
        "authority": "temporal_binding_evidence_only",
    }
    result["binding_hash"] = _hash(result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Bind LITD measurements to effective target snapshots")
    parser.add_argument("--snapshots", nargs="+", type=Path, required=True)
    parser.add_argument("--measurement-history", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    snapshots = [json.loads(path.read_text(encoding="utf-8")) for path in args.snapshots]
    history = json.loads(args.measurement_history.read_text(encoding="utf-8"))
    result = build_binding(snapshots, history)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2), encoding="utf-8")
    print(json.dumps({"status": result["status"], "bound": result["bound_measurement_count"], "unbound": result["unbound_measurement_count"]}, sort_keys=True))
    return 1 if result["status"] != "OK" else 0


if __name__ == "__main__":
    raise SystemExit(main())
