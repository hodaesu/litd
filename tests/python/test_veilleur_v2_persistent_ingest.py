from pathlib import Path

from tools.quality.evidence_ledger import EvidenceLedger
from tools.quality.veilleur_v2_ingest import canonical_content_hash, validate_and_record


def _event(evidence_id: str = "EV-001") -> dict:
    title = "Godot optimization note"
    summary = "A verified performance technique relevant to procedural generation."
    source_url = "https://example.com/source"
    return {
        "evidence_id": evidence_id,
        "title": title,
        "summary": summary,
        "source_url": source_url,
        "source_verified": True,
        "source_confidence": 0.9,
        "discovered_at": "2026-09-10T18:00:00Z",
        "published_at": "2026-09-10T17:00:00Z",
        "domain_hints": ["godot", "performance"],
        "content_hash": canonical_content_hash(title, summary, source_url),
    }


def test_first_ingest_is_persisted(tmp_path: Path):
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    decision = validate_and_record(_event(), ledger)
    assert decision.accepted is True
    assert "EV-001" in ledger.known_evidence_ids()
    assert ledger.verify_chain() is True
    ledger.close()


def test_duplicate_is_detected_after_database_reopen(tmp_path: Path):
    db = tmp_path / "ledger.sqlite3"
    first = EvidenceLedger(db)
    assert validate_and_record(_event(), first).accepted is True
    first.close()

    reopened = EvidenceLedger(db)
    duplicate = validate_and_record(_event(), reopened)
    assert duplicate.accepted is False
    assert duplicate.status == "DUPLICATE"
    assert duplicate.reason == "duplicate_evidence_id"
    assert reopened.verify_chain() is True
    reopened.close()


def test_same_content_new_id_is_still_duplicate_after_reopen(tmp_path: Path):
    db = tmp_path / "ledger.sqlite3"
    first = EvidenceLedger(db)
    validate_and_record(_event("EV-001"), first)
    first.close()

    reopened = EvidenceLedger(db)
    duplicate = validate_and_record(_event("EV-002"), reopened)
    assert duplicate.status == "DUPLICATE"
    assert duplicate.reason == "duplicate_canonical_content"
    reopened.close()


def test_rejected_attempt_is_audited_but_not_registered(tmp_path: Path):
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    event = _event()
    event["content_hash"] = "0" * 64
    decision = validate_and_record(event, ledger)
    assert decision.status == "REJECTED"
    assert ledger.known_evidence_ids() == set()
    assert ledger.verify_chain() is True
    row = ledger.connection.execute("SELECT decision, reason FROM decision_ledger").fetchone()
    assert tuple(row) == ("REJECTED", "content_hash_mismatch")
    ledger.close()
