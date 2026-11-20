-- Remove institution data and all client access to the retired portal.
do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='institutions'
  ) then
    alter publication supabase_realtime drop table public.institutions;
  end if;
end;
$$;

drop table if exists public.institutions;

drop policy if exists profiles_insert_own on public.profiles;
drop policy if exists profiles_update_own on public.profiles;
drop policy if exists candidate_profiles_insert_own on public.candidate_profiles;
drop policy if exists candidate_profiles_read_own on public.candidate_profiles;
drop policy if exists candidate_profiles_update_own on public.candidate_profiles;
drop policy if exists applications_insert_own on public.job_applications;
drop policy if exists applications_read_own on public.job_applications;
drop policy if exists candidate_photo_delete_own on storage.objects;
drop policy if exists candidate_photo_insert_own on storage.objects;
drop policy if exists candidate_photo_select_own on storage.objects;
drop policy if exists candidate_photo_update_own on storage.objects;

-- PostgreSQL cannot delete a single enum value, so rebuild the role type.
alter table public.profiles alter column role drop default;
alter type public.user_role rename to user_role_with_institution;
create type public.user_role as enum ('CANDIDATE', 'EMPLOYER', 'ADMIN');
alter table public.profiles alter column role type public.user_role
  using role::text::public.user_role;
alter table public.profiles alter column role set default 'CANDIDATE'::public.user_role;
drop type public.user_role_with_institution;

create policy profiles_insert_own on public.profiles for insert to authenticated
with check (
  (select auth.uid()) = id
  and role in ('CANDIDATE', 'EMPLOYER')
  and status = 'ACTIVE'
);

create policy profiles_update_own on public.profiles for update to authenticated
using (
  (select auth.uid()) = id
  and status = 'ACTIVE'
  and role in ('CANDIDATE', 'EMPLOYER')
)
with check (
  (select auth.uid()) = id
  and status = 'ACTIVE'
  and role in ('CANDIDATE', 'EMPLOYER')
);

create policy candidate_profiles_insert_own on public.candidate_profiles
  for insert to authenticated with check (
    (select auth.uid()) = user_id and exists (
      select 1 from public.profiles p where p.id=(select auth.uid())
        and p.role='CANDIDATE' and p.status='ACTIVE'
    )
  );
create policy candidate_profiles_read_own on public.candidate_profiles
  for select to authenticated using (
    (select auth.uid()) = user_id and exists (
      select 1 from public.profiles p where p.id=(select auth.uid())
        and p.role='CANDIDATE' and p.status='ACTIVE'
    )
  );
create policy candidate_profiles_update_own on public.candidate_profiles
  for update to authenticated using (
    (select auth.uid()) = user_id and exists (
      select 1 from public.profiles p where p.id=(select auth.uid())
        and p.role='CANDIDATE' and p.status='ACTIVE'
    )
  ) with check (
    (select auth.uid()) = user_id and exists (
      select 1 from public.profiles p where p.id=(select auth.uid())
        and p.role='CANDIDATE' and p.status='ACTIVE'
    )
  );
create policy applications_read_own on public.job_applications
  for select to authenticated using (
    candidate_id in (select cp.id from public.candidate_profiles cp
      where cp.user_id=(select auth.uid())) and exists (
        select 1 from public.profiles p where p.id=(select auth.uid())
          and p.role='CANDIDATE' and p.status='ACTIVE'
      )
  );
create policy applications_insert_own on public.job_applications
  for insert to authenticated with check (
    candidate_id in (select cp.id from public.candidate_profiles cp
      where cp.user_id=(select auth.uid()))
    and status='SUBMITTED'
    and exists (select 1 from public.profiles p where p.id=(select auth.uid())
      and p.role='CANDIDATE' and p.status='ACTIVE')
    and exists (select 1 from public.jobs j where j.id=job_id
      and j.status='PUBLISHED' and (j.expires_at is null or j.expires_at>now()))
  );

create policy candidate_photo_delete_own on storage.objects for delete to authenticated
using (bucket_id='profile-photos'
  and name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|webp|png)$')
  and exists(select 1 from public.profiles p where p.id=(select auth.uid())
    and p.role='CANDIDATE' and p.status='ACTIVE'));
create policy candidate_photo_insert_own on storage.objects for insert to authenticated
with check (bucket_id='profile-photos'
  and name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$')
  and exists(select 1 from public.profiles p where p.id=(select auth.uid())
    and p.role='CANDIDATE' and p.status='ACTIVE'));
create policy candidate_photo_select_own on storage.objects for select to authenticated
using (bucket_id='profile-photos'
  and name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$')
  and exists(select 1 from public.profiles p where p.id=(select auth.uid())
    and p.role='CANDIDATE' and p.status='ACTIVE'));
create policy candidate_photo_update_own on storage.objects for update to authenticated
using (bucket_id='profile-photos'
  and name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$')
  and exists(select 1 from public.profiles p where p.id=(select auth.uid())
    and p.role='CANDIDATE' and p.status='ACTIVE'))
with check (bucket_id='profile-photos'
  and name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$')
  and exists(select 1 from public.profiles p where p.id=(select auth.uid())
    and p.role='CANDIDATE' and p.status='ACTIVE'));
