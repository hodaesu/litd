from pathlib import Path


MIGRATION = Path("supabase/migrations/20260912162000_governance_receipt_registry.sql")


def _sql() -> str:
    return MIGRATION.read_text(encoding="utf-8")


def test_postgres_registry_contract_is_present() -> None:
    sql = _sql()
    assert "create schema if not exists governance_private" in sql
    assert "create table if not exists governance_private.registered_receipts" in sql
    assert "create table if not exists governance_private.receipt_consumptions" in sql
    assert "create table if not exists governance_private.receipt_invalidations" in sql
    assert "create table if not exists governance_private.consumption_audit" in sql


def test_single_use_consumption_is_serialized_and_unique() -> None:
    sql = _sql()
    assert "receipt_hash text primary key references governance_private.registered_receipts(receipt_hash)" in sql
    assert "pg_advisory_xact_lock(pg_catalog.hashtext(p_receipt_hash))" in sql
    assert "replay_detected" in sql
    assert "consumed_once" in sql


def test_scope_context_and_invalidation_are_fail_closed() -> None:
    sql = _sql()
    for token in (
        "project_scope_mismatch",
        "target_route_mismatch",
        "unexpected_consumer",
        "stale_context",
        "receipt_",
        "REVOKED",
        "SUPERSEDED",
    ):
        assert token in sql


def test_audit_chain_is_serialized_and_sha256_linked() -> None:
    sql = _sql()
    assert "pg_advisory_xact_lock(33120260912)" in sql
    assert "previous_hash" in sql
    assert "extensions.digest" in sql
    assert "'sha256'" in sql
    assert "entry_hash text not null unique" in sql


def test_append_only_tables_reject_update_and_delete() -> None:
    sql = _sql()
    assert "reject_append_only_mutation" in sql
    assert sql.count("before update or delete") >= 4


def test_supabase_exposure_is_restricted_to_server_role_functions() -> None:
    sql = _sql()
    assert "revoke all on schema governance_private from public, anon, authenticated" in sql
    assert "revoke all on all tables in schema governance_private from public, anon, authenticated, service_role" in sql
    assert "security definer" in sql
    assert "set search_path = ''" in sql
    assert "grant execute on function governance_private.consume_receipt" in sql
    assert "to service_role" in sql
