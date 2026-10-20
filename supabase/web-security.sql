-- Additive hardening; does not modify existing CRM payloads or the owner.
begin;
revoke all on public.crm_owner from anon, authenticated;
revoke all on public.crm_records from anon, authenticated;
grant select, insert, update on public.crm_records to authenticated;
create or replace function public.crm_access()
returns boolean language sql stable security invoker set search_path=''
as $$ select private.is_crm_owner(); $$;
revoke all on function public.crm_access() from public, anon;
grant execute on function public.crm_access() to authenticated;

create or replace function private.crm_record_guard()
returns trigger language plpgsql security invoker set search_path=''
as $$ begin
 if jsonb_typeof(new.payload) <> 'object' then raise exception 'Payload must be an object'; end if;
 if tg_op='UPDATE' then
  if (new.id,new.owner_id,new.entity_type,new.source_device_id,new.source_local_id,new.created_at)
     is distinct from (old.id,old.owner_id,old.entity_type,old.source_device_id,old.source_local_id,old.created_at)
  then raise exception 'Record identity is immutable'; end if;
  new.revision := old.revision+1;
 else new.revision:=1;
 end if;
 new.updated_at:=clock_timestamp();
 return new;
end $$;
revoke all on function private.crm_record_guard() from public, anon, authenticated;
drop trigger if exists crm_record_guard on public.crm_records;
create trigger crm_record_guard before insert or update on public.crm_records
for each row execute function private.crm_record_guard();

-- Expected revision is compared atomically; stale edits cannot overwrite.
create or replace function public.crm_save(p_id uuid,p_revision bigint,p_payload jsonb)
returns setof public.crm_records language plpgsql security invoker set search_path=''
as $$ begin
 if not private.is_crm_owner() then raise exception 'Forbidden' using errcode='42501'; end if;
 return query update public.crm_records set payload=p_payload
 where id=p_id and owner_id=auth.uid() and revision=p_revision and deleted_at is null returning *;
 if not found then raise exception 'CONFLICT: reload record before saving' using errcode='40001'; end if;
end $$;
revoke all on function public.crm_save(uuid,bigint,jsonb) from public, anon;
grant execute on function public.crm_save(uuid,bigint,jsonb) to authenticated;

-- Atomic append-only import. Identical reimports are skipped; changed records abort.
create or replace function public.crm_import(p_device text,p_rows jsonb)
returns integer language plpgsql security invoker set search_path=''
as $$ declare r jsonb; existing public.crm_records; inserted integer:=0; begin
 if not private.is_crm_owner() then raise exception 'Forbidden' using errcode='42501'; end if;
 if length(p_device) not between 1 and 100 or jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)>10000 then raise exception 'Invalid import'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_device,0));
 for r in select value from jsonb_array_elements(p_rows) loop
  if r->>'entity_type' not in ('customers','activities','tasks','appointments','projects','quotes','contracts','payments') or jsonb_typeof(r->'payload')<>'object' or coalesce(r->>'source_local_id','')='' then raise exception 'Invalid record'; end if;
  select * into existing from public.crm_records where owner_id=auth.uid() and entity_type=r->>'entity_type' and source_device_id=p_device and source_local_id=r->>'source_local_id';
  if found then
   if existing.payload is distinct from r->'payload' or existing.deleted_at is not null then raise exception 'CONFLICT: imported record already changed'; end if;
  else
   insert into public.crm_records(owner_id,entity_type,source_device_id,source_local_id,payload)
   values(auth.uid(),r->>'entity_type',p_device,r->>'source_local_id',r->'payload');
   inserted:=inserted+1;
  end if;
 end loop;
 return inserted;
end $$;
revoke all on function public.crm_import(text,jsonb) from public, anon;
grant execute on function public.crm_import(text,jsonb) to authenticated;
commit;
