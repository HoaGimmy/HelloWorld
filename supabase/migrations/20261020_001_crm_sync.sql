-- MPWindows CRM single-owner sync staging schema.
-- IMPORTANT: Set owner UUID in Supabase SQL editor after the owner signs in.
-- No public access. No service role key in the client.
create extension if not exists pgcrypto;

create table if not exists public.crm_owner (
  singleton boolean primary key default true check (singleton),
  user_id uuid not null unique references auth.users(id)
);
alter table public.crm_owner enable row level security;
-- No client policies: owner registration is admin-only.

create or replace function public.is_crm_owner()
returns boolean language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.crm_owner
    where user_id = (select auth.uid())
  );
$$;
revoke all on function public.is_crm_owner() from public;
grant execute on function public.is_crm_owner() to authenticated;

create table if not exists public.crm_records (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id),
  entity_type text not null check (entity_type in (
    'customers','activities','tasks','appointments','projects',
    'contracts','payments','quotes','app_settings'
  )),
  source_device_id text not null,
  source_local_id text not null,
  payload jsonb not null default '{}'::jsonb,
  revision bigint not null default 1 check (revision > 0),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, entity_type, source_device_id, source_local_id)
);
create index if not exists crm_records_owner_updated
  on public.crm_records (owner_id, updated_at);

alter table public.crm_records enable row level security;
create policy "owner read" on public.crm_records
  for select to authenticated
  using (owner_id = (select auth.uid()) and (select public.is_crm_owner()));
create policy "owner insert" on public.crm_records
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and (select public.is_crm_owner()));
create policy "owner update" on public.crm_records
  for update to authenticated
  using (owner_id = (select auth.uid()) and (select public.is_crm_owner()))
  with check (owner_id = (select auth.uid()) and (select public.is_crm_owner()));
create policy "owner delete" on public.crm_records
  for delete to authenticated
  using (false);

-- Install an owner UUID manually after the intended Google account has signed in:
-- insert into public.crm_owner (singleton,user_id)
-- values (true, 'REPLACE_WITH_AUTH_USER_UUID');
-- Keep deletes as tombstones, never physical deletions from the client.
-- This schema is staging infrastructure, NOT a completed two-way sync implementation.
