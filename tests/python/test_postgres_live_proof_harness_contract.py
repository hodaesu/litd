from pathlib import Path


HARNESS = Path("scripts/governance/run_postgres_receipt_live_proof.sh")


def text() -> str:
    return HARNESS.read_text(encoding="utf-8")


def test_live_proof_requires_explicit_database_url_and_fail_closed_shell():
    body = text()
    assert "set -euo pipefail" in body
    assert "GOVERNANCE_DATABASE_URL" in body
    assert "must point to the real governance PostgreSQL/Supabase database" in body
    assert "psql" in body


def test_live_proof_covers_required_p0_rejection_classes():
    body = text()
    for marker in (
        "replay_detected",
        "project_scope_mismatch",
        "target_route_mismatch",
        "stale_context",
        "receipt_revoked",
        "receipt_superseded",
    ):
        assert marker in body


def test_live_proof_uses_two_independent_concurrent_consumers():
    body = text()
    assert '"worker-a"' in body
    assert '"worker-b"' in body
    assert "PID_A=$!" in body
    assert "PID_B=$!" in body
    assert 'ACCEPT_COUNT' in body
    assert 'REPLAY_COUNT' in body
    assert '[[ "$ACCEPT_COUNT" != "1" || "$REPLAY_COUNT" != "1" ]]' in body


def test_live_proof_checks_client_role_denial_and_audit_chain():
    body = text()
    assert "has_schema_privilege('anon'" in body
    assert "has_table_privilege('authenticated'" in body
    assert "has_function_privilege('anon'" in body
    assert "audit_chain_breaks.txt" in body
    assert "previous_hash <> prior_entry_hash" in body


def test_live_proof_does_not_embed_database_credentials():
    body = text()
    lowered = body.lower()
    assert "postgresql://" not in lowered
    assert "supabase.co" not in lowered
    assert "password=" not in lowered
