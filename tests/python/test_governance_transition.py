import json
from pathlib import Path

import pytest

from tools.quality.global_governance import REGISTRY_ROOT, validate
from tools.quality.governance_transition import TransitionError, apply_transition, plan_transition


def _registry_copy(tmp_path: Path) -> Path:
    for source in REGISTRY_ROOT.glob("*.json"):
        (tmp_path / source.name).write_bytes(source.read_bytes())
    change_path = tmp_path / "change_registry.json"
    payload = json.loads(change_path.read_text(encoding="utf-8"))
    foundation = next(
        entry for entry in payload["entries"]
        if entry["id"] == "CHG-GOVERNANCE-FOUNDATION-001"
    )
    foundation["status"] = "APPROVED"
    foundation["history"] = ["LITD_CHANGE_CANDIDATE", "TESTED", "APPROVED"]
    foundation["evidence_ids"] = ["EVD-GOVERNANCE-LOCAL-001"]
    change_path.write_text(json.dumps(payload), encoding="utf-8")
    return tmp_path


def _evidence(change_id: str, evidence_id: str, evidence_type: str) -> dict:
    return {
        "id": evidence_id,
        "type": evidence_type,
        "result": "PASS",
        "uri": f"https://github.com/hodaesu/litd/{evidence_id}",
        "observed_at": "2026-09-11T12:00:00Z",
        "change_id": change_id,
    }


def test_plan_is_dry_run_and_applied_transition_is_valid(tmp_path: Path):
    root = _registry_copy(tmp_path)
    before = (root / "change_registry.json").read_bytes()
    replacements = plan_transition(
        root,
        change_id="CHG-GOVERNANCE-FOUNDATION-001",
        target_status="APPLIED",
        evidence=_evidence("CHG-GOVERNANCE-FOUNDATION-001", "EVD-MERGE-TEST-001", "GIT_COMMIT"),
    )
    assert (root / "change_registry.json").read_bytes() == before
    apply_transition(root, replacements)
    assert validate(root) == []
    change = json.loads((root / "change_registry.json").read_text())["entries"][0]
    assert change["status"] == "APPLIED"


def test_transition_must_be_the_immediate_next_state(tmp_path: Path):
    root = _registry_copy(tmp_path)
    with pytest.raises(TransitionError, match="transition_must_be_next"):
        plan_transition(
            root,
            change_id="CHG-GOVERNANCE-FOUNDATION-001",
            target_status="MEASURED",
            evidence=_evidence("CHG-GOVERNANCE-FOUNDATION-001", "EVD-CI-TEST-001", "CI"),
        )


def test_applied_requires_git_commit_evidence(tmp_path: Path):
    root = _registry_copy(tmp_path)
    with pytest.raises(TransitionError, match="applied_requires_git_commit_evidence"):
        plan_transition(
            root,
            change_id="CHG-GOVERNANCE-FOUNDATION-001",
            target_status="APPLIED",
            evidence=_evidence("CHG-GOVERNANCE-FOUNDATION-001", "EVD-WRONG-TYPE-001", "CI"),
        )


def test_conflicting_evidence_id_fails_closed(tmp_path: Path):
    root = _registry_copy(tmp_path)
    existing = json.loads((root / "evidence_registry.json").read_text())["entries"][0]
    conflicting = dict(existing, uri="https://example.invalid/conflict")
    with pytest.raises(TransitionError, match="evidence_id_conflict"):
        plan_transition(
            root,
            change_id="CHG-GOVERNANCE-FOUNDATION-001",
            target_status="APPLIED",
            evidence=conflicting,
        )
