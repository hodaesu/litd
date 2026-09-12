import json
from pathlib import Path

from tools.quality.global_governance import REGISTRY_ROOT, validate
from tools.quality.knowledge_impact import apply_plan, plan_impact


def _root(tmp_path: Path) -> Path:
    for source in REGISTRY_ROOT.glob("*.json"):
        (tmp_path / source.name).write_bytes(source.read_bytes())
    return tmp_path


def _request(**overrides) -> dict:
    request = {
        "knowledge_ids": ["KNOW-GOVERNANCE-FOUNDATION-001"],
        "summary": "Add a bounded governance report.",
        "rationale": "The active governance contract requires visible evidence.",
        "pillars": ["P7", "P9"],
        "affected_paths": ["docs/knowledge/governance/report.json"],
        "risks": ["The report may become stale."],
        "contradictor_findings": ["A static report is not runtime observability."],
        "test_plan": "Validate schema and references in CI.",
        "rollback_plan": "Revert the isolated report commit.",
    }
    request.update(overrides)
    return request


def test_active_knowledge_builds_review_only_core_candidate(tmp_path: Path):
    root = _root(tmp_path)
    before = (root / "core_candidate_registry.json").read_bytes()
    plan = plan_impact(_request(), root)
    assert plan.status == "CORE_CHANGE_CANDIDATE"
    assert plan.guardian == "ORANGE"
    assert plan.core_write_allowed is False
    assert (root / "core_candidate_registry.json").read_bytes() == before
    apply_plan(plan, root)
    assert validate(root) == []
    candidate = json.loads((root / "core_candidate_registry.json").read_text())["entries"][0]
    assert candidate["status"] == "REVIEW"
    assert candidate["human_approval"] is False


def test_experimental_knowledge_is_blocked(tmp_path: Path):
    plan = plan_impact(
        _request(knowledge_ids=["KNOW-GOVERNANCE-INTAKE-003"]), _root(tmp_path)
    )
    assert plan.status == "BLOCKED"
    assert plan.reason.startswith("active_knowledge_required")


def test_missing_contradictor_findings_is_blocked(tmp_path: Path):
    plan = plan_impact(_request(contradictor_findings=[]), _root(tmp_path))
    assert plan.reason == "missing_field:contradictor_findings"


def test_unsafe_path_is_blocked(tmp_path: Path):
    plan = plan_impact(_request(affected_paths=["../core.gd"]), _root(tmp_path))
    assert plan.reason == "unsafe_affected_path"


def test_candidate_creation_is_idempotent(tmp_path: Path):
    root = _root(tmp_path)
    first = plan_impact(_request(), root)
    apply_plan(first, root)
    second = plan_impact(_request(), root)
    assert second.status == "ALREADY_REGISTERED"
    apply_plan(second, root)
