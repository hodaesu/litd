#!/usr/bin/env python3
"""Fail-closed bridge from VEILLEUR V2 routing to the LITD Knowledge registry."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta
import json
import os
from pathlib import Path
import tempfile
from typing import Any

from tools.quality.global_governance import REGISTRY_ROOT, SCHEMA_ROOT, validate
from tools.quality.library_trieur import Route, route_information
from tools.quality.veilleur_v2_ingest import validate_event

MIN_LITD_SOURCE_CONFIDENCE = 0.70


@dataclass(frozen=True)
class KnowledgeIntakePlan:
    status: str
    reason: str
    route: str
    knowledge_id: str | None = None
    registry_payload: dict[str, Any] | None = None
    requires_human_review: bool = False
    core_write_allowed: bool = False


def _knowledge_id(canonical_hash: str) -> str:
    return f"KNOW-INTAKE-{canonical_hash[:16].upper()}"


def _load_registry(root: Path, name: str) -> dict[str, Any]:
    path = root / name
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot_load:{name}:{exc}") from exc
    if payload.get("schema_version") != 1 or not isinstance(payload.get("entries"), list):
        raise ValueError(f"invalid_registry_envelope:{name}")
    return payload


def _valid_counterevidence(event: dict[str, Any]) -> list[str] | None:
    findings = event.get("counterevidence")
    if not isinstance(findings, list) or not findings:
        return None
    if not all(isinstance(item, str) and item.strip() for item in findings):
        return None
    return [item.strip() for item in findings]


def plan_intake(event: dict[str, Any], root: Path = REGISTRY_ROOT) -> KnowledgeIntakePlan:
    """Validate, route and prepare a Knowledge entry without writing it."""
    ingress = validate_event(event)
    if not ingress.accepted or ingress.canonical_hash is None:
        return KnowledgeIntakePlan(ingress.status, ingress.reason, Route.QUARANTINE.value)

    text = "\n".join((
        str(event["title"]),
        str(event["summary"]),
        " ".join(str(item) for item in event["domain_hints"]),
    ))
    routing = route_information(text, source_verified=True)
    if routing.route == Route.GENERAL:
        return KnowledgeIntakePlan("ROUTED_GENERAL", routing.reason, routing.route.value)
    if routing.route == Route.QUARANTINE:
        return KnowledgeIntakePlan("QUARANTINED", routing.reason, routing.route.value)

    confidence = float(event["source_confidence"])
    if confidence < MIN_LITD_SOURCE_CONFIDENCE:
        return KnowledgeIntakePlan(
            "QUARANTINED", "source_confidence_below_litd_threshold", Route.QUARANTINE.value
        )
    counterevidence = _valid_counterevidence(event)
    if counterevidence is None:
        return KnowledgeIntakePlan(
            "QUARANTINED", "counterevidence_required_for_litd_candidate", Route.QUARANTINE.value
        )

    knowledge_id = _knowledge_id(ingress.canonical_hash)
    registry = _load_registry(root, "knowledge_registry.json")
    domain = str(event["domain_hints"][0]).strip().casefold().replace(" ", "-")
    discovered = datetime.fromisoformat(str(event["discovered_at"]).replace("Z", "+00:00"))
    entry = {
        "id": knowledge_id,
        "domain": domain,
        "claim": str(event["summary"]).strip(),
        "status": "EXPERIMENTAL",
        "sources": [str(event["source_url"]).strip()],
        "source_evidence_ids": [str(event["evidence_id"]).strip()],
        "source_confidence": confidence,
        "contradictions": counterevidence,
        "dependencies": [],
        "validated_at": discovered.date().isoformat(),
        "revalidate_at": (discovered + timedelta(days=30)).date().isoformat(),
    }

    existing = [item for item in registry["entries"] if item.get("id") == knowledge_id]
    if existing:
        if json.dumps(existing[0], sort_keys=True) == json.dumps(entry, sort_keys=True):
            return KnowledgeIntakePlan(
                "ALREADY_REGISTERED", "idempotent_existing_entry", routing.route.value,
                knowledge_id, registry, True,
            )
        return KnowledgeIntakePlan(
            "DUPLICATE", "knowledge_id_conflict", Route.QUARANTINE.value, knowledge_id
        )

    registry["entries"].append(entry)
    with tempfile.TemporaryDirectory(prefix="litd-knowledge-intake-") as tmp:
        candidate_root = Path(tmp)
        for name in ("decision_registry.json", "change_registry.json", "evidence_registry.json"):
            (candidate_root / name).write_text(
                json.dumps(_load_registry(root, name), ensure_ascii=False), encoding="utf-8"
            )
        (candidate_root / "knowledge_registry.json").write_text(
            json.dumps(registry, ensure_ascii=False), encoding="utf-8"
        )
        errors = validate(candidate_root, SCHEMA_ROOT)
    if errors:
        return KnowledgeIntakePlan(
            "QUARANTINED", "candidate_registry_invalid:" + "|".join(errors),
            Route.QUARANTINE.value, knowledge_id,
        )
    return KnowledgeIntakePlan(
        "LITD_KNOWLEDGE_CANDIDATE", "validated_routed_and_counterchecked",
        routing.route.value, knowledge_id, registry, True,
    )


def apply_plan(plan: KnowledgeIntakePlan, root: Path = REGISTRY_ROOT) -> None:
    if plan.status not in {"LITD_KNOWLEDGE_CANDIDATE", "ALREADY_REGISTERED"}:
        raise ValueError(f"intake_plan_not_applicable:{plan.status}")
    if plan.status == "ALREADY_REGISTERED":
        return
    if plan.registry_payload is None:
        raise ValueError("intake_plan_missing_registry_payload")
    destination = root / "knowledge_registry.json"
    fd, temp_name = tempfile.mkstemp(prefix=".knowledge_registry.", dir=root)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(plan.registry_payload, handle, sort_keys=True, indent=2, ensure_ascii=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, destination)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def main() -> int:
    parser = argparse.ArgumentParser(description="Route one VEILLEUR V2 event into Knowledge")
    parser.add_argument("event_json", type=Path)
    parser.add_argument("--registry-root", type=Path, default=REGISTRY_ROOT)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    event = json.loads(args.event_json.read_text(encoding="utf-8"))
    plan = plan_intake(event, args.registry_root)
    if args.apply:
        apply_plan(plan, args.registry_root)
    output = asdict(plan)
    output.pop("registry_payload", None)
    output["mode"] = "APPLY" if args.apply else "DRY_RUN"
    print(json.dumps(output, sort_keys=True, ensure_ascii=False))
    return 0 if plan.status not in {"REJECTED", "QUARANTINED", "DUPLICATE"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
