drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles for insert to authenticated
with check (
  (select auth.uid()) = id
  and role in ('CANDIDATE', 'EMPLOYER', 'INSTITUTION')
  and status = 'ACTIVE'
);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated
using (
  (select auth.uid()) = id
  and status = 'ACTIVE'
  and role in ('CANDIDATE', 'EMPLOYER', 'INSTITUTION')
)
with check (
  (select auth.uid()) = id
  and status = 'ACTIVE'
  and role in ('CANDIDATE', 'EMPLOYER', 'INSTITUTION')
);

create or replace function public.prevent_self_role_change()
returns trigger language plpgsql security invoker set search_path = public, pg_temp
as $$
begin
  if (select auth.role()) = 'authenticated' and new.role is distinct from old.role then
    raise exception 'Account role cannot be changed';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_role_immutable on public.profiles;
create trigger profiles_role_immutable before update on public.profiles
for each row execute function public.prevent_self_role_change();

create table if not exists public.institutions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 2 and 200),
  institution_type text not null check (length(trim(institution_type)) between 2 and 100),
  coordinator_name text not null check (length(trim(coordinator_name)) between 2 and 120),
  phone text not null default '',
  email text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.institutions enable row level security;
create policy institutions_read_own on public.institutions for select to authenticated
using ((select auth.uid()) = user_id);
create policy institutions_insert_own on public.institutions for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (select 1 from public.profiles p where p.id = user_id and p.role = 'INSTITUTION')
);
create policy institutions_update_own on public.institutions for update to authenticated
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and exists (select 1 from public.profiles p where p.id = user_id and p.role = 'INSTITUTION')
);
grant select, insert, update on public.institutions to authenticated;
