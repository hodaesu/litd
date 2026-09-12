from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest

from tools.quality.receipt_consumption_registry import ReceiptConsumptionRegistry

RECEIPT_HASH = "a" * 64
SOURCE_HASH = "b" * 64
CONTEXT_HASH = "c" * 64
REPLACEMENT_HASH = "d" * 64


def register(path: Path, *, expected_consumer: str = "GUARDIAN_CHANGE_GATE") -> None:
    registry = ReceiptConsumptionRegistry(path)
    try:
        registry.register_receipt(
            receipt_id="receipt:test:1",
            receipt_hash=RECEIPT_HASH,
            receipt_kind="LITD_VEILLEUR_REVIEW_RESOLUTION_RECEIPT",
            source_hash=SOURCE_HASH,
            context_hash=CONTEXT_HASH,
            expected_consumer=expected_consumer,
        )
    finally:
        registry.close()


def test_receipt_can_be_consumed_exactly_once(tmp_path: Path):
    db = tmp_path / "receipts.sqlite3"
    register(db)
    registry = ReceiptConsumptionRegistry(db)
    try:
        first = registry.consume(
            RECEIPT_HASH,
            consumer="GUARDIAN_CHANGE_GATE",
            actor="guardian-1",
            current_context_hash=CONTEXT_HASH,
        )
        second = registry.consume(
            RECEIPT_HASH,
            consumer="GUARDIAN_CHANGE_GATE",
            actor="guardian-2",
            current_context_hash=CONTEXT_HASH,
        )
        assert first.accepted is True
        assert first.reason == "consumed_once"
        assert second.accepted is False
        assert second.reason == "replay_detected"
        assert registry.consumption_count(RECEIPT_HASH) == 1
        assert registry.verify_audit_chain() is True
    finally:
        registry.close()


def test_concurrent_double_consumption_allows_one_winner(tmp_path: Path):
    db = tmp_path / "concurrent.sqlite3"
    register(db)

    def attempt(index: int):
        registry = ReceiptConsumptionRegistry(db)
        try:
            return registry.consume(
                RECEIPT_HASH,
                consumer="GUARDIAN_CHANGE_GATE",
                actor=f"worker-{index}",
                current_context_hash=CONTEXT_HASH,
            )
        finally:
            registry.close()

    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(attempt, range(8)))

    assert sum(result.accepted for result in results) == 1
    assert sum(result.reason == "replay_detected" for result in results) == 7
    registry = ReceiptConsumptionRegistry(db)
    try:
        assert registry.consumption_count(RECEIPT_HASH) == 1
        assert registry.verify_audit_chain() is True
    finally:
        registry.close()


def test_wrong_consumer_is_rejected_without_consuming(tmp_path: Path):
    db = tmp_path / "wrong-consumer.sqlite3"
    register(db)
    registry = ReceiptConsumptionRegistry(db)
    try:
        result = registry.consume(
            RECEIPT_HASH,
            consumer="APPLICATION_DECISION_GATE",
            actor="hostile-consumer",
            current_context_hash=CONTEXT_HASH,
        )
        assert result.accepted is False
        assert result.reason == "unexpected_consumer"
        assert registry.consumption_count(RECEIPT_HASH) == 0
    finally:
        registry.close()


def test_stale_context_is_rejected_without_consuming(tmp_path: Path):
    db = tmp_path / "stale.sqlite3"
    register(db)
    registry = ReceiptConsumptionRegistry(db)
    try:
        result = registry.consume(
            RECEIPT_HASH,
            consumer="GUARDIAN_CHANGE_GATE",
            actor="guardian",
            current_context_hash="e" * 64,
        )
        assert result.accepted is False
        assert result.reason == "stale_context"
        assert registry.consumption_count(RECEIPT_HASH) == 0
    finally:
        registry.close()


def test_revoked_receipt_is_rejected(tmp_path: Path):
    db = tmp_path / "revoked.sqlite3"
    register(db)
    registry = ReceiptConsumptionRegistry(db)
    try:
        registry.invalidate_receipt(
            RECEIPT_HASH,
            kind="REVOKED",
            reason="Evidence provenance was invalidated after review.",
            actor="governance-admin",
        )
        result = registry.consume(
            RECEIPT_HASH,
            consumer="GUARDIAN_CHANGE_GATE",
            actor="guardian",
            current_context_hash=CONTEXT_HASH,
        )
        assert result.accepted is False
        assert result.reason == "receipt_revoked"
        assert registry.consumption_count(RECEIPT_HASH) == 0
    finally:
        registry.close()


def test_superseded_receipt_is_rejected(tmp_path: Path):
    db = tmp_path / "superseded.sqlite3"
    register(db)
    registry = ReceiptConsumptionRegistry(db)
    try:
        registry.invalidate_receipt(
            RECEIPT_HASH,
            kind="SUPERSEDED",
            reason="A newer governed receipt replaces this one.",
            actor="governance-admin",
            replacement_receipt_hash=REPLACEMENT_HASH,
        )
        result = registry.consume(
            RECEIPT_HASH,
            consumer="GUARDIAN_CHANGE_GATE",
            actor="guardian",
            current_context_hash=CONTEXT_HASH,
        )
        assert result.accepted is False
        assert result.reason == "receipt_superseded"
    finally:
        registry.close()


def test_cross_project_registry_is_refused_before_access(tmp_path: Path):
    with pytest.raises(ValueError, match="project scope mismatch"):
        ReceiptConsumptionRegistry(tmp_path / "cross.sqlite3", project_id="COMPANY")


def test_cross_route_registry_is_refused_before_access(tmp_path: Path):
    with pytest.raises(ValueError, match="route scope mismatch"):
        ReceiptConsumptionRegistry(tmp_path / "cross-route.sqlite3", target_route="COMPANY_LIBRARY")


def test_append_only_tables_reject_mutation(tmp_path: Path):
    db = tmp_path / "append-only.sqlite3"
    register(db)
    registry = ReceiptConsumptionRegistry(db)
    try:
        registry.consume(
            RECEIPT_HASH,
            consumer="GUARDIAN_CHANGE_GATE",
            actor="guardian",
            current_context_hash=CONTEXT_HASH,
        )
        with pytest.raises(Exception, match="receipt_consumptions_append_only"):
            registry.connection.execute(
                "UPDATE receipt_consumptions SET actor='tampered' WHERE receipt_hash=?",
                (RECEIPT_HASH,),
            )
        with pytest.raises(Exception, match="consumption_audit_append_only"):
            registry.connection.execute("DELETE FROM consumption_audit")
    finally:
        registry.close()


def test_audit_tampering_is_detected_if_trigger_is_bypassed(tmp_path: Path):
    db = tmp_path / "tamper.sqlite3"
    register(db)
    registry = ReceiptConsumptionRegistry(db)
    try:
        registry.consume(
            RECEIPT_HASH,
            consumer="GUARDIAN_CHANGE_GATE",
            actor="guardian",
            current_context_hash=CONTEXT_HASH,
        )
        registry.connection.execute("DROP TRIGGER consumption_audit_no_update")
        registry.connection.execute("UPDATE consumption_audit SET reason='tampered' WHERE sequence=1")
        assert registry.verify_audit_chain() is False
    finally:
        registry.close()
