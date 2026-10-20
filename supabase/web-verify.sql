-- Runs under administrative SQL connection; all synthetic data rolls back.
begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.crm_owner where singleton),true);
set local role authenticated;
do $$ declare r public.crm_records; n integer; begin
 if not public.crm_access() then raise exception 'Owner authorization failed'; end if;
 insert into public.crm_records(owner_id,entity_type,source_device_id,source_local_id,payload)
 values(auth.uid(),'customers','verification-only',gen_random_uuid()::text,'{"name":"Kiểm tra không lưu"}') returning * into r;
 if r.revision<>1 then raise exception 'Initial revision failed'; end if;
 perform public.crm_save(r.id,1,'{"name":"Kiểm tra phiên bản"}');
 select revision into n from public.crm_records where id=r.id;
 if n<>2 then raise exception 'Revision increment failed'; end if;
 begin
  perform public.crm_save(r.id,1,'{"name":"Must not overwrite"}');
  raise exception 'Stale edit was accepted';
 exception when serialization_failure then null; end;
 n:=public.crm_import('verification-import','[{"entity_type":"customers","source_local_id":"1","payload":{"id":1,"name":"Mẫu"}}]');
 if n<>1 then raise exception 'Import failed'; end if;
 n:=public.crm_import('verification-import','[{"entity_type":"customers","source_local_id":"1","payload":{"id":1,"name":"Mẫu"}}]');
 if n<>0 then raise exception 'Identical import not idempotent'; end if;
 begin
  perform public.crm_import('verification-import','[{"entity_type":"customers","source_local_id":"2","payload":{"id":2,"name":"Rollback"}},{"entity_type":"customers","source_local_id":"1","payload":{"id":1,"name":"Changed"}}]');
  raise exception 'Changed import accepted';
 exception when raise_exception then
  if sqlerrm not like 'CONFLICT:%' then raise; end if;
 end;
 if exists(select 1 from public.crm_records where source_device_id='verification-import' and source_local_id='2') then raise exception 'Import was not atomic'; end if;
 begin
  execute 'truncate public.crm_records';
  raise exception 'TRUNCATE allowed';
 exception when insufficient_privilege then null; end;
 begin
  delete from public.crm_records where id=r.id;
  raise exception 'DELETE privilege allowed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ begin
 if public.crm_access() then raise exception 'Non-owner authorized'; end if;
 if exists(select 1 from public.crm_records) then raise exception 'Non-owner can read'; end if;
 begin
  insert into public.crm_records(owner_id,entity_type,source_device_id,source_local_id,payload)
  values(auth.uid(),'customers','verification-only','unauthorized','{}');
  raise exception 'Non-owner write allowed';
 exception when insufficient_privilege then null; end;
 begin
  perform public.crm_import('verification-import','[]');
  raise exception 'Non-owner RPC allowed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin perform * from public.crm_records; raise exception 'Anonymous read allowed';
 exception when insufficient_privilege then null; end;
end $$;
rollback;
