from pathlib import Path

from tools.quality.evidence_ledger import EvidenceLedger
from tools.quality.veilleur_triage import process_batch
from tools.quality.veilleur_v2_ingest import canonical_content_hash


def event(title="Godot performance update", summary="Godot runtime performance improvements", hints=None):
    hints = hints or ["Godot", "performance"]
    row = {
        "evidence_id": "veilleur:test:001",
        "title": title,
        "summary": summary,
        "source_url": "https://example.com/release",
        "source_verified": True,
        "source_confidence": 0.95,
        "discovered_at": "2026-09-12T06:00:00Z",
        "published_at": "2026-09-12T05:00:00Z",
        "domain_hints": hints,
    }
    row["content_hash"] = canonical_content_hash(row["title"], row["summary"], row["source_url"])
    return row


def batch(row):
    return {
        "kind": "LITD_VEILLEUR_DISCOVERY_BATCH",
        "generated_at": "2026-09-12T06:00:00Z",
        "candidates": [row],
        "core_write_allowed": False,
        "automatic_library_write_allowed": False,
    }


def test_general_evidence_becomes_review_candidate_without_core_authority(tmp_path: Path):
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    try:
        report = process_batch(batch(event()), ledger)
        item = report["items"][0]
        assert item["route"] == "GENERAL_LIBRARY"
        assert item["library_candidate"] is True
        assert item["core_write_allowed"] is False
        assert report["ledger_chain_valid"] is True
        assert report["automatic_library_write_allowed"] is False
    finally:
        ledger.close()


def test_litd_specific_evidence_requires_impact_review(tmp_path: Path):
    row = event("LITD Godot decision", "Validated Godot performance change for LITD", ["Godot", "LITD"])
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    try:
        report = process_batch(batch(row), ledger)
        item = report["items"][0]
        assert item["route"] == "LITD_LIBRARY"
        assert item["impact_analysis"]["requires_review"] is True
        assert item["impact_analysis"]["core_change_candidate_allowed"] is False
    finally:
        ledger.close()


def test_duplicate_is_quarantined_on_second_batch(tmp_path: Path):
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    try:
        first = process_batch(batch(event()), ledger)
        second = process_batch(batch(event()), ledger)
        assert first["summary"]["general_library_candidates"] == 1
        assert second["summary"]["duplicates"] == 1
        assert second["items"][0]["route"] == "QUARANTINED"
    finally:
        ledger.close()


def test_invalid_batch_attempting_library_write_fails_closed(tmp_path: Path):
    data = batch(event())
    data["automatic_library_write_allowed"] = True
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    try:
        try:
            process_batch(data, ledger)
            assert False, "expected ValueError"
        except ValueError as exc:
            assert "library authority" in str(exc)
    finally:
        ledger.close()
