#!/usr/bin/env python3
"""Detect whether a proposed LITD design target becomes stricter or more permissive.

This module never approves a target revision and never writes to the Core. It
only classifies the direction of change so governance cannot silently lower its
own standards.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

STRICTER = "STRICTER"
EQUIVALENT = "EQUIVALENT"
MORE_PERMISSIVE = "MORE_PERMISSIVE"
MIXED = "MIXED"
UNSUPPORTED = "UNSUPPORTED"


def _num(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    return None


def classify_target_change(old: dict[str, Any], new: dict[str, Any]) -> str:
    old_type = old.get("type")
    new_type = new.get("type")
    if old_type != new_type:
        return UNSUPPORTED

    if old_type == "max":
        old_max, new_max = _num(old.get("max")), _num(new.get("max"))
        if old_max is None or new_max is None:
            return UNSUPPORTED
        if new_max < old_max:
            return STRICTER
        if new_max > old_max:
            return MORE_PERMISSIVE
        return EQUIVALENT

    if old_type == "min":
        old_min, new_min = _num(old.get("min")), _num(new.get("min"))
        if old_min is None or new_min is None:
            return UNSUPPORTED
        if new_min > old_min:
            return STRICTER
        if new_min < old_min:
            return MORE_PERMISSIVE
        return EQUIVALENT

    if old_type == "window":
        old_min, old_max = _num(old.get("min")), _num(old.get("max"))
        new_min, new_max = _num(new.get("min")), _num(new.get("max"))
        if None in {old_min, old_max, new_min, new_max}:
            return UNSUPPORTED
        lower_stricter = new_min > old_min
        lower_looser = new_min < old_min
        upper_stricter = new_max < old_max
        upper_looser = new_max > old_max
        if not any((lower_stricter, lower_looser, upper_stricter, upper_looser)):
            return EQUIVALENT
        if (lower_stricter or upper_stricter) and not (lower_looser or upper_looser):
            return STRICTER
        if (lower_looser or upper_looser) and not (lower_stricter or upper_stricter):
            return MORE_PERMISSIVE
        return MIXED

    return UNSUPPORTED


def evaluate_revision_proposal(payload: dict[str, Any]) -> dict[str, Any]:
    old_values = payload.get("old_values", {})
    new_values = payload.get("new_values", {})
    target_ids = payload.get("target_ids", [])

    results: list[dict[str, Any]] = []
    permissive: list[str] = []
    mixed: list[str] = []
    unsupported: list[str] = []

    for target_id in target_ids if isinstance(target_ids, list) else []:
        old = old_values.get(target_id) if isinstance(old_values, dict) else None
        new = new_values.get(target_id) if isinstance(new_values, dict) else None
        if not isinstance(old, dict) or not isinstance(new, dict):
            direction = UNSUPPORTED
        else:
            direction = classify_target_change(old, new)
        results.append({"target_id": target_id, "direction": direction, "old": old, "new": new})
        if direction == MORE_PERMISSIVE:
            permissive.append(target_id)
        elif direction == MIXED:
            mixed.append(target_id)
        elif direction == UNSUPPORTED:
            unsupported.append(target_id)

    requires_explicit_justification = bool(permissive or mixed)
    justification = payload.get("permissiveness_justification")
    evidence = payload.get("permissiveness_evidence_refs")
    justification_ok = isinstance(justification, str) and len(justification.strip()) >= 80
    evidence_ok = isinstance(evidence, list) and len(evidence) >= 2 and all(isinstance(x, str) and x.strip() for x in evidence)

    reasons: list[str] = []
    if permissive:
        reasons.append("target_standard_becomes_more_permissive")
    if mixed:
        reasons.append("target_standard_change_is_mixed")
    if unsupported:
        reasons.append("target_standard_change_unsupported")
    if requires_explicit_justification and not justification_ok:
        reasons.append("permissiveness_justification_required")
    if requires_explicit_justification and not evidence_ok:
        reasons.append("at_least_two_permissiveness_evidence_refs_required")

    blocking = bool(unsupported) or (requires_explicit_justification and (not justification_ok or not evidence_ok))
    return {
        "kind": "LITD_TARGET_DRIFT_ANALYSIS",
        "status": "BLOCK" if blocking else "PASS",
        "results": results,
        "more_permissive_targets": permissive,
        "mixed_targets": mixed,
        "unsupported_targets": unsupported,
        "requires_explicit_justification": requires_explicit_justification,
        "reasons": reasons,
        "core_write_allowed": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Detect permissive drift in LITD target revisions")
    parser.add_argument("proposal", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    payload = json.loads(args.proposal.read_text(encoding="utf-8"))
    result = evaluate_revision_proposal(payload)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, sort_keys=True, indent=2), encoding="utf-8")
    print(json.dumps({"status": result["status"], "reasons": result["reasons"]}, sort_keys=True))
    return 1 if result["status"] == "BLOCK" else 0


if __name__ == "__main__":
    raise SystemExit(main())
