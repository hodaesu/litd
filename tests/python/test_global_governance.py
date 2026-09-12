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


def _candidate(**overrides):
    candidate = {
        "status": "REVIEW",
        "knowledge_ids": ["KNOW-GOVERNANCE-FOUNDATION-001"],
        "summary": "Bounded candidate",
        "rationale": "Contract test",
        "pillars": ["P9"],
        "affected_paths": ["docs/example.json"],
        "risks": ["Incomplete scope"],
        "contradictor_findings": ["Requires review"],
        "test_plan": "Run the gate",
        "rollback_plan": "Discard candidate",
        "guardian": "ORANGE",
        "human_approval": False,
        "core_write_allowed": False,
    }
    from tools.quality.global_governance import _expected_core_candidate_id
    candidate["id"] = _expected_core_candidate_id(candidate)
    candidate.update(overrides)
    return candidate


def _registry_copy(tmp_path: Path) -> Path:
    for source in REGISTRY_ROOT.glob("*.json"):
        (tmp_path / source.name).write_bytes(source.read_bytes())
    return tmp_path


def test_gate_rejects_core_candidate_with_write_authority(tmp_path: Path):
    root = _registry_copy(tmp_path)
    path = root / "core_candidate_registry.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["entries"].append(_candidate(guardian="GREEN", human_approval=True, core_write_allowed=True))
    path.write_text(json.dumps(payload), encoding="utf-8")
    errors = validate(root)
    assert any("cannot authorize Core writes" in error for error in errors)
    assert any("must remain ORANGE" in error for error in errors)


def test_gate_rejects_manual_unsafe_candidate_path(tmp_path: Path):
    root = _registry_copy(tmp_path)
    path = root / "core_candidate_registry.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    payload["entries"].append(_candidate(affected_paths=["./.git/config"]))
    path.write_text(json.dumps(payload), encoding="utf-8")
    assert any("unsafe affected path" in error for error in validate(root))


def test_gate_rejects_tampered_deterministic_candidate_id(tmp_path: Path):
    root = _registry_copy(tmp_path)
    path = root / "core_candidate_registry.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    candidate = _candidate()
    candidate["summary"] = "Changed after identifier generation"
    payload["entries"].append(candidate)
    path.write_text(json.dumps(payload), encoding="utf-8")
    assert any("deterministic candidate id mismatch" in error for error in validate(root))
