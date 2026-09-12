from datetime import datetime, timezone
from pathlib import Path
from tools.quality.autonomous_veilleur import run
from tools.quality.evidence_ledger import EvidenceLedger
from tools.quality.veilleur_triage import process_batch
from tools.quality.veilleur_library_review import build_review_batch

ATOM=b'''<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Godot LITD update</title><link rel="alternate" href="https://example.com/r1"/><published>2026-09-12T05:00:00Z</published><summary>Validated Godot performance change for LITD.</summary></entry></feed>'''

def registry():
    return {"kind":"LITD_VEILLEUR_SOURCE_REGISTRY","version":1,"policy":{"unknown_source_action":"QUARANTINE","unverified_source_action":"QUARANTINE","core_write_allowed":False,"automatic_library_write_allowed":False,"max_response_bytes":100000,"timeout_seconds":5},"sources":[{"source_id":"example","name":"Example","enabled":True,"trust":"TRUSTED_PRIMARY","format":"atom","url":"https://example.com/feed.atom","allowed_host":"example.com","domain_hints":["Godot","LITD","performance"],"source_confidence":0.95}]}

def test_end_to_end_discovery_triage_review_remains_governed(tmp_path:Path):
    def fetcher(source,timeout,max_bytes): return ATOM
    discovery=run(registry(),fetcher=fetcher,now=datetime(2026,9,12,6,tzinfo=timezone.utc))
    ledger=EvidenceLedger(tmp_path/"ledger.sqlite3")
    try: triage=process_batch(discovery,ledger)
    finally: ledger.close()
    review=build_review_batch(triage)
    assert discovery["candidate_count"]==1
    assert triage["items"][0]["route"]=="LITD_LIBRARY"
    assert review["summary"]["core_reviews_required"]==1
    assert review["items"][0]["contradiction"]["status"]=="REVIEW_REQUIRED"
    assert review["core_write_allowed"] is False
    assert review["automatic_library_write_allowed"] is False
