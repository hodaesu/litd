import json
from pathlib import Path

from tools.quality.global_governance import REGISTRY_ROOT, validate
from tools.quality.knowledge_promotion import apply_plan, plan_promotion


def _root(tmp_path: Path) -> Path:
    for source in REGISTRY_ROOT.glob("*.json"):
        (tmp_path / source.name).write_bytes(source.read_bytes())
    return tmp_path


def _review(**overrides) -> dict:
    review = {
        "decision": "APPROVED",
        "human_approval": True,
        "reviewer": "Aurélien Fabre",
        "reviewed_at": "2026-09-11T17:20:00Z",
        "rationale": "The evidence is relevant, sourced and sufficiently bounded for LITD.",
        "contradiction_resolution": "Known limits remain documented and require revalidation.",
    }
    review.update(overrides)
    return review


def test_approved_review_promotes_experimental_entry(tmp_path: Path):
    root = _root(tmp_path)
    before = (root / "knowledge_registry.json").read_bytes()
    plan = plan_promotion("KNOW-GOVERNANCE-INTAKE-003", _review(), root)
    assert plan.status == "PROMOTION_READY"
    assert plan.core_write_allowed is False
    assert (root / "knowledge_registry.json").read_bytes() == before
    apply_plan(plan, root)
    assert validate(root) == []
    entry = next(item for item in json.loads((root / "knowledge_registry.json").read_text())["entries"]
                 if item["id"] == "KNOW-GOVERNANCE-INTAKE-003")
    assert entry["status"] == "ACTIVE"
    assert entry["review"]["reviewer"] == "Aurélien Fabre"


def test_promotion_requires_explicit_human_approval(tmp_path: Path):
    plan = plan_promotion("KNOW-GOVERNANCE-INTAKE-003", _review(human_approval=False), _root(tmp_path))
    assert plan.status == "BLOCKED"
    assert plan.reason == "explicit_human_approval_required"


def test_promotion_requires_contradiction_resolution(tmp_path: Path):
    plan = plan_promotion(
        "KNOW-GOVERNANCE-INTAKE-003", _review(contradiction_resolution=""), _root(tmp_path)
    )
    assert plan.status == "BLOCKED"
    assert plan.reason == "missing_review_field:contradiction_resolution"


def test_promotion_is_idempotent(tmp_path: Path):
    root = _root(tmp_path)
    review = _review()
    first = plan_promotion("KNOW-GOVERNANCE-INTAKE-003", review, root)
    apply_plan(first, root)
    stored = {key: review[key] for key in review if key != "human_approval"}
    second = plan_promotion("KNOW-GOVERNANCE-INTAKE-003", stored, root)
    assert second.status == "ALREADY_ACTIVE"
    apply_plan(second, root)


def test_active_or_missing_entry_cannot_be_promoted(tmp_path: Path):
    root = _root(tmp_path)
    assert plan_promotion("KNOW-UNKNOWN", _review(), root).status == "BLOCKED"
    assert plan_promotion("KNOW-GOVERNANCE-FOUNDATION-001", _review(), root).status == "BLOCKED"
