import json
from pathlib import Path

from tools.quality.global_governance import REGISTRY_ROOT, validate


def test_committed_registries_are_green():
    assert validate() == []


def test_gate_fails_closed_for_quarantined_knowledge(tmp_path: Path):
    for source in REGISTRY_ROOT.glob("*.json"):
        (tmp_path / source.name).write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
    path = tmp_path / "knowledge_registry.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["entries"][0]["status"] = "QUARANTINED"
    path.write_text(json.dumps(payload), encoding="utf-8")
    assert any("knowledge gate closed" in error for error in validate(tmp_path))


def test_gate_rejects_skipped_transition(tmp_path: Path):
    for source in REGISTRY_ROOT.glob("*.json"):
        (tmp_path / source.name).write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
    path = tmp_path / "change_registry.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["entries"][0]["status"] = "APPROVED"
    payload["entries"][0]["history"] = ["LITD_CHANGE_CANDIDATE", "APPROVED"]
    path.write_text(json.dumps(payload), encoding="utf-8")
    assert any("illegal state transition" in error for error in validate(tmp_path))


def test_green_requires_human_approval(tmp_path: Path):
    for source in REGISTRY_ROOT.glob("*.json"):
        (tmp_path / source.name).write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
    path = tmp_path / "decision_registry.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["entries"][0]["human_approval"] = False
    path.write_text(json.dumps(payload), encoding="utf-8")
    assert any("GREEN requires approved human decision" in error for error in validate(tmp_path))


def test_gate_rejects_core_candidate_with_write_authority(tmp_path: Path):
    for source in REGISTRY_ROOT.glob("*.json"):
        (tmp_path / source.name).write_bytes(source.read_bytes())
    path = tmp_path / "core_candidate_registry.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["entries"].append({
        "id": "CORE-CANDIDATE-0123456789ABCDEF",
        "status": "REVIEW",
        "knowledge_ids": ["KNOW-GOVERNANCE-FOUNDATION-001"],
        "summary": "Unsafe candidate",
        "rationale": "Contract test",
        "pillars": ["P9"],
        "affected_paths": ["docs/example.json"],
        "risks": ["Unsafe authority"],
        "contradictor_findings": ["Must be blocked"],
        "test_plan": "Run the gate",
        "rollback_plan": "Discard candidate",
        "guardian": "GREEN",
        "human_approval": True,
        "core_write_allowed": True,
    })
    path.write_text(json.dumps(payload), encoding="utf-8")
    errors = validate(tmp_path)
    assert any("cannot authorize Core writes" in error for error in errors)
    assert any("must remain ORANGE" in error for error in errors)
