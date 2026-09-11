#!/usr/bin/env python3
"""Validate and summarize the longitudinal history of LITD design targets.

History entries are committed governance records. They form a hash chain and
never authorize direct Core writes. The first snapshot is the reference point;
subsequent snapshots must point to the previous snapshot hash.
"""
from __future__ import annotations

import argparse
import json
from hashlib import sha256
from pathlib import Path
from typing import Any

from tools.quality.target_drift_budget import relaxation_ratio

KIND = "LITD_TARGET_HISTORY_SNAPSHOT"
HEX64 = set("0123456789abcdef")


def canonical_hash(payload: Any) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def registry_hash(registry: dict[str, Any]) -> str:
    return canonical_hash(registry)


def snapshot_body(snapshot: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in snapshot.items() if k != "snapshot_hash"}


def compute_snapshot_hash(snapshot: dict[str, Any]) -> str:
    return canonical_hash(snapshot_body(snapshot))


def validate_snapshot(snapshot: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if snapshot.get("kind") != KIND:
        errors.append("invalid_kind")
    if not isinstance(snapshot.get("sequence"), int) or snapshot.get("sequence", 0) < 1:
        errors.append("invalid_sequence")
    targets = snapshot.get("targets")
    if not isinstance(targets, dict) or not targets:
        errors.append("targets_required")
    if snapshot.get("core_write_allowed") is not False:
        errors.append("direct_core_write_forbidden")
    for field in ("registry_hash", "snapshot_hash"):
        value = snapshot.get(field)
        if not isinstance(value, str) or len(value) != 64 or any(c not in HEX64 for c in value):
            errors.append(f"invalid_{field}")
    previous = snapshot.get("previous_snapshot_hash")
    if previous is not None and (not isinstance(previous, str) or len(previous) != 64 or any(c not in HEX64 for c in previous)):
        errors.append("invalid_previous_snapshot_hash")
    if isinstance(snapshot.get("snapshot_hash"), str) and snapshot.get("snapshot_hash") != compute_snapshot_hash(snapshot):
        errors.append("snapshot_hash_mismatch")
    return errors


def validate_chain(snapshots: list[dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    if not snapshots:
        return ["history_empty"]
    ordered = sorted(snapshots, key=lambda row: row.get("sequence", 0))
    seen_hashes: set[str] = set()
    for index, snapshot in enumerate(ordered):
        for error in validate_snapshot(snapshot):
            errors.append(f"seq_{snapshot.get('sequence')}:{error}")
        expected_sequence = index + 1
        if snapshot.get("sequence") != expected_sequence:
            errors.append(f"seq_{snapshot.get('sequence')}:sequence_gap")
        current_hash = snapshot.get("snapshot_hash")
        if current_hash in seen_hashes:
            errors.append(f"seq_{snapshot.get('sequence')}:duplicate_snapshot_hash")
        if isinstance(current_hash, str):
            seen_hashes.add(current_hash)
        expected_previous = None if index == 0 else ordered[index - 1].get("snapshot_hash")
        if snapshot.get("previous_snapshot_hash") != expected_previous:
            errors.append(f"seq_{snapshot.get('sequence')}:previous_hash_mismatch")
    return errors


def build_trend_report(snapshots: list[dict[str, Any]]) -> dict[str, Any]:
    errors = validate_chain(snapshots)
    if errors:
        return {
            "kind": "LITD_TARGET_TRAJECTORY_REPORT",
            "status": "INVALID_HISTORY",
            "errors": errors,
            "core_write_allowed": False,
        }

    ordered = sorted(snapshots, key=lambda row: row["sequence"])
    first = ordered[0]
    last = ordered[-1]
    target_ids = sorted(set().union(*(row["targets"].keys() for row in ordered)))
    rows: list[dict[str, Any]] = []
    permissive = stricter = changed = 0

    for target_id in target_ids:
        baseline = first["targets"].get(target_id)
        current = last["targets"].get(target_id)
        if not isinstance(baseline, dict) or not isinstance(current, dict):
            status = "TARGET_SET_CHANGED"
            ratio = None
        else:
            drift = relaxation_ratio(baseline, current)
            status = drift["status"]
            ratio = drift["ratio"]
        revisions = 0
        prior = None
        for snap in ordered:
            value = snap["targets"].get(target_id)
            if prior is not None and value != prior:
                revisions += 1
            prior = value
        if revisions:
            changed += 1
        if status == "MORE_PERMISSIVE":
            permissive += 1
        elif status == "STRICTER":
            stricter += 1
        rows.append({
            "target_id": target_id,
            "status": status,
            "cumulative_relaxation_ratio": ratio,
            "revision_count": revisions,
            "first_sequence": first["sequence"],
            "last_sequence": last["sequence"],
        })

    result = {
        "kind": "LITD_TARGET_TRAJECTORY_REPORT",
        "status": "OK",
        "snapshot_count": len(ordered),
        "first_snapshot_hash": first["snapshot_hash"],
        "latest_snapshot_hash": last["snapshot_hash"],
        "targets": rows,
        "summary": {
            "target_count": len(rows),
            "changed_target_count": changed,
            "more_permissive_count": permissive,
            "stricter_count": stricter,
        },
        "core_write_allowed": False,
    }
    result["report_hash"] = canonical_hash(result)
    return result


def snapshot_from_registry(registry: dict[str, Any], *, sequence: int, previous_snapshot_hash: str | None, recorded_at: str, source_ref: str, evidence_refs: list[str]) -> dict[str, Any]:
    snapshot = {
        "kind": KIND,
        "sequence": sequence,
        "recorded_at": recorded_at,
        "source_ref": source_ref,
        "registry_hash": registry_hash(registry),
        "previous_snapshot_hash": previous_snapshot_hash,
        "evidence_refs": evidence_refs,
        "targets": registry.get("targets", {}),
        "core_write_allowed": False,
    }
    snapshot["snapshot_hash"] = compute_snapshot_hash(snapshot)
    return snapshot


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate LITD target history and render trajectory report")
    parser.add_argument("snapshots", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    snapshots = [json.loads(path.read_text(encoding="utf-8")) for path in args.snapshots]
    report = build_trend_report(snapshots)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, sort_keys=True, indent=2), encoding="utf-8")
    print(json.dumps({"status": report["status"], **report.get("summary", {})}, sort_keys=True))
    return 1 if report["status"] != "OK" else 0


if __name__ == "__main__":
    raise SystemExit(main())
