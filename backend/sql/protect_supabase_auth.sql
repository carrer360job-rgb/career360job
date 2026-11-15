-- Auth-backed API grants. RLS remains enabled on every public table.
revoke all on all tables in schema public from anon, authenticated;

grant select on public.profiles to authenticated;
grant insert (id, email, phone, role, fcm_token, device_type, last_active_at, updated_at)
  on public.profiles to authenticated;
grant update (id, email, phone, role, fcm_token, device_type, last_active_at, updated_at)
  on public.profiles to authenticated;

drop policy if exists "Users can view and edit own profile" on public.profiles;
create policy profiles_read_own on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy profiles_insert_own on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id and role in ('CANDIDATE', 'EMPLOYER') and status = 'ACTIVE');
create policy profiles_update_own on public.profiles for update to authenticated
  using ((select auth.uid()) = id and status = 'ACTIVE' and role in ('CANDIDATE', 'EMPLOYER'))
  with check ((select auth.uid()) = id and status = 'ACTIVE' and role in ('CANDIDATE', 'EMPLOYER'));

alter table public.employers alter column posting_credits set default 0;
alter table public.employers alter column is_verified set default false;
grant select on public.employers to authenticated;
grant insert (user_id, company_name, contact_name, designation, district, city, phone, email, logo_url, updated_at)
  on public.employers to authenticated;
grant update (user_id, company_name, contact_name, designation, district, city, phone, email, logo_url, updated_at)
  on public.employers to authenticated;
drop policy if exists "Employers can view and edit own company" on public.employers;
create policy employers_read_own on public.employers for select to authenticated
  using ((select auth.uid()) = user_id);
create policy employers_insert_own on public.employers for insert to authenticated
  with check ((select auth.uid()) = user_id and is_verified = false and posting_credits = 0);
create policy employers_update_own on public.employers for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

grant select, insert, update on public.candidate_profiles to authenticated;
grant select on public.jobs to anon, authenticated;
grant select on public.employer_plans to anon, authenticated;
grant select, insert on public.job_applications to authenticated;
grant select on public.notifications to authenticated;
grant update (is_read) on public.notifications to authenticated;

drop policy if exists "Candidates can create and view own applications" on public.job_applications;
create policy applications_read_own on public.job_applications for select to authenticated
  using (candidate_id in (select id from public.candidate_profiles where user_id = (select auth.uid())));
create policy applications_insert_own on public.job_applications for insert to authenticated
  with check (candidate_id in (select id from public.candidate_profiles where user_id = (select auth.uid()))
    and status = 'SUBMITTED');
create policy notifications_mark_read on public.notifications for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- This event trigger function must never be exposed as a Data API RPC.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
