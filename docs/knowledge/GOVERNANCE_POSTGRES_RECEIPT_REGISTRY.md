# Durable governance receipt registry — PostgreSQL/Supabase

Status: P0 implementation step for #331. This document does **not** mark #331 closed.

## Purpose

The SQLite registry merged in #341 is the executable contract prototype. The durable target is PostgreSQL/Supabase with the same fail-closed semantics and with cross-process concurrency handled inside the database transaction.

## Durable invariants

- receipts are immutable and uniquely identified by lowercase SHA-256 hashes;
- project identity and target route are persisted with every registered receipt;
- expected consumer and critical-context hash are bound at registration time;
- receipt consumption is atomic and single-use;
- identical or concurrent replays are rejected;
- stale context, wrong consumer, wrong project, wrong route, revocation and supersession are rejected;
- accepted and rejected attempts are written to an append-only hash-chained audit log;
- audit-chain insertion is globally serialized to prevent forks under concurrent writes;
- tables are not exposed directly to `anon` or `authenticated` clients;
- mutations are performed only through restricted server-side database functions;
- privileged functions pin `search_path=''` and schema-qualify referenced objects;
- no Core write, merge, application, rollback or target-mutation authority is granted by this registry.

## Migration

Canonical migration:

`supabase/migrations/20260912162000_governance_receipt_registry.sql`

It creates the private schema `governance_private`, four append-only tables, restricted registration/invalidation/consumption functions, per-receipt transaction serialization, and serialized audit-chain insertion.

## Security boundary

The migration revokes direct table access from `public`, `anon`, `authenticated`, and `service_role`, then grants only schema usage plus explicit function execution to `service_role`. The service role must remain server-side. No browser/client key may invoke or mutate the registry.

The schema is intentionally outside the exposed `public` schema. Row-level security is enabled as defense in depth, but the primary interface is the restricted function surface rather than direct table CRUD.

## What remains before #331 can close

1. Apply this migration to the real Supabase/PostgreSQL governance project.
2. Run database-level allow/deny, replay, stale, revoked, superseded and concurrent-consumption tests against the real database.
3. Prove exactly one winner under concurrent transactions from separate connections/workers.
4. Propagate single-use consumption through every remaining authority-bearing transition after Guardian.
5. Bind the durable audit hash into downstream receipts and provenance evidence.
6. Preserve deployment/test evidence and verify recovery/backup behavior.
7. Verify equivalent project isolation for COMPANY and future projects in the shared registry.

Until those steps are evidenced, SQLite and the repository migration are contract/provisioning artifacts, not proof of production enforcement.
