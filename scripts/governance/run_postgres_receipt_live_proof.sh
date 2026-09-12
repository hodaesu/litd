#!/usr/bin/env bash
set -euo pipefail

: "${GOVERNANCE_DATABASE_URL:?GOVERNANCE_DATABASE_URL must point to the real governance PostgreSQL/Supabase database}"

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required" >&2
  exit 2
fi

EVIDENCE_DIR="${GOVERNANCE_EVIDENCE_DIR:-artifacts/governance-postgres-proof/$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$EVIDENCE_DIR"
chmod 700 "$EVIDENCE_DIR"

hash_for() {
  python3 - "$1" <<'PY'
import hashlib, sys
print(hashlib.sha256(sys.argv[1].encode("utf-8")).hexdigest())
PY
}

RUN_ID="$(date -u +%Y%m%dT%H%M%S)-$$"
SOURCE_HASH="$(hash_for "source:$RUN_ID")"
CTX_HASH="$(hash_for "context:$RUN_ID")"
STALE_CTX_HASH="$(hash_for "stale:$RUN_ID")"
REPLACEMENT_HASH="$(hash_for "replacement:$RUN_ID")"
PROJECT="LITD"
ROUTE="LITD_LIBRARY"
CONSUMER="GUARDIAN"
ACTOR="live-proof-harness"

psql_base=(psql "$GOVERNANCE_DATABASE_URL" -X -v ON_ERROR_STOP=1 -At)

sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

register_receipt() {
  local label="$1" receipt_hash
  receipt_hash="$(hash_for "$label:$RUN_ID")"
  "${psql_base[@]}" -c "select governance_private.register_receipt('$(sql_escape "$label-$RUN_ID")','$receipt_hash','VEILLEUR_RESOLUTION','$PROJECT','$ROUTE','$SOURCE_HASH','$CTX_HASH','$CONSUMER');" >/dev/null
  printf "%s" "$receipt_hash"
}

consume() {
  local receipt_hash="$1" project="$2" route="$3" consumer="$4" context_hash="$5" actor="$6"
  "${psql_base[@]}" -F '|' -c "select accepted,status,reason,audit_entry_hash from governance_private.consume_receipt('$receipt_hash','$(sql_escape "$project")','$(sql_escape "$route")','$(sql_escape "$consumer")','$(sql_escape "$actor")','$context_hash');"
}

assert_contains() {
  local value="$1" expected="$2" label="$3"
  if [[ "$value" != *"$expected"* ]]; then
    echo "FAIL $label: expected '$expected' in '$value'" >&2
    exit 1
  fi
  echo "PASS $label" | tee -a "$EVIDENCE_DIR/summary.txt"
}

# Capture deployment identity without exposing credentials.
"${psql_base[@]}" -c "select current_database(), current_user, version();" >"$EVIDENCE_DIR/database_identity.txt"
"${psql_base[@]}" -c "select to_regprocedure('governance_private.consume_receipt(text,text,text,text,text,text)') is not null;" >"$EVIDENCE_DIR/migration_present.txt"

# Client roles must not have direct table access or function execution.
"${psql_base[@]}" -F '|' -c "
select
  has_schema_privilege('anon','governance_private','USAGE'),
  has_schema_privilege('authenticated','governance_private','USAGE'),
  has_table_privilege('anon','governance_private.registered_receipts','SELECT'),
  has_table_privilege('authenticated','governance_private.registered_receipts','SELECT'),
  has_function_privilege('anon','governance_private.consume_receipt(text,text,text,text,text,text)','EXECUTE'),
  has_function_privilege('authenticated','governance_private.consume_receipt(text,text,text,text,text,text)','EXECUTE');
" >"$EVIDENCE_DIR/client_privileges.txt"
assert_contains "$(cat "$EVIDENCE_DIR/client_privileges.txt")" "f|f|f|f|f|f" "client roles denied"

# Identical replay: first succeeds, second fails closed.
R_REPLAY="$(register_receipt replay)"
FIRST="$(consume "$R_REPLAY" "$PROJECT" "$ROUTE" "$CONSUMER" "$CTX_HASH" "$ACTOR")"
SECOND="$(consume "$R_REPLAY" "$PROJECT" "$ROUTE" "$CONSUMER" "$CTX_HASH" "$ACTOR")"
printf '%s\n' "$FIRST" >"$EVIDENCE_DIR/replay_first.txt"
printf '%s\n' "$SECOND" >"$EVIDENCE_DIR/replay_second.txt"
assert_contains "$FIRST" "t|ACCEPTED|consumed_once|" "first consumption accepted"
assert_contains "$SECOND" "f|REJECTED|replay_detected|" "identical replay rejected"

# Cross-project and wrong-route reuse must fail closed.
R_SCOPE="$(register_receipt scope)"
CROSS_PROJECT="$(consume "$R_SCOPE" "COMPANY" "$ROUTE" "$CONSUMER" "$CTX_HASH" "$ACTOR")"
WRONG_ROUTE="$(consume "$R_SCOPE" "$PROJECT" "COMPANY_LIBRARY" "$CONSUMER" "$CTX_HASH" "$ACTOR")"
printf '%s\n' "$CROSS_PROJECT" >"$EVIDENCE_DIR/cross_project.txt"
printf '%s\n' "$WRONG_ROUTE" >"$EVIDENCE_DIR/wrong_route.txt"
assert_contains "$CROSS_PROJECT" "f|REJECTED|project_scope_mismatch|" "cross-project rejected"
assert_contains "$WRONG_ROUTE" "f|REJECTED|target_route_mismatch|" "wrong route rejected"

