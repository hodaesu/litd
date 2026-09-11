from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys

MODULE_PATH = Path(__file__).resolve().parents[2] / "tools" / "quality" / "veilleur_v2_ingest.py"
spec = spec_from_file_location("veilleur_v2_ingest", MODULE_PATH)
module = module_from_spec(spec)
assert spec and spec.loader
sys.modules[spec.name] = module
spec.loader.exec_module(module)

canonical_content_hash = module.canonical_content_hash
validate_event = module.validate_event
can_write_core = module.can_write_core


def make_event():
    title = "Godot release note"
    summary = "A verified upstream release changes renderer behaviour."
    url = "https://godotengine.org/article/example"
    return {
        "evidence_id": "EV-001",
        "title": title,
        "summary": summary,
        "source_url": url,
        "source_verified": True,
        "source_confidence": 0.95,
        "discovered_at": "2026-09-10T18:00:00Z",
        "published_at": "2026-09-10T16:00:00Z",
        "domain_hints": ["godot", "programming"],
        "content_hash": canonical_content_hash(title, summary, url),
    }


def test_valid_event_is_accepted_for_routing():
    decision = validate_event(make_event())
    assert decision.accepted is True
    assert decision.status == "ACCEPTED_FOR_ROUTING"


def test_missing_required_field_is_rejected():
    event = make_event()
    del event["source_url"]
    decision = validate_event(event)
    assert decision.accepted is False
    assert decision.status == "REJECTED"


def test_unverified_source_is_quarantined():
    event = make_event()
    event["source_verified"] = False
    decision = validate_event(event)
    assert decision.status == "QUARANTINED"


def test_hash_mismatch_is_rejected():
    event = make_event()
    event["content_hash"] = "0" * 64
    decision = validate_event(event)
    assert decision.status == "REJECTED"
    assert decision.reason == "content_hash_mismatch"


def test_duplicate_evidence_id_is_blocked():
    event = make_event()
    decision = validate_event(event, known_evidence_ids={"EV-001"})
    assert decision.status == "DUPLICATE"


def test_duplicate_canonical_hash_is_blocked():
    event = make_event()
    decision = validate_event(event, known_hashes={event["content_hash"]})
    assert decision.status == "DUPLICATE"


def test_non_https_source_is_rejected():
    event = make_event()
    event["source_url"] = "http://example.com/source"
    event["content_hash"] = canonical_content_hash(event["title"], event["summary"], event["source_url"])
    decision = validate_event(event)
    assert decision.status == "REJECTED"
    assert decision.reason == "invalid_or_unencrypted_source_url"


def test_invalid_timestamp_is_rejected():
    event = make_event()
    event["published_at"] = "yesterday"
    decision = validate_event(event)
    assert decision.status == "REJECTED"


def test_ingress_gate_never_authorizes_core_write():
    decision = validate_event(make_event())
    assert can_write_core(decision) is False
