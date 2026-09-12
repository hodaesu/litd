import json
from pathlib import Path

import pytest

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


@pytest.mark.parametrize(
    "unsafe_path",
    ["../core.gd", "/tmp/core.gd", ".git/config", "./.git/config", "docs/../core.gd", "docs//core.gd", r"docs\\core.gd"],
)
def test_unsafe_path_is_blocked(tmp_path: Path, unsafe_path: str):
    plan = plan_impact(_request(affected_paths=[unsafe_path]), _root(tmp_path))
    assert plan.reason == "unsafe_affected_path"


def test_candidate_creation_is_idempotent(tmp_path: Path):
    root = _root(tmp_path)
    first = plan_impact(_request(), root)
    apply_plan(first, root)
    second = plan_impact(_request(), root)
    assert second.status == "ALREADY_REGISTERED"
    apply_plan(second, root)



def test_apply_rejects_registry_changed_after_plan(tmp_path: Path):
    root = _root(tmp_path)
    plan = plan_impact(_request(), root)
    path = root / "core_candidate_registry.json"
    path.write_text(path.read_text(encoding="utf-8") + "\n", encoding="utf-8")
    with pytest.raises(ValueError, match="core_candidate_registry_changed_since_plan"):
        apply_plan(plan, root)


def test_idempotent_result_still_requires_valid_registry(tmp_path: Path):
    root = _root(tmp_path)
    first = plan_impact(_request(), root)
    apply_plan(first, root)
    path = root / "core_candidate_registry.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["entries"][0]["affected_paths"] = ["../core.gd"]
    path.write_text(json.dumps(payload), encoding="utf-8")
    second = plan_impact(_request(), root)
    assert second.status == "BLOCKED"
    assert second.reason.startswith("registry_invalid:")
