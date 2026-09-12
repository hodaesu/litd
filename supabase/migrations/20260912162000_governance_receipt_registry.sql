-- P0 #331 durable replay-protection registry for Supabase/PostgreSQL.
-- This migration mirrors the validated SQLite contract while keeping all
-- authority-bearing mutations inside PostgreSQL transactions.

create schema if not exists governance_private;
create extension if not exists pgcrypto with schema extensions;

create table if not exists governance_private.registered_receipts (
    receipt_hash text primary key check (receipt_hash ~ '^[0-9a-f]{64}$'),
    receipt_id text not null unique check (length(btrim(receipt_id)) > 0),
    receipt_kind text not null check (length(btrim(receipt_kind)) > 0),
    project_id text not null check (length(btrim(project_id)) > 0),
    target_route text not null check (length(btrim(target_route)) > 0),
    source_hash text not null check (source_hash ~ '^[0-9a-f]{64}$'),
    context_hash text not null check (context_hash ~ '^[0-9a-f]{64}$'),
    expected_consumer text not null check (length(btrim(expected_consumer)) > 0),
    registered_at timestamptz not null default clock_timestamp()
);

create table if not exists governance_private.receipt_consumptions (
    receipt_hash text primary key references governance_private.registered_receipts(receipt_hash),
    consumer text not null,
    actor text not null,
    consumed_at timestamptz not null default clock_timestamp(),
    current_context_hash text not null check (current_context_hash ~ '^[0-9a-f]{64}$')
);

create table if not exists governance_private.receipt_invalidations (
    receipt_hash text primary key references governance_private.registered_receipts(receipt_hash),
    invalidation_kind text not null check (invalidation_kind in ('REVOKED', 'SUPERSEDED')),
    reason text not null check (length(btrim(reason)) > 0),
    replacement_receipt_hash text check (replacement_receipt_hash is null or replacement_receipt_hash ~ '^[0-9a-f]{64}$'),
    actor text not null check (length(btrim(actor)) > 0),
    invalidated_at timestamptz not null default clock_timestamp(),
    check (invalidation_kind <> 'SUPERSEDED' or replacement_receipt_hash is not null)
);

create table if not exists governance_private.consumption_audit (
    sequence bigint generated always as identity primary key,
    receipt_hash text not null,
    project_id text not null,
    target_route text not null,
    consumer text not null,
    actor text not null,
    current_context_hash text not null,
    outcome text not null check (outcome in ('ACCEPTED', 'REJECTED')),
    reason text not null,
    recorded_at timestamptz not null,
    previous_hash text not null,
    entry_hash text not null unique check (entry_hash ~ '^[0-9a-f]{64}$')
);

create or replace function governance_private.reject_append_only_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    raise exception '%_append_only', tg_table_name using errcode = '55000';
end;
$$;

drop trigger if exists registered_receipts_append_only on governance_private.registered_receipts;
create trigger registered_receipts_append_only
before update or delete on governance_private.registered_receipts
for each row execute function governance_private.reject_append_only_mutation();

drop trigger if exists receipt_consumptions_append_only on governance_private.receipt_consumptions;
create trigger receipt_consumptions_append_only
before update or delete on governance_private.receipt_consumptions
for each row execute function governance_private.reject_append_only_mutation();

drop trigger if exists receipt_invalidations_append_only on governance_private.receipt_invalidations;
create trigger receipt_invalidations_append_only
before update or delete on governance_private.receipt_invalidations
for each row execute function governance_private.reject_append_only_mutation();

drop trigger if exists consumption_audit_append_only on governance_private.consumption_audit;
create trigger consumption_audit_append_only
before update or delete on governance_private.consumption_audit
for each row execute function governance_private.reject_append_only_mutation();

alter table governance_private.registered_receipts enable row level security;
alter table governance_private.receipt_consumptions enable row level security;
alter table governance_private.receipt_invalidations enable row level security;
alter table governance_private.consumption_audit enable row level security;

revoke all on schema governance_private from public, anon, authenticated;
revoke all on all tables in schema governance_private from public, anon, authenticated, service_role;
revoke all on all sequences in schema governance_private from public, anon, authenticated, service_role;
revoke execute on all functions in schema governance_private from public, anon, authenticated, service_role;

grant usage on schema governance_private to service_role;

