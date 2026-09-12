from __future__ import annotations

import threading

import pytest

from tools.quality.governance_replay_registry import GovernanceReplayRegistry


def _fixture(registry: GovernanceReplayRegistry):
    data = {
        "project_id": "LITD",
        "target_route": "LITD_LIBRARY",
        "candidate_hash": "a" * 64,
        "receipt_hash": "b" * 64,
        "critical_context_hash": "c" * 64,
    }
    rid = registry.register(**data)
    return rid, data


def test_single_use_replay_is_refused(tmp_path):
    registry = GovernanceReplayRegistry(tmp_path / "replay.sqlite3")
    rid, data = _fixture(registry)
    first = registry.consume(receipt_id=rid, consumer="guardian", **data)
    second = registry.consume(receipt_id=rid, consumer="guardian", **data)
    assert first.accepted is True
    assert second.accepted is False
    assert second.reason == "receipt_consumed"
    assert registry.verify_audit_chain()


def test_cross_project_and_wrong_route_are_refused(tmp_path):
    registry = GovernanceReplayRegistry(tmp_path / "replay.sqlite3")
    rid, data = _fixture(registry)
    cross = registry.consume(receipt_id=rid, consumer="guardian", **{**data, "project_id": "COMPANY"})
    wrong_route = registry.consume(receipt_id=rid, consumer="guardian", **{**data, "target_route": "COMPANY_LIBRARY"})
    assert cross.accepted is False and cross.reason == "scope_mismatch"
    assert wrong_route.accepted is False and wrong_route.reason == "scope_mismatch"


def test_stale_context_is_refused(tmp_path):
    registry = GovernanceReplayRegistry(tmp_path / "replay.sqlite3")
    rid, data = _fixture(registry)
    result = registry.consume(
        receipt_id=rid,
        consumer="guardian",
        **{**data, "critical_context_hash": "d" * 64},
    )
    assert result.accepted is False
    assert result.reason == "stale_context"


def test_superseded_and_revoked_receipts_are_refused(tmp_path):
    db = tmp_path / "replay.sqlite3"
    registry = GovernanceReplayRegistry(db)
    rid, data = _fixture(registry)
    registry.supersede(rid)
    assert registry.consume(receipt_id=rid, consumer="guardian", **data).reason == "receipt_superseded"

    other = {
        **data,
        "candidate_hash": "e" * 64,
        "receipt_hash": "f" * 64,
    }
    rid2 = registry.register(**other)
    registry.revoke(rid2)
    assert registry.consume(receipt_id=rid2, consumer="guardian", **other).reason == "receipt_revoked"


def test_binding_substitution_is_refused(tmp_path):
    registry = GovernanceReplayRegistry(tmp_path / "replay.sqlite3")
    rid, data = _fixture(registry)
    result = registry.consume(
        receipt_id=rid,
        consumer="guardian",
        **{**data, "candidate_hash": "9" * 64},
    )
    assert result.accepted is False
    assert result.reason == "binding_mismatch"


def test_only_one_concurrent_consumer_wins(tmp_path):
    db = tmp_path / "replay.sqlite3"
    setup = GovernanceReplayRegistry(db)
    rid, data = _fixture(setup)
    setup.close()

    barrier = threading.Barrier(2)
    results = []
    errors = []

    def worker(name: str):
        registry = GovernanceReplayRegistry(db)
        try:
            barrier.wait()
            results.append(registry.consume(receipt_id=rid, consumer=name, **data))
        except Exception as exc:  # pragma: no cover - diagnostic guard
            errors.append(exc)
        finally:
            registry.close()

    threads = [threading.Thread(target=worker, args=(f"consumer-{i}",)) for i in range(2)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    assert errors == []
    assert sum(result.accepted for result in results) == 1
    assert sorted(result.reason for result in results) == ["accepted", "receipt_consumed"]

    verify = GovernanceReplayRegistry(db)
    assert verify.verify_audit_chain()
    assert verify.connection.execute("SELECT COUNT(*) FROM replay_audit").fetchone()[0] == 2


def test_audit_log_is_append_only(tmp_path):
    registry = GovernanceReplayRegistry(tmp_path / "replay.sqlite3")
    rid, data = _fixture(registry)
    registry.consume(receipt_id=rid, consumer="guardian", **data)
    with pytest.raises(Exception):
        registry.connection.execute("DELETE FROM replay_audit")
