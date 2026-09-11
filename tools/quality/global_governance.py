#!/usr/bin/env python3
"""Fail-closed cross-registry gate for LITD global governance."""

from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
REGISTRY_ROOT = ROOT / "docs" / "knowledge" / "governance" / "registry"
SCHEMA_ROOT = ROOT / "docs" / "knowledge" / "governance" / "schemas"

KNOWLEDGE_OK = {"ACTIVE", "EXPERIMENTAL"}
CHANGE_ORDER = ["LITD_CHANGE_CANDIDATE", "TESTED", "APPROVED", "APPLIED", "MEASURED"]


def _load(name: str, root: Path = REGISTRY_ROOT) -> list[dict]:
    path = root / name
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot load {path}: {exc}") from exc
    if payload.get("schema_version") != 1 or not isinstance(payload.get("entries"), list):
        raise ValueError(f"invalid registry envelope: {path}")
    return payload["entries"]


def _index(entries: list[dict], label: str, errors: list[str]) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for item in entries:
        item_id = item.get("id")
        if not isinstance(item_id, str) or not item_id:
            errors.append(f"{label}: entry without id")
        elif item_id in result:
            errors.append(f"{label}: duplicate id {item_id}")
        else:
            result[item_id] = item
    return result


def _validate_schema_contract(
    entries: list[dict], schema_name: str, label: str, errors: list[str], schema_root: Path
) -> None:
    try:
        schema = json.loads((schema_root / schema_name).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"{label}: invalid schema: {exc}")
        return
    required = set(schema.get("required", []))
    properties = schema.get("properties", {})
    for entry in entries:
        entry_id = entry.get("id", "<unknown>")
        missing = sorted(required - entry.keys())
        if missing:
            errors.append(f"{entry_id}: missing required fields {missing}")
        if schema.get("additionalProperties") is False:
            unexpected = sorted(entry.keys() - properties.keys())
            if unexpected:
                errors.append(f"{entry_id}: unexpected fields {unexpected}")
        for field, rules in properties.items():
            if field in entry and "enum" in rules and entry[field] not in rules["enum"]:
                errors.append(f"{entry_id}: invalid {field} {entry[field]!r}")


def validate(root: Path = REGISTRY_ROOT, schema_root: Path = SCHEMA_ROOT) -> list[str]:
    errors: list[str] = []
    try:
        knowledge_entries = _load("knowledge_registry.json", root)
        decision_entries = _load("decision_registry.json", root)
        change_entries = _load("change_registry.json", root)
        evidence_entries = _load("evidence_registry.json", root)
    except ValueError as exc:
        return [str(exc)]

    _validate_schema_contract(knowledge_entries, "knowledge_entry.schema.json", "knowledge", errors, schema_root)
    _validate_schema_contract(decision_entries, "decision.schema.json", "decision", errors, schema_root)
    _validate_schema_contract(change_entries, "change_candidate.schema.json", "change", errors, schema_root)
    _validate_schema_contract(evidence_entries, "evidence.schema.json", "evidence", errors, schema_root)
    knowledge = _index(knowledge_entries, "knowledge", errors)
    decisions = _index(decision_entries, "decision", errors)
    changes = _index(change_entries, "change", errors)
    evidence = _index(evidence_entries, "evidence", errors)

    for decision in decisions.values():
        refs = decision.get("knowledge_ids")
        if not isinstance(refs, list) or not refs:
            errors.append(f"{decision['id']}: no knowledge references")
            continue
        for ref in refs:
            entry = knowledge.get(ref)
            if entry is None:
                errors.append(f"{decision['id']}: unknown knowledge {ref}")
            elif entry.get("status") not in KNOWLEDGE_OK:
                errors.append(f"{decision['id']}: knowledge gate closed by {ref} status {entry.get('status')}")

    for change in changes.values():
        decision = decisions.get(change.get("decision_id"))
        if decision is None:
            errors.append(f"{change['id']}: unknown decision {change.get('decision_id')}")
            continue
        history = change.get("history")
        status = change.get("status")
        if not isinstance(history, list) or not history or history[-1] != status:
            errors.append(f"{change['id']}: history must end at current status")
        elif history != CHANGE_ORDER[: len(history)]:
            errors.append(f"{change['id']}: illegal state transition history")
        refs = change.get("evidence_ids", [])
        if status in {"TESTED", "APPROVED", "APPLIED", "MEASURED"} and not refs:
            errors.append(f"{change['id']}: status {status} requires evidence")
        for ref in refs:
            proof = evidence.get(ref)
            if proof is None:
                errors.append(f"{change['id']}: unknown evidence {ref}")
            elif proof.get("change_id") != change["id"]:
                errors.append(f"{change['id']}: evidence {ref} points elsewhere")
        if change.get("guardian") == "GREEN":
            if decision.get("status") != "APPROVED" or decision.get("human_approval") is not True:
                errors.append(f"{change['id']}: GREEN requires approved human decision")
            if not change.get("test_plan") or not change.get("rollback_plan"):
                errors.append(f"{change['id']}: GREEN requires test and rollback plans")
        if status in {"APPLIED", "MEASURED"} and change.get("guardian") != "GREEN":
            errors.append(f"{change['id']}: {status} requires GREEN Guardian")

    for proof in evidence.values():
        if proof.get("change_id") not in changes:
            errors.append(f"{proof['id']}: orphan evidence")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        for error in errors:
            print(f"GLOBAL_GOVERNANCE_ERROR: {error}", file=sys.stderr)
        return 1
    print("GLOBAL_GOVERNANCE_GATE: GREEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