# Stale critical context must fail closed.
R_STALE="$(register_receipt stale)"
STALE="$(consume "$R_STALE" "$PROJECT" "$ROUTE" "$CONSUMER" "$STALE_CTX_HASH" "$ACTOR")"
printf '%s\n' "$STALE" >"$EVIDENCE_DIR/stale_context.txt"
assert_contains "$STALE" "f|REJECTED|stale_context|" "stale context rejected"

# Revoked receipt must fail closed.
R_REVOKED="$(register_receipt revoked)"
"${psql_base[@]}" -c "select governance_private.invalidate_receipt('$R_REVOKED','$PROJECT','$ROUTE','REVOKED','live proof revocation','$ACTOR',null);" >/dev/null
REVOKED="$(consume "$R_REVOKED" "$PROJECT" "$ROUTE" "$CONSUMER" "$CTX_HASH" "$ACTOR")"
printf '%s\n' "$REVOKED" >"$EVIDENCE_DIR/revoked.txt"
assert_contains "$REVOKED" "f|REJECTED|receipt_revoked|" "revoked receipt rejected"

# Superseded receipt must fail closed.
R_SUPERSEDED="$(register_receipt superseded)"
"${psql_base[@]}" -c "select governance_private.invalidate_receipt('$R_SUPERSEDED','$PROJECT','$ROUTE','SUPERSEDED','live proof supersession','$ACTOR','$REPLACEMENT_HASH');" >/dev/null
SUPERSEDED="$(consume "$R_SUPERSEDED" "$PROJECT" "$ROUTE" "$CONSUMER" "$CTX_HASH" "$ACTOR")"
printf '%s\n' "$SUPERSEDED" >"$EVIDENCE_DIR/superseded.txt"
assert_contains "$SUPERSEDED" "f|REJECTED|receipt_superseded|" "superseded receipt rejected"

# Concurrency proof: two independent connections race for one fresh receipt.
R_CONCURRENT="$(register_receipt concurrent)"
(
  consume "$R_CONCURRENT" "$PROJECT" "$ROUTE" "$CONSUMER" "$CTX_HASH" "worker-a" >"$EVIDENCE_DIR/concurrent_a.txt"
) &
PID_A=$!
(
  consume "$R_CONCURRENT" "$PROJECT" "$ROUTE" "$CONSUMER" "$CTX_HASH" "worker-b" >"$EVIDENCE_DIR/concurrent_b.txt"
) &
PID_B=$!
wait "$PID_A"
wait "$PID_B"

CONCURRENT_ALL="$(cat "$EVIDENCE_DIR/concurrent_a.txt"; cat "$EVIDENCE_DIR/concurrent_b.txt")"
ACCEPT_COUNT="$(printf '%s\n' "$CONCURRENT_ALL" | grep -c 't|ACCEPTED|consumed_once|' || true)"
REPLAY_COUNT="$(printf '%s\n' "$CONCURRENT_ALL" | grep -c 'f|REJECTED|replay_detected|' || true)"
if [[ "$ACCEPT_COUNT" != "1" || "$REPLAY_COUNT" != "1" ]]; then
  echo "FAIL concurrent single-winner: accepted=$ACCEPT_COUNT replay=$REPLAY_COUNT" >&2
  exit 1
fi
echo "PASS concurrent single-winner" | tee -a "$EVIDENCE_DIR/summary.txt"

# Preserve immutable audit evidence and verify chain continuity shape.
"${psql_base[@]}" -F '|' -c "
select sequence,receipt_hash,project_id,target_route,consumer,actor,outcome,reason,previous_hash,entry_hash
from governance_private.consumption_audit
where actor in ('$ACTOR','worker-a','worker-b')
order by sequence;
" >"$EVIDENCE_DIR/audit_rows.txt"

"${psql_base[@]}" -F '|' -c "
with ordered as (
  select sequence, previous_hash, entry_hash,
         lag(entry_hash) over (order by sequence) as prior_entry_hash
  from governance_private.consumption_audit
)
select count(*) filter (where sequence > (select min(sequence) from ordered) and previous_hash <> prior_entry_hash)
from ordered;
" >"$EVIDENCE_DIR/audit_chain_breaks.txt"
assert_contains "$(cat "$EVIDENCE_DIR/audit_chain_breaks.txt")" "0" "audit chain continuity"

printf 'run_id=%s\nmain_contract=78d4036dad2f3e3f6531f5bf8a1f9b55302eaaed\nevidence_dir=%s\n' "$RUN_ID" "$EVIDENCE_DIR" >"$EVIDENCE_DIR/manifest.txt"
echo "LIVE POSTGRES GOVERNANCE PROOF PASSED: $EVIDENCE_DIR"
