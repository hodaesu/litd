#!/usr/bin/env python3
"""Plan and apply fail-closed LITD governance registry transitions.

The command is dry-run by default.  ``--apply`` is required to write registry
files, and every proposed state is validated before either file is replaced.
It never edits the LITD Core or gameplay data.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
import json
import os
from pathlib import Path
import tempfile
from typing import Any

from tools.quality.global_governance import CHANGE_ORDER, REGISTRY_ROOT, SCHEMA_ROOT, validate


class TransitionError(ValueError):
    """Raised when a proposed registry transition must fail closed."""


def _load_payload(root: Path, name: str) -> dict[str, Any]:
    path = root / name
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise TransitionError(f"cannot_load:{name}:{exc}") from exc
    if payload.get("schema_version") != 1 or not isinstance(payload.get("entries"), list):
        raise TransitionError(f"invalid_registry_envelope:{name}")
    return payload


def _canonical(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _validate_evidence(evidence: dict[str, Any], change_id: str) -> None:
    required = {"id", "type", "result", "uri", "observed_at", "change_id"}
    missing = sorted(required - evidence.keys())
    if missing:
        raise TransitionError(f"evidence_missing_fields:{','.join(missing)}")
    if evidence["change_id"] != change_id:
        raise TransitionError("evidence_points_to_other_change")
    if evidence["result"] != "PASS":
        raise TransitionError("transition_requires_passing_evidence")
    if not all(isinstance(evidence[field], str) and evidence[field].strip() for field in required):
        raise TransitionError("evidence_fields_must_be_non_empty_strings")


def plan_transition(
    root: Path,
    *,
    change_id: str,
    target_status: str,
    evidence: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    """Return validated replacement payloads without writing to disk."""
    if target_status not in CHANGE_ORDER:
        raise TransitionError(f"unknown_target_status:{target_status}")

    changes = deepcopy(_load_payload(root, "change_registry.json"))
    proofs = deepcopy(_load_payload(root, "evidence_registry.json"))
    matches = [entry for entry in changes["entries"] if entry.get("id") == change_id]
    if len(matches) != 1:
        raise TransitionError(f"change_not_unique:{change_id}")
    change = matches[0]
    current = change.get("status")
    if current not in CHANGE_ORDER:
        raise TransitionError(f"invalid_current_status:{current}")

    _validate_evidence(evidence, change_id)
    existing = [entry for entry in proofs["entries"] if entry.get("id") == evidence["id"]]
    if existing and _canonical(existing[0]) != _canonical(evidence):
        raise TransitionError(f"evidence_id_conflict:{evidence['id']}")
    if len(existing) > 1:
        raise TransitionError(f"duplicate_evidence_id:{evidence['id']}")

    current_index = CHANGE_ORDER.index(current)
    target_index = CHANGE_ORDER.index(target_status)
    if target_index == current_index:
        if not existing or evidence["id"] not in change.get("evidence_ids", []):
            raise TransitionError("idempotent_transition_requires_matching_recorded_evidence")
        return {"change_registry.json": changes, "evidence_registry.json": proofs}
    if target_index != current_index + 1:
        raise TransitionError(f"transition_must_be_next:{current}->{target_status}")

    if not existing:
        if any(entry.get("uri") == evidence["uri"] for entry in proofs["entries"]):
            raise TransitionError(f"duplicate_evidence_uri:{evidence['uri']}")
        proofs["entries"].append(evidence)
    evidence_ids = change.setdefault("evidence_ids", [])
    if evidence["id"] not in evidence_ids:
        evidence_ids.append(evidence["id"])
    change.setdefault("history", []).append(target_status)
    change["status"] = target_status

    if target_status == "APPROVED" and change.get("guardian") != "GREEN":
        raise TransitionError("approval_requires_green_guardian")
    if target_status in {"APPLIED", "MEASURED"} and change.get("guardian") != "GREEN":
        raise TransitionError(f"{target_status.lower()}_requires_green_guardian")
    if target_status == "APPLIED" and evidence["type"] != "GIT_COMMIT":
        raise TransitionError("applied_requires_git_commit_evidence")
    if target_status == "MEASURED" and evidence["type"] not in {
        "CI", "GODOT_RUN", "PC_TEST", "MOBILE_TEST", "PLAYTEST", "PERFORMANCE"
    }:
        raise TransitionError("measured_requires_runtime_or_validation_evidence")

    with tempfile.TemporaryDirectory(prefix="litd-governance-plan-") as tmp:
        validation_root = Path(tmp)
        for name in ("knowledge_registry.json", "decision_registry.json"):
            (validation_root / name).write_text(
                json.dumps(_load_payload(root, name), ensure_ascii=False), encoding="utf-8"
            )
        for name, payload in {
            "change_registry.json": changes,
            "evidence_registry.json": proofs,
        }.items():
            (validation_root / name).write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        errors = validate(validation_root, SCHEMA_ROOT)
    if errors:
        raise TransitionError("proposed_state_invalid:" + "|".join(errors))
    return {"change_registry.json": changes, "evidence_registry.json": proofs}


def apply_transition(root: Path, replacements: dict[str, dict[str, Any]]) -> None:
    """Atomically replace each validated registry file with rollback on failure."""
    originals = {name: (root / name).read_bytes() for name in replacements}
    written: list[str] = []
    try:
        for name, payload in replacements.items():
            destination = root / name
            fd, temp_name = tempfile.mkstemp(prefix=f".{name}.", dir=root)
            try:
                with os.fdopen(fd, "w", encoding="utf-8") as handle:
                    json.dump(payload, handle, sort_keys=True, indent=2, ensure_ascii=False)
                    handle.write("\n")
                    handle.flush()
                    os.fsync(handle.fileno())
                os.replace(temp_name, destination)
                written.append(name)
            finally:
                if os.path.exists(temp_name):
                    os.unlink(temp_name)
    except Exception:
        for name in written:
            (root / name).write_bytes(originals[name])
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description="Plan or apply one LITD governance transition")
    parser.add_argument("change_id")
    parser.add_argument("target_status", choices=CHANGE_ORDER)
    parser.add_argument("--evidence-json", type=Path, required=True)
    parser.add_argument("--registry-root", type=Path, default=REGISTRY_ROOT)
    parser.add_argument("--apply", action="store_true", help="write the validated plan")
    args = parser.parse_args()
    evidence = json.loads(args.evidence_json.read_text(encoding="utf-8"))
    replacements = plan_transition(
        args.registry_root,
        change_id=args.change_id,
        target_status=args.target_status,
        evidence=evidence,
    )
    if args.apply:
        apply_transition(args.registry_root, replacements)
    print(json.dumps({
        "change_id": args.change_id,
        "target_status": args.target_status,
        "mode": "APPLY" if args.apply else "DRY_RUN",
        "core_write_allowed": False,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
