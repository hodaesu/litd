from datetime import datetime, timezone

from tools.quality.autonomous_veilleur import parse_feed, run
from tools.quality.source_registry import enabled_sources, validate_registry


def registry():
    return {
        "kind": "LITD_VEILLEUR_SOURCE_REGISTRY",
        "version": 1,
        "policy": {
            "unknown_source_action": "QUARANTINE",
            "unverified_source_action": "QUARANTINE",
            "core_write_allowed": False,
            "automatic_library_write_allowed": False,
            "max_response_bytes": 100000,
            "timeout_seconds": 5,
        },
        "sources": [
            {
                "source_id": "example",
                "name": "Example primary",
                "enabled": True,
                "trust": "TRUSTED_PRIMARY",
                "format": "atom",
                "url": "https://example.com/feed.atom",
                "allowed_host": "example.com",
                "allowed_item_hosts": ["example.com"],
                "domain_hints": ["Godot"],
                "source_confidence": 0.9,
            }
        ],
    }


ATOM = b'''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <title>Release 1</title>
    <link rel="alternate" href="https://example.com/release-1" />
    <published>2026-09-11T10:00:00Z</published>
    <summary>Important fixes and performance improvements.</summary>
  </entry>
</feed>'''

RSS = b'''<?xml version="1.0"?>
<rss version="2.0"><channel><item>
<title>Python update</title>
<link>https://example.com/python-update</link>
<pubDate>Fri, 11 Sep 2026 10:00:00 GMT</pubDate>
<description>Security and runtime improvements.</description>
</item></channel></rss>'''


def test_registry_accepts_explicit_trusted_https_source():
    assert validate_registry(registry()) == []
    assert len(enabled_sources(registry())) == 1


def test_registry_rejects_enabled_untrusted_source():
    data = registry()
    data["sources"][0]["trust"] = "UNVERIFIED"
    assert any("enabled_source_not_trusted" in e for e in validate_registry(data))


def test_registry_rejects_host_mismatch():
    data = registry()
    data["sources"][0]["allowed_host"] = "evil.example"
    assert any("host_mismatch" in e for e in validate_registry(data))


def test_atom_feed_emits_ingress_compatible_event():
    source = registry()["sources"][0]
    events = parse_feed(ATOM, source, "2026-09-11T12:00:00Z")
    assert len(events) == 1
    assert events[0]["source_verified"] is True
    assert events[0]["source_url"] == "https://example.com/release-1"
    assert len(events[0]["content_hash"]) == 64


def test_rss_feed_supports_rfc822_publication_date():
    source = registry()["sources"][0].copy()
    source["format"] = "rss"
    events = parse_feed(RSS, source, "2026-09-11T12:00:00Z")
    assert events[0]["published_at"] == "2026-09-11T10:00:00Z"


def test_run_is_read_only_and_routes_to_ingress_next():
    def fake_fetch(source, timeout, max_bytes):
        assert timeout == 5
        assert max_bytes == 100000
        return ATOM

    report = run(registry(), fetcher=fake_fetch, now=datetime(2026, 9, 11, 12, tzinfo=timezone.utc))
    assert report["status"] == "OK"
    assert report["candidate_count"] == 1
    assert report["core_write_allowed"] is False
    assert report["automatic_library_write_allowed"] is False
    assert report["next_stage"] == "VEILLEUR_V2_INGRESS_AND_TRIAGE"


def test_fetch_failure_is_reported_not_silently_accepted():
    def failing_fetch(source, timeout, max_bytes):
        raise RuntimeError("network down")

    report = run(registry(), fetcher=failing_fetch)
    assert report["status"] == "FAILED"
    assert report["successful_source_count"] == 0
    assert report["candidate_count"] == 0
    assert report["failure_count"] == 1
    assert "network down" in report["failures"][0]["reason"]


def test_feed_item_link_outside_allowlist_is_rejected():
    source = registry()["sources"][0]
    payload = ATOM.replace(b"https://example.com/release-1", b"https://evil.example/release-1")
    try:
        parse_feed(payload, source, "2026-09-11T12:00:00Z")
        assert False, "expected off-domain item link rejection"
    except ValueError as exc:
        assert "allowed host policy" in str(exc)


def test_registry_rejects_missing_item_host_allowlist():
    data = registry()
    del data["sources"][0]["allowed_item_hosts"]
    assert any("invalid_allowed_item_hosts" in e for e in validate_registry(data))
