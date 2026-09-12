-- P0 governance replay protection for Supabase/PostgreSQL.
-- This migration defines the durable contract only. It is not production proof until
-- deployed to the real governance project and exercised with retained evidence.

create schema if not exists governance;

revoke all on schema governance from public;
revoke all on schema governance from anon;
revoke all on schema governance from authenticated;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'receipt_invalidation_kind' and typnamespace = 'governance'::regnamespace) then
    create type governance.receipt_invalidation_kind as enum ('REVOKED', 'SUPERSEDED');
  end if;
end
$$;

create table if not exists governance.receipts (
  receipt_id text primary key,
  receipt_hash text not null unique check (receipt_hash ~ '^[0-9a-f]{64}$'),
  receipt_kind text not null check (length(btrim(receipt_kind)) > 0),
  project_id text not null check (length(btrim(project_id)) > 0),
  target_route text not null check (length(btrim(target_route)) > 0),
  candidate_hash text not null check (candidate_hash ~ '^[0-9a-f]{64}$'),
  source_hash text not null check (source_hash ~ '^[0-9a-f]{64}$'),
  context_hash text not null check (context_hash ~ '^[0-9a-f]{64}$'),
  expected_consumer text not null check (length(btrim(expected_consumer)) > 0),
  created_at timestamptz not null default clock_timestamp(),
  created_by text not null check (length(btrim(created_by)) > 0)
);

create table if not exists governance.receipt_invalidations (
  invalidation_id bigint generated always as identity primary key,
  receipt_hash text not null references governance.receipts(receipt_hash),
  kind governance.receipt_invalidation_kind not null,
  replacement_receipt_hash text null,
  reason text not null check (length(btrim(reason)) > 0),
  actor text not null check (length(btrim(actor)) > 0),
  occurred_at timestamptz not null default clock_timestamp(),
  check (
    (kind = 'SUPERSEDED' and replacement_receipt_hash is not null and replacement_receipt_hash ~ '^[0-9a-f]{64}$')
    or (kind = 'REVOKED' and replacement_receipt_hash is null)
  )
);

create table if not exists governance.receipt_consumptions (
  consumption_id bigint generated always as identity primary key,
  receipt_hash text not null unique references governance.receipts(receipt_hash),
  consumer text not null check (length(btrim(consumer)) > 0),
  actor text not null check (length(btrim(actor)) > 0),
  consumed_context_hash text not null check (consumed_context_hash ~ '^[0-9a-f]{64}$'),
  consumed_at timestamptz not null default clock_timestamp()
);

create table if not exists governance.receipt_consumption_audit (
  audit_id bigint generated always as identity primary key,
  receipt_hash text not null,
  consumer text not null,
  actor text not null,
  attempted_context_hash text not null,
  accepted boolean not null,
  reason text not null,
  attempted_at timestamptz not null default clock_timestamp()
);

create index if not exists receipt_invalidations_receipt_hash_idx
  on governance.receipt_invalidations(receipt_hash, invalidation_id desc);
create index if not exists receipt_consumption_audit_receipt_hash_idx
  on governance.receipt_consumption_audit(receipt_hash, audit_id desc);

create or replace function governance.prevent_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, governance
as $$
begin
  raise exception 'append_only_relation';
end
$$;

drop trigger if exists receipts_append_only on governance.receipts;
create trigger receipts_append_only
before update or delete on governance.receipts
for each row execute function governance.prevent_mutation();

drop trigger if exists receipt_invalidations_append_only on governance.receipt_invalidations;
create trigger receipt_invalidations_append_only
before update or delete on governance.receipt_invalidations
for each row execute function governance.prevent_mutation();

drop trigger if exists receipt_consumptions_append_only on governance.receipt_consumptions;
create trigger receipt_consumptions_append_only
before update or delete on governance.receipt_consumptions
for each row execute function governance.prevent_mutation();

drop trigger if exists receipt_consumption_audit_append_only on governance.receipt_consumption_audit;
create trigger receipt_consumption_audit_append_only
before update or delete on governance.receipt_consumption_audit
for each row execute function governance.prevent_mutation();

create or replace function governance.consume_receipt_once(
  p_receipt_hash text,
  p_project_id text,
  p_target_route text,
  p_candidate_hash text,
  p_consumer text,
  p_actor text,
  p_current_context_hash text
)
returns table(accepted boolean, reason text, consumption_id bigint)
language plpgsql
security definer
set search_path = pg_catalog, governance
as $$
declare
  v_receipt governance.receipts%rowtype;
  v_invalidation governance.receipt_invalidations%rowtype;
  v_consumption_id bigint;
