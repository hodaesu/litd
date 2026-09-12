#!/usr/bin/env python3
"""Build review-only Core change candidates from ACTIVE LITD Knowledge."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import tempfile
from typing import Any

from tools.quality.global_governance import REGISTRY_ROOT, SCHEMA_ROOT, validate

PILLARS = {f"P{number}" for number in range(1, 10)}


@dataclass(frozen=True)
class ImpactPlan:
    status: str
    reason: str
    candidate_id: str | None = None
    registry_payload: dict[str, Any] | None = None
    source_registry_sha256: str | None = None
    requires_core_review: bool = True
    guardian: str = "ORANGE"
    core_write_allowed: bool = False


def _load(root: Path, name: str) -> dict[str, Any]:
    try:
        payload = json.loads((root / name).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot_load:{name}:{exc}") from exc
    if payload.get("schema_version") != 1 or not isinstance(payload.get("entries"), list):
        raise ValueError(f"invalid_registry_envelope:{name}")
    return payload


def _load_candidate_registry(root: Path) -> tuple[dict[str, Any], str]:
    path = root / "core_candidate_registry.json"
    try:
        raw = path.read_bytes()
        payload = json.loads(raw.decode("utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot_load:core_candidate_registry.json:{exc}") from exc
    if payload.get("schema_version") != 1 or not isinstance(payload.get("entries"), list):
        raise ValueError("invalid_registry_envelope:core_candidate_registry.json")
    return payload, hashlib.sha256(raw).hexdigest()


def _strings(value: Any) -> list[str] | None:
    if not isinstance(value, list) or not value:
        return None
    if not all(isinstance(item, str) and item.strip() for item in value):
        return None
    return [item.strip() for item in value]


def _safe_paths(paths: list[str]) -> bool:
    for raw in paths:
        if "\\" in raw or "\x00" in raw:
            return False
        path = PurePosixPath(raw)
        if (
            path.is_absolute()
            or path.as_posix() != raw
            or any(part == ".." or part.casefold() == ".git" for part in path.parts)
        ):
            return False
    return True


def _candidate_id(candidate: dict[str, Any]) -> str:
    canonical = json.dumps(candidate, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "CORE-CANDIDATE-" + hashlib.sha256(canonical.encode()).hexdigest()[:16].upper()


def plan_impact(request: dict[str, Any], root: Path = REGISTRY_ROOT) -> ImpactPlan:
    baseline_errors = validate(root, SCHEMA_ROOT)
    if baseline_errors:
        return ImpactPlan("BLOCKED", "registry_invalid:" + "|".join(baseline_errors))
    knowledge_ids = _strings(request.get("knowledge_ids"))
    if knowledge_ids is None or len(set(knowledge_ids)) != len(knowledge_ids):
        return ImpactPlan("BLOCKED", "unique_knowledge_ids_required")
    knowledge = {item.get("id"): item for item in _load(root, "knowledge_registry.json")["entries"]}
    for knowledge_id in knowledge_ids:
        entry = knowledge.get(knowledge_id)
        if entry is None:
            return ImpactPlan("BLOCKED", f"unknown_knowledge:{knowledge_id}")
        if entry.get("status") != "ACTIVE":
            return ImpactPlan("BLOCKED", f"active_knowledge_required:{knowledge_id}")

    required_text = ("summary", "rationale", "test_plan", "rollback_plan")
    for field in required_text:
        if not isinstance(request.get(field), str) or not request[field].strip():
            return ImpactPlan("BLOCKED", f"missing_field:{field}")
    collections: dict[str, list[str]] = {}
    for field in ("pillars", "affected_paths", "risks", "contradictor_findings"):
        values = _strings(request.get(field))
        if values is None:
            return ImpactPlan("BLOCKED", f"missing_field:{field}")
        collections[field] = values
    if not set(collections["pillars"]).issubset(PILLARS):
        return ImpactPlan("BLOCKED", "invalid_pillar")
    if not _safe_paths(collections["affected_paths"]):
        return ImpactPlan("BLOCKED", "unsafe_affected_path")

    candidate = {
        "status": "REVIEW",
        "knowledge_ids": knowledge_ids,
        "summary": request["summary"].strip(),
        "rationale": request["rationale"].strip(),
        "pillars": collections["pillars"],
        "affected_paths": collections["affected_paths"],
        "risks": collections["risks"],
        "contradictor_findings": collections["contradictor_findings"],
        "test_plan": request["test_plan"].strip(),
        "rollback_plan": request["rollback_plan"].strip(),
        "guardian": "ORANGE",
        "human_approval": False,
        "core_write_allowed": False,
    }
    candidate_id = _candidate_id(candidate)
    candidate["id"] = candidate_id
    registry, source_registry_sha256 = _load_candidate_registry(root)
    matches = [item for item in registry["entries"] if item.get("id") == candidate_id]
    if matches:
        if matches[0] == candidate:
            return ImpactPlan("ALREADY_REGISTERED", "idempotent_existing_candidate", candidate_id, registry, source_registry_sha256)
        return ImpactPlan("BLOCKED", "candidate_id_conflict", candidate_id)
    registry["entries"].append(candidate)

    with tempfile.TemporaryDirectory(prefix="litd-impact-") as tmp:
        validation_root = Path(tmp)
        for source in root.glob("*.json"):
            (validation_root / source.name).write_bytes(source.read_bytes())
        (validation_root / "core_candidate_registry.json").write_text(
            json.dumps(registry, ensure_ascii=False), encoding="utf-8"
        )
        errors = validate(validation_root, SCHEMA_ROOT)
    if errors:
        return ImpactPlan("BLOCKED", "candidate_registry_invalid:" + "|".join(errors), candidate_id)
    return ImpactPlan(
        "CORE_CHANGE_CANDIDATE", "active_knowledge_impact_ready_for_core_review",
        candidate_id, registry, source_registry_sha256,
    )


def apply_plan(plan: ImpactPlan, root: Path = REGISTRY_ROOT) -> None:
    if plan.status == "ALREADY_REGISTERED":
        return
    if (
        plan.status != "CORE_CHANGE_CANDIDATE"
        or plan.registry_payload is None
        or plan.source_registry_sha256 is None
    ):
        raise ValueError(f"impact_plan_not_applicable:{plan.status}")
    registry_path = root / "core_candidate_registry.json"
    current_sha256 = hashlib.sha256(registry_path.read_bytes()).hexdigest()
    if current_sha256 != plan.source_registry_sha256:
        raise ValueError("core_candidate_registry_changed_since_plan")
    fd, temp_name = tempfile.mkstemp(prefix=".core_candidate_registry.", dir=root)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(plan.registry_payload, handle, sort_keys=True, indent=2, ensure_ascii=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        current_sha256 = hashlib.sha256(registry_path.read_bytes()).hexdigest()
        if current_sha256 != plan.source_registry_sha256:
            raise ValueError("core_candidate_registry_changed_since_plan")
        os.replace(temp_name, registry_path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a review-only Core change candidate")
    parser.add_argument("request_json", type=Path)
    parser.add_argument("--registry-root", type=Path, default=REGISTRY_ROOT)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    request = json.loads(args.request_json.read_text(encoding="utf-8"))
    plan = plan_impact(request, args.registry_root)
    if args.apply:
        apply_plan(plan, args.registry_root)
    output = asdict(plan)
    output.pop("registry_payload", None)
    output["mode"] = "APPLY" if args.apply else "DRY_RUN"
    print(json.dumps(output, sort_keys=True, ensure_ascii=False))
    return 0 if plan.status in {"CORE_CHANGE_CANDIDATE", "ALREADY_REGISTERED"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