create or replace function governance_private.register_receipt(
    p_receipt_id text,
    p_receipt_hash text,
    p_receipt_kind text,
    p_project_id text,
    p_target_route text,
    p_source_hash text,
    p_context_hash text,
    p_expected_consumer text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if p_receipt_hash !~ '^[0-9a-f]{64}$'
       or p_source_hash !~ '^[0-9a-f]{64}$'
       or p_context_hash !~ '^[0-9a-f]{64}$' then
        raise exception 'receipt/source/context hashes must be lowercase sha256';
    end if;
    if length(btrim(p_receipt_id)) = 0 or length(btrim(p_receipt_kind)) = 0
       or length(btrim(p_project_id)) = 0 or length(btrim(p_target_route)) = 0
       or length(btrim(p_expected_consumer)) = 0 then
        raise exception 'receipt identity, scope and expected consumer are required';
    end if;

    insert into governance_private.registered_receipts(
        receipt_hash, receipt_id, receipt_kind, project_id, target_route,
        source_hash, context_hash, expected_consumer
    ) values (
        p_receipt_hash, btrim(p_receipt_id), btrim(p_receipt_kind), btrim(p_project_id),
        btrim(p_target_route), p_source_hash, p_context_hash, btrim(p_expected_consumer)
    );
end;
$$;

create or replace function governance_private.invalidate_receipt(
    p_receipt_hash text,
    p_project_id text,
    p_target_route text,
    p_kind text,
    p_reason text,
    p_actor text,
    p_replacement_receipt_hash text default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_found boolean;
begin
    if p_kind not in ('REVOKED', 'SUPERSEDED') then
        raise exception 'unsupported invalidation kind';
    end if;
    if p_kind = 'SUPERSEDED' and p_replacement_receipt_hash is null then
        raise exception 'supersession requires replacement receipt hash';
    end if;

    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(p_receipt_hash));
    select true into v_found
      from governance_private.registered_receipts
     where receipt_hash = p_receipt_hash
       and project_id = p_project_id
       and target_route = p_target_route
     for update;
    if coalesce(v_found, false) is false then
        raise exception 'unknown or cross-scope receipt';
    end if;

    insert into governance_private.receipt_invalidations(
        receipt_hash, invalidation_kind, reason, replacement_receipt_hash, actor
    ) values (
        p_receipt_hash, p_kind, btrim(p_reason), p_replacement_receipt_hash, btrim(p_actor)
    );
end;
$$;

create or replace function governance_private.consume_receipt(
    p_receipt_hash text,
    p_project_id text,
    p_target_route text,
    p_consumer text,
    p_actor text,
    p_current_context_hash text
) returns table(accepted boolean, status text, reason text, audit_entry_hash text)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_receipt governance_private.registered_receipts%rowtype;
    v_invalidation text;
    v_consumed boolean;
    v_outcome text := 'REJECTED';
    v_reason text := 'unknown_receipt';
    v_previous_hash text;
    v_recorded_at timestamptz := clock_timestamp();
    v_entry_hash text;
begin
    if p_receipt_hash !~ '^[0-9a-f]{64}$' or p_current_context_hash !~ '^[0-9a-f]{64}$' then
        raise exception 'receipt and context hashes must be lowercase sha256';
    end if;
    if length(btrim(p_project_id)) = 0 or length(btrim(p_target_route)) = 0
       or length(btrim(p_consumer)) = 0 or length(btrim(p_actor)) = 0 then
        raise exception 'scope, consumer and actor are required';
    end if;

    -- Serialize attempts for the same receipt. Hash collisions only serialize
    -- unrelated receipts; they cannot authorize a second consumption.
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(p_receipt_hash));

    select * into v_receipt
      from governance_private.registered_receipts
     where receipt_hash = p_receipt_hash
     for update;

    if found then
        if v_receipt.project_id <> p_project_id then
            v_reason := 'project_scope_mismatch';
        elsif v_receipt.target_route <> p_target_route then
            v_reason := 'target_route_mismatch';
        elsif v_receipt.expected_consumer <> p_consumer then
            v_reason := 'unexpected_consumer';
        elsif v_receipt.context_hash <> p_current_context_hash then
            v_reason := 'stale_context';
        else
            select invalidation_kind into v_invalidation
              from governance_private.receipt_invalidations
             where receipt_hash = p_receipt_hash;
            if found then
                v_reason := 'receipt_' || lower(v_invalidation);
            else
                select true into v_consumed
                  from governance_private.receipt_consumptions
                 where receipt_hash = p_receipt_hash;
                if coalesce(v_consumed, false) then
                    v_reason := 'replay_detected';
                else
                    insert into governance_private.receipt_consumptions(
                        receipt_hash, consumer, actor, current_context_hash
                    ) values (
                        p_receipt_hash, btrim(p_consumer), btrim(p_actor), p_current_context_hash
                    );
                    v_outcome := 'ACCEPTED';
                    v_reason := 'consumed_once';
                end if;
            end if;
        end if;
    end if;

    -- Serialize the global audit chain so concurrent receipts cannot fork it.
    perform pg_catalog.pg_advisory_xact_lock(33120260912);
    select entry_hash into v_previous_hash
      from governance_private.consumption_audit
     order by sequence desc
     limit 1;
    v_previous_hash := coalesce(v_previous_hash, 'GENESIS');

    v_entry_hash := encode(
        extensions.digest(
            pg_catalog.convert_to(
                pg_catalog.jsonb_build_object(
                    'receipt_hash', p_receipt_hash,
                    'project_id', p_project_id,
                    'target_route', p_target_route,
                    'consumer', btrim(p_consumer),
                    'actor', btrim(p_actor),
                    'current_context_hash', p_current_context_hash,
                    'outcome', v_outcome,
                    'reason', v_reason,
                    'recorded_at', v_recorded_at,
                    'previous_hash', v_previous_hash
                )::text,
                'UTF8'
            ),
            'sha256'
        ),
        'hex'
    );

    insert into governance_private.consumption_audit(
        receipt_hash, project_id, target_route, consumer, actor,
        current_context_hash, outcome, reason, recorded_at, previous_hash, entry_hash
    ) values (
        p_receipt_hash, btrim(p_project_id), btrim(p_target_route), btrim(p_consumer), btrim(p_actor),
        p_current_context_hash, v_outcome, v_reason, v_recorded_at, v_previous_hash, v_entry_hash
    );

    return query select (v_outcome = 'ACCEPTED'), v_outcome, v_reason, v_entry_hash;
end;
$$;

revoke execute on function governance_private.register_receipt(text,text,text,text,text,text,text,text) from public, anon, authenticated;
revoke execute on function governance_private.invalidate_receipt(text,text,text,text,text,text,text) from public, anon, authenticated;
revoke execute on function governance_private.consume_receipt(text,text,text,text,text,text) from public, anon, authenticated;

grant execute on function governance_private.register_receipt(text,text,text,text,text,text,text,text) to service_role;
grant execute on function governance_private.invalidate_receipt(text,text,text,text,text,text,text) to service_role;
grant execute on function governance_private.consume_receipt(text,text,text,text,text,text) to service_role;