begin
  if coalesce(p_receipt_hash, '') !~ '^[0-9a-f]{64}$'
     or coalesce(p_candidate_hash, '') !~ '^[0-9a-f]{64}$'
     or coalesce(p_current_context_hash, '') !~ '^[0-9a-f]{64}$'
     or length(btrim(coalesce(p_project_id, ''))) = 0
     or length(btrim(coalesce(p_target_route, ''))) = 0
     or length(btrim(coalesce(p_consumer, ''))) = 0
     or length(btrim(coalesce(p_actor, ''))) = 0 then
    insert into governance.receipt_consumption_audit(
      receipt_hash, consumer, actor, attempted_context_hash, accepted, reason
    ) values (
      coalesce(p_receipt_hash, '<invalid>'), coalesce(p_consumer, '<invalid>'),
      coalesce(p_actor, '<invalid>'), coalesce(p_current_context_hash, '<invalid>'),
      false, 'invalid_request'
    );
    return query select false, 'invalid_request', null::bigint;
    return;
  end if;

  select * into v_receipt
  from governance.receipts
  where receipt_hash = p_receipt_hash
  for update;

  if not found then
    insert into governance.receipt_consumption_audit(
      receipt_hash, consumer, actor, attempted_context_hash, accepted, reason
    ) values (p_receipt_hash, p_consumer, p_actor, p_current_context_hash, false, 'unknown_receipt');
    return query select false, 'unknown_receipt', null::bigint;
    return;
  end if;

  if v_receipt.project_id <> p_project_id then
    insert into governance.receipt_consumption_audit values
      (default, p_receipt_hash, p_consumer, p_actor, p_current_context_hash, false, 'project_scope_mismatch', default);
    return query select false, 'project_scope_mismatch', null::bigint;
    return;
  end if;

  if v_receipt.target_route <> p_target_route then
    insert into governance.receipt_consumption_audit values
      (default, p_receipt_hash, p_consumer, p_actor, p_current_context_hash, false, 'route_scope_mismatch', default);
    return query select false, 'route_scope_mismatch', null::bigint;
    return;
  end if;

  if v_receipt.candidate_hash <> p_candidate_hash then
    insert into governance.receipt_consumption_audit values
      (default, p_receipt_hash, p_consumer, p_actor, p_current_context_hash, false, 'candidate_hash_mismatch', default);
    return query select false, 'candidate_hash_mismatch', null::bigint;
    return;
  end if;

  if v_receipt.expected_consumer <> p_consumer then
    insert into governance.receipt_consumption_audit values
      (default, p_receipt_hash, p_consumer, p_actor, p_current_context_hash, false, 'unexpected_consumer', default);
    return query select false, 'unexpected_consumer', null::bigint;
    return;
  end if;

  if v_receipt.context_hash <> p_current_context_hash then
    insert into governance.receipt_consumption_audit values
      (default, p_receipt_hash, p_consumer, p_actor, p_current_context_hash, false, 'stale_context', default);
    return query select false, 'stale_context', null::bigint;
    return;
  end if;

  select * into v_invalidation
  from governance.receipt_invalidations
  where receipt_hash = p_receipt_hash
  order by invalidation_id desc
  limit 1;

  if found then
    insert into governance.receipt_consumption_audit values
      (default, p_receipt_hash, p_consumer, p_actor, p_current_context_hash, false,
       case when v_invalidation.kind = 'SUPERSEDED' then 'receipt_superseded' else 'receipt_revoked' end,
       default);
    return query select false,
      case when v_invalidation.kind = 'SUPERSEDED' then 'receipt_superseded' else 'receipt_revoked' end,
      null::bigint;
    return;
  end if;

  insert into governance.receipt_consumptions(
    receipt_hash, consumer, actor, consumed_context_hash
  ) values (
    p_receipt_hash, p_consumer, p_actor, p_current_context_hash
  )
  on conflict (receipt_hash) do nothing
  returning governance.receipt_consumptions.consumption_id into v_consumption_id;

  if v_consumption_id is null then
    insert into governance.receipt_consumption_audit values
      (default, p_receipt_hash, p_consumer, p_actor, p_current_context_hash, false, 'replay_detected', default);
    return query select false, 'replay_detected', null::bigint;
    return;
  end if;

  insert into governance.receipt_consumption_audit values
    (default, p_receipt_hash, p_consumer, p_actor, p_current_context_hash, true, 'consumed_once', default);
  return query select true, 'consumed_once', v_consumption_id;
end
$$;

revoke all on all tables in schema governance from public, anon, authenticated;
revoke all on all sequences in schema governance from public, anon, authenticated;
revoke all on function governance.consume_receipt_once(text, text, text, text, text, text, text) from public, anon, authenticated;

comment on function governance.consume_receipt_once(text, text, text, text, text, text, text)
is 'P0 single-use receipt gate. Serializes by receipt row, rejects replay/scope/context/invalidation failures, and records every attempt.';
