#!/usr/bin/env python3
"""Human-controlled promotion of EXPERIMENTAL LITD Knowledge to ACTIVE."""

from __future__ import annotations

import argparse
import hashlib
from dataclasses import asdict, dataclass
from datetime import date, datetime, timezone
import json
import os
from pathlib import Path
import tempfile
from typing import Any

from tools.quality.global_governance import REGISTRY_ROOT, SCHEMA_ROOT, validate


@dataclass(frozen=True)
class PromotionPlan:
    status: str
    reason: str
    knowledge_id: str
    registry_payload: dict[str, Any] | None = None
    source_registry_sha256: str | None = None
    requires_human_review: bool = True
    core_write_allowed: bool = False


def _load_registry(root: Path) -> tuple[dict[str, Any], str]:
    try:
        raw = (root / "knowledge_registry.json").read_bytes()
        payload = json.loads(raw.decode("utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot_load:knowledge_registry.json:{exc}") from exc
    if payload.get("schema_version") != 1 or not isinstance(payload.get("entries"), list):
        raise ValueError("invalid_registry_envelope:knowledge_registry.json")
    return payload, hashlib.sha256(raw).hexdigest()


def _nonempty(review: dict[str, Any], field: str) -> bool:
    return isinstance(review.get(field), str) and bool(review[field].strip())


def plan_promotion(
    knowledge_id: str, review: dict[str, Any], root: Path = REGISTRY_ROOT
) -> PromotionPlan:
    """Validate a human review and prepare an atomic registry replacement."""
    registry, source_registry_sha256 = _load_registry(root)
    matches = [entry for entry in registry["entries"] if entry.get("id") == knowledge_id]
    if len(matches) != 1:
        return PromotionPlan("BLOCKED", "knowledge_entry_not_found_or_ambiguous", knowledge_id)
    entry = matches[0]
    review_fields = ("decision", "reviewer", "reviewed_at", "rationale", "contradiction_resolution")
    comparable_review = {
        key: review[key].strip() if isinstance(review.get(key), str) else review.get(key)
        for key in review_fields if key in review
    }
    if (entry.get("status") == "ACTIVE" and entry.get("review") == comparable_review
            and review.get("human_approval", True) is True):
        return PromotionPlan(
            "ALREADY_ACTIVE", "idempotent_existing_review", knowledge_id,
            registry_payload=registry, source_registry_sha256=source_registry_sha256,
        )
    if entry.get("status") != "EXPERIMENTAL":
        return PromotionPlan("BLOCKED", "only_experimental_knowledge_can_be_promoted", knowledge_id)
    if review.get("decision") != "APPROVED" or review.get("human_approval") is not True:
        return PromotionPlan("BLOCKED", "explicit_human_approval_required", knowledge_id)
    for field in ("reviewer", "reviewed_at", "rationale", "contradiction_resolution"):
        if not _nonempty(review, field):
            return PromotionPlan("BLOCKED", f"missing_review_field:{field}", knowledge_id)
    try:
        reviewed_at = datetime.fromisoformat(review["reviewed_at"].replace("Z", "+00:00"))
        revalidate_at = date.fromisoformat(str(entry["revalidate_at"]))
    except (TypeError, ValueError) as exc:
        return PromotionPlan("BLOCKED", f"invalid_review_date:{exc}", knowledge_id)
    if reviewed_at.tzinfo is None:
        return PromotionPlan("BLOCKED", "reviewed_at_timezone_required", knowledge_id)
    if reviewed_at > datetime.now(timezone.utc):
        return PromotionPlan("BLOCKED", "reviewed_at_cannot_be_future", knowledge_id)
    if revalidate_at <= reviewed_at.date():
        return PromotionPlan("BLOCKED", "revalidation_must_follow_review", knowledge_id)

    stored_review = {key: review[key].strip() if isinstance(review[key], str) else review[key]
                     for key in review_fields}
    entry["status"] = "ACTIVE"
    entry["validated_at"] = reviewed_at.date().isoformat()
    entry["review"] = stored_review

    with tempfile.TemporaryDirectory(prefix="litd-knowledge-promotion-") as tmp:
        candidate_root = Path(tmp)
        for name in ("decision_registry.json", "change_registry.json", "evidence_registry.json"):
            (candidate_root / name).write_bytes((root / name).read_bytes())
        (candidate_root / "knowledge_registry.json").write_text(
            json.dumps(registry, ensure_ascii=False), encoding="utf-8"
        )
        errors = validate(candidate_root, SCHEMA_ROOT)
    if errors:
        return PromotionPlan("BLOCKED", "candidate_registry_invalid:" + "|".join(errors), knowledge_id)
    return PromotionPlan(
        "PROMOTION_READY", "human_review_validated", knowledge_id,
        registry_payload=registry, source_registry_sha256=source_registry_sha256,
    )


def apply_plan(plan: PromotionPlan, root: Path = REGISTRY_ROOT) -> None:
    if plan.status == "ALREADY_ACTIVE":
        return
    if (plan.status != "PROMOTION_READY" or plan.registry_payload is None
            or plan.source_registry_sha256 is None):
        raise ValueError(f"promotion_plan_not_applicable:{plan.status}")
    registry_path = root / "knowledge_registry.json"
    current_sha256 = hashlib.sha256(registry_path.read_bytes()).hexdigest()
    if current_sha256 != plan.source_registry_sha256:
        raise ValueError("knowledge_registry_changed_since_plan")
    fd, temp_name = tempfile.mkstemp(prefix=".knowledge_registry.", dir=root)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(plan.registry_payload, handle, sort_keys=True, indent=2, ensure_ascii=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        current_sha256 = hashlib.sha256(registry_path.read_bytes()).hexdigest()
        if current_sha256 != plan.source_registry_sha256:
            raise ValueError("knowledge_registry_changed_since_plan")
        os.replace(temp_name, registry_path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def main() -> int:
    parser = argparse.ArgumentParser(description="Review and promote EXPERIMENTAL LITD Knowledge")
    parser.add_argument("knowledge_id")
    parser.add_argument("review_json", type=Path)
    parser.add_argument("--registry-root", type=Path, default=REGISTRY_ROOT)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    review = json.loads(args.review_json.read_text(encoding="utf-8"))
    plan = plan_promotion(args.knowledge_id, review, args.registry_root)
    if args.apply:
        apply_plan(plan, args.registry_root)
    output = asdict(plan)
    output.pop("registry_payload", None)
    output["mode"] = "APPLY" if args.apply else "DRY_RUN"
    print(json.dumps(output, sort_keys=True, ensure_ascii=False))
    return 0 if plan.status in {"PROMOTION_READY", "ALREADY_ACTIVE"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
