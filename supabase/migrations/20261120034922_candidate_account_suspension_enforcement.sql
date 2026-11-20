-- Keep suspended job seeker sessions out of private data even before Auth
-- rejects a refreshed token. profiles remains readable by its owner so the
-- mobile app can receive the status change and show an account notice.

drop policy if exists candidate_profiles_read_own on public.candidate_profiles;
create policy candidate_profiles_read_own on public.candidate_profiles
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'CANDIDATE'
        and p.status = 'ACTIVE'
    )
  );

drop policy if exists candidate_profiles_insert_own on public.candidate_profiles;
create policy candidate_profiles_insert_own on public.candidate_profiles
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'CANDIDATE'
        and p.status = 'ACTIVE'
    )
  );

drop policy if exists candidate_profiles_update_own on public.candidate_profiles;
create policy candidate_profiles_update_own on public.candidate_profiles
  for update to authenticated
  using (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'CANDIDATE'
        and p.status = 'ACTIVE'
    )
  )
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'CANDIDATE'
        and p.status = 'ACTIVE'
    )
  );

drop policy if exists applications_read_own on public.job_applications;
create policy applications_read_own on public.job_applications
  for select to authenticated
  using (
    candidate_id in (
      select cp.id from public.candidate_profiles cp
      where cp.user_id = (select auth.uid())
    )
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'CANDIDATE'
        and p.status = 'ACTIVE'
    )
  );

drop policy if exists applications_insert_own on public.job_applications;
create policy applications_insert_own on public.job_applications
  for insert to authenticated
  with check (
    candidate_id in (
      select cp.id from public.candidate_profiles cp
      where cp.user_id = (select auth.uid())
    )
    and status = 'SUBMITTED'
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.role = 'CANDIDATE'
        and p.status = 'ACTIVE'
    )
  );

drop policy if exists saved_jobs_read_own on public.saved_jobs;
create policy saved_jobs_read_own on public.saved_jobs
  for select to authenticated
  using (
    candidate_id in (
      select cp.id from public.candidate_profiles cp
      where cp.user_id = (select auth.uid())
    )
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.status = 'ACTIVE'
    )
  );

drop policy if exists saved_jobs_insert_own on public.saved_jobs;
create policy saved_jobs_insert_own on public.saved_jobs
  for insert to authenticated
  with check (
    candidate_id in (
      select cp.id from public.candidate_profiles cp
      where cp.user_id = (select auth.uid())
    )
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.status = 'ACTIVE'
    )
  );

drop policy if exists saved_jobs_delete_own on public.saved_jobs;
create policy saved_jobs_delete_own on public.saved_jobs
  for delete to authenticated
  using (
    candidate_id in (
      select cp.id from public.candidate_profiles cp
      where cp.user_id = (select auth.uid())
    )
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.status = 'ACTIVE'
    )
  );

drop policy if exists "Users can view own notifications" on public.notifications;
create policy notifications_read_active_own on public.notifications
  for select to authenticated
  using (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.status = 'ACTIVE'
    )
  );

drop policy if exists notifications_mark_read on public.notifications;
create policy notifications_mark_read on public.notifications
  for update to authenticated
  using (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.status = 'ACTIVE'
    )
  )
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.status = 'ACTIVE'
    )
  );

drop policy if exists candidate_photo_select_own on storage.objects;
create policy candidate_photo_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'profile-photos'
    and name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$')
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'CANDIDATE' and p.status = 'ACTIVE'
    )
  );

drop policy if exists candidate_photo_insert_own on storage.objects;
create policy candidate_photo_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'profile-photos'
    and name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$')
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'CANDIDATE' and p.status = 'ACTIVE'
    )
  );

drop policy if exists candidate_photo_update_own on storage.objects;
create policy candidate_photo_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'profile-photos'
    and name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$')
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'CANDIDATE' and p.status = 'ACTIVE'
    )
  )
  with check (
    bucket_id = 'profile-photos'
    and name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|png|webp)$')
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'CANDIDATE' and p.status = 'ACTIVE'
    )
  );

drop policy if exists candidate_photo_delete_own on storage.objects;
create policy candidate_photo_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'profile-photos'
    and name ~ ('^' || (select auth.uid())::text || '/avatar[.](jpg|jpeg|webp|png)$')
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'CANDIDATE' and p.status = 'ACTIVE'
    )
  );
