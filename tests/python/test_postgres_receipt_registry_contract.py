from pathlib import Path


MIGRATION = Path("infra/supabase/migrations/20260912_governance_receipt_registry.sql")


def sql() -> str:
    return MIGRATION.read_text(encoding="utf-8")


def test_postgres_registry_is_project_and_route_bound():
    text = sql()
    assert "project_id text not null" in text
    assert "target_route text not null" in text
    assert "candidate_hash text not null" in text
    assert "source_hash text not null" in text
    assert "context_hash text not null" in text
    assert "expected_consumer text not null" in text


def test_receipt_consumption_is_single_use_and_concurrency_safe():
    text = sql()
    assert "receipt_hash text not null unique references governance.receipts(receipt_hash)" in text
    assert "for update;" in text
    assert "on conflict (receipt_hash) do nothing" in text
    assert "replay_detected" in text
    assert "consumed_once" in text


def test_revocation_and_supersession_are_append_only():
    text = sql()
    assert "receipt_invalidation_kind as enum ('REVOKED', 'SUPERSEDED')" in text
    assert "receipt_invalidations_append_only" in text
    assert "receipt_superseded" in text
    assert "receipt_revoked" in text
    assert "before update or delete on governance.receipt_invalidations" in text


def test_receipts_consumptions_and_audit_cannot_be_mutated():
    text = sql()
    for trigger in (
        "receipts_append_only",
        "receipt_consumptions_append_only",
        "receipt_consumption_audit_append_only",
    ):
        assert trigger in text
    assert text.count("before update or delete") >= 4
    assert "raise exception 'append_only_relation'" in text


def test_every_rejection_class_is_auditable():
    text = sql()
    for reason in (
        "invalid_request",
        "unknown_receipt",
        "project_scope_mismatch",
        "route_scope_mismatch",
        "candidate_hash_mismatch",
        "unexpected_consumer",
        "stale_context",
        "receipt_superseded",
        "receipt_revoked",
        "replay_detected",
    ):
        assert reason in text
    assert "create table if not exists governance.receipt_consumption_audit" in text


def test_public_and_client_roles_have_no_direct_governance_access():
    text = sql()
    assert "revoke all on schema governance from public" in text
    assert "revoke all on schema governance from anon" in text
    assert "revoke all on schema governance from authenticated" in text
    assert "revoke all on all tables in schema governance from public, anon, authenticated" in text
    assert "revoke all on function governance.consume_receipt_once" in text


def test_invalid_hash_inputs_are_failed_closed_before_lookup():
    text = sql()
    assert "coalesce(p_receipt_hash, '') !~ '^[0-9a-f]{64}$'" in text
    assert "coalesce(p_candidate_hash, '') !~ '^[0-9a-f]{64}$'" in text
    assert "coalesce(p_current_context_hash, '') !~ '^[0-9a-f]{64}$'" in text
