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
