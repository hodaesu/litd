import sqlite3
from pathlib import Path

import pytest

from tools.quality.evidence_ledger import EvidenceLedger


def test_evidence_persists_across_reopen(tmp_path: Path):
    db = tmp_path / "ledger.sqlite3"
    ledger = EvidenceLedger(db)
    ledger.register_evidence("EV-001", "a" * 64, "https://example.com/source")
    ledger.close()

    reopened = EvidenceLedger(db)
    assert "EV-001" in reopened.known_evidence_ids()
    assert "a" * 64 in reopened.known_hashes()
    reopened.close()


def test_duplicate_ids_and_hashes_are_visible(tmp_path: Path):
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    ledger.register_evidence("EV-001", "b" * 64, "https://example.com/source")
    assert ledger.known_evidence_ids() == {"EV-001"}
    assert ledger.known_hashes() == {"b" * 64}
    ledger.close()


def test_ledger_rejects_cross_project_or_route_scope(tmp_path: Path):
    with pytest.raises(ValueError, match="project scope mismatch"):
        EvidenceLedger(tmp_path / "company.sqlite3", project_id="COMPANY", target_route="COMPANY_LIBRARY")
    with pytest.raises(ValueError, match="route scope mismatch"):
        EvidenceLedger(tmp_path / "wrong-route.sqlite3", project_id="LITD", target_route="GENERAL_LIBRARY")


def test_scope_is_persisted_with_evidence(tmp_path: Path):
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    ledger.register_evidence("EV-001", "c" * 64, "https://example.com/source")
    row = ledger.connection.execute(
        "SELECT project_id, target_route FROM evidence_registry WHERE evidence_id='EV-001'"
    ).fetchone()
    assert row["project_id"] == "LITD"
    assert row["target_route"] == "LITD_LIBRARY"
    ledger.close()


def test_decision_chain_is_valid():
    pass


def test_decision_chain_is_valid(tmp_path: Path):
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    first = ledger.append_decision("EV-001", "ACCEPTED_FOR_ROUTING", "validated")
    second = ledger.append_decision("EV-001", "LITD_LIBRARY", "litd_specific_knowledge")
    assert first.previous_hash == "GENESIS"
    assert second.previous_hash == first.entry_hash
    assert ledger.verify_chain() is True
    ledger.close()


def test_decision_ledger_rejects_updates(tmp_path: Path):
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    ledger.append_decision("EV-001", "QUARANTINED", "source_not_verified")
    try:
        ledger.connection.execute("UPDATE decision_ledger SET reason='tampered' WHERE sequence=1")
    except sqlite3.DatabaseError as exc:
        assert "append_only" in str(exc)
    else:
        raise AssertionError("decision ledger update unexpectedly succeeded")
    ledger.close()


def test_decision_ledger_rejects_deletes(tmp_path: Path):
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    ledger.append_decision("EV-001", "REJECTED", "content_hash_mismatch")
    try:
        ledger.connection.execute("DELETE FROM decision_ledger WHERE sequence=1")
    except sqlite3.DatabaseError as exc:
        assert "append_only" in str(exc)
    else:
        raise AssertionError("decision ledger delete unexpectedly succeeded")
    ledger.close()


def test_chain_detects_tampering_even_if_triggers_are_bypassed(tmp_path: Path):
    db = tmp_path / "ledger.sqlite3"
    ledger = EvidenceLedger(db)
    ledger.append_decision("EV-001", "ACCEPTED_FOR_ROUTING", "validated")
    ledger.close()

    raw = sqlite3.connect(db)
    raw.execute("DROP TRIGGER decision_ledger_no_update")
    raw.execute("UPDATE decision_ledger SET reason='tampered' WHERE sequence=1")
    raw.commit()
    raw.close()

    reopened = EvidenceLedger(db)
    assert reopened.verify_chain() is False
    reopened.close()


def test_chain_detects_project_scope_tampering(tmp_path: Path):
    db = tmp_path / "ledger.sqlite3"
    ledger = EvidenceLedger(db)
    ledger.append_decision("EV-001", "ACCEPTED_FOR_ROUTING", "validated")
    ledger.close()

    raw = sqlite3.connect(db)
    raw.execute("DROP TRIGGER decision_ledger_no_update")
    raw.execute("UPDATE decision_ledger SET project_id='COMPANY' WHERE sequence=1")
    raw.commit()
    raw.close()

    reopened = EvidenceLedger(db)
    assert reopened.verify_chain() is False
    reopened.close()
