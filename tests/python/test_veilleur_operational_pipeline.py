from datetime import datetime, timezone
from pathlib import Path

import pytest

from tools.quality.autonomous_veilleur import parse_feed, run
from tools.quality.evidence_ledger import EvidenceLedger
from tools.quality.veilleur_triage import process_batch
from tools.quality.veilleur_library_review import build_review_batch
from tools.quality.source_registry import validate_registry

ATOM=b'''<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Godot LITD update</title><link rel="alternate" href="https://example.com/r1"/><published>2026-09-12T05:00:00Z</published><summary>Validated Godot performance change for LITD.</summary></entry></feed>'''

def registry():
    return {"kind":"LITD_VEILLEUR_SOURCE_REGISTRY","version":1,"policy":{"unknown_source_action":"QUARANTINE","unverified_source_action":"QUARANTINE","core_write_allowed":False,"automatic_library_write_allowed":False,"max_response_bytes":100000,"timeout_seconds":5},"sources":[{"source_id":"example","name":"Example","enabled":True,"trust":"TRUSTED_PRIMARY","format":"atom","url":"https://example.com/feed.atom","allowed_host":"example.com","allowed_item_hosts":["example.com"],"domain_hints":["Godot","LITD","performance"],"source_confidence":0.95}]}

def test_end_to_end_discovery_triage_review_remains_governed(tmp_path:Path):
    def fetcher(source,timeout,max_bytes): return ATOM
    discovery=run(registry(),fetcher=fetcher,now=datetime(2026,9,12,6,tzinfo=timezone.utc))
    assert discovery["project_id"] == "LITD"
    assert discovery["target_route"] == "LITD_LIBRARY"
    assert discovery["candidates"][0]["project_id"] == "LITD"
    assert discovery["candidates"][0]["target_route"] == "LITD_LIBRARY"
    ledger=EvidenceLedger(tmp_path/"ledger.sqlite3")
    try: triage=process_batch(discovery,ledger)
    finally: ledger.close()
    assert triage["project_id"] == "LITD"
    assert triage["target_route"] == "LITD_LIBRARY"
    review=build_review_batch(triage)
    assert discovery["candidate_count"]==1
    assert triage["items"][0]["route"]=="LITD_LIBRARY"
    assert review["summary"]["core_reviews_required"]==1
    assert review["items"][0]["contradiction"]["status"]=="REVIEW_REQUIRED"
    assert review["core_write_allowed"] is False
    assert review["automatic_library_write_allowed"] is False


def test_cross_project_batch_is_rejected_before_ledger_append(tmp_path: Path):
    discovery = run(registry(), fetcher=lambda source, timeout, max_bytes: ATOM)
    discovery["project_id"] = "COMPANY"
    discovery["target_route"] = "COMPANY_LIBRARY"
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    try:
        before = ledger.connection.execute("SELECT COUNT(*) FROM decision_ledger").fetchone()[0]
        with pytest.raises(ValueError, match="project scope mismatch"):
            process_batch(discovery, ledger)
        after = ledger.connection.execute("SELECT COUNT(*) FROM decision_ledger").fetchone()[0]
        assert after == before
    finally:
        ledger.close()


def test_wrong_route_batch_is_rejected_before_ledger_append(tmp_path: Path):
    discovery = run(registry(), fetcher=lambda source, timeout, max_bytes: ATOM)
    discovery["target_route"] = "GENERAL_LIBRARY"
    ledger = EvidenceLedger(tmp_path / "ledger.sqlite3")
    try:
        before = ledger.connection.execute("SELECT COUNT(*) FROM decision_ledger").fetchone()[0]
        with pytest.raises(ValueError, match="route scope mismatch"):
            process_batch(discovery, ledger)
        after = ledger.connection.execute("SELECT COUNT(*) FROM decision_ledger").fetchone()[0]
        assert after == before
    finally:
        ledger.close()


def test_total_source_outage_fails_closed():
    def failing_fetch(source, timeout, max_bytes):
        raise RuntimeError("network down")
    report = run(registry(), fetcher=failing_fetch)
    assert report["status"] == "FAILED"
    assert report["successful_source_count"] == 0
    assert report["candidate_count"] == 0


def test_feed_item_outside_allowlist_is_rejected():
    source = registry()["sources"][0]
    hostile = ATOM.replace(b"https://example.com/r1", b"https://evil.example/r1")
    try:
        parse_feed(hostile, source, "2026-09-12T06:00:00Z")
        assert False, "expected off-domain item rejection"
    except ValueError as exc:
        assert "allowed host policy" in str(exc)


def test_enabled_source_requires_item_host_allowlist():
    data = registry()
    del data["sources"][0]["allowed_item_hosts"]
    assert any("invalid_allowed_item_hosts" in error for error in validate_registry(data))


def test_tampered_restored_ledger_is_rejected_before_append(tmp_path: Path):
    ledger = EvidenceLedger(tmp_path / "tampered.sqlite3")
    try:
        ledger.append_decision("existing", "ACCEPTED_FOR_ROUTING", "validated")
        before = ledger.connection.execute("SELECT COUNT(*) FROM decision_ledger").fetchone()[0]
        ledger.connection.execute("DROP TRIGGER decision_ledger_no_update")
        ledger.connection.execute("UPDATE decision_ledger SET reason='tampered' WHERE sequence=1")
        ledger.connection.commit()
        discovery = run(registry(), fetcher=lambda source, timeout, max_bytes: ATOM)
        try:
            process_batch(discovery, ledger)
            assert False, "expected ledger verification failure"
        except ValueError as exc:
            assert "restored evidence ledger chain verification failed" in str(exc)
        after = ledger.connection.execute("SELECT COUNT(*) FROM decision_ledger").fetchone()[0]
        assert after == before
    finally:
        ledger.close()
