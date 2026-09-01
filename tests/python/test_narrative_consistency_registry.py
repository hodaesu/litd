import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "data/litd_universe_narrative_inconsistencies.json"


def load_registry():
    return json.loads(REGISTRY.read_text(encoding="utf-8"))


def test_registry_summary_is_computed_from_entries():
    data = load_registry()
    entries = data["entries"]
    summary = data["summary"]
    counts = Counter(entry["severity"] for entry in entries)

    assert summary["entries_total"] == len(entries)
    assert summary["blocking_total"] == counts["BLOCKING"]
    assert summary["major_total"] == counts["MAJOR"]
    assert summary["minor_total"] == counts["MINOR"]
    assert summary["open_question_total"] == counts["OPEN_QUESTION"]


def test_no_blocking_or_major_issue_can_be_declared_ready_while_open():
    data = load_registry()
    unresolved = [
        entry for entry in data["entries"]
        if entry["severity"] in {"BLOCKING", "MAJOR"} and entry["status"] != "RESOLVED"
    ]
    assert unresolved == []
    assert data["summary"]["blocking_open"] == 0
    assert data["summary"]["major_open"] == 0
    assert data["summary"]["validation_state"] == "READY_FOR_REVIEW"


def test_audit_entries_are_traceable_and_have_unique_ids():
    entries = load_registry()["entries"]
    ids = [entry["id"] for entry in entries]
    assert len(ids) == len(set(ids))
    for entry in entries:
        assert entry["problem"].strip()
        assert entry["resolution"].strip()
        assert entry["files"]


def test_current_audit_has_no_unresolved_questions_or_minor_issues():
    data = load_registry()
    entries = data["entries"]
    assert all(entry["status"] == "RESOLVED" for entry in entries)
    assert data["summary"]["minor_open"] == 0
    assert data["summary"]["open_question_unresolved"] == 0
