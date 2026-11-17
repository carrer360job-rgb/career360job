-- Persist each candidate onboarding step without marking partial profiles complete.
alter table public.candidate_profiles
  add column if not exists personal_details jsonb not null default '{}'::jsonb,
  add column if not exists preferred_job_titles text[] not null default '{}'::text[],
  add column if not exists onboarding_step smallint not null default 0,
  add column if not exists onboarding_completed_at timestamptz;

alter table public.candidate_profiles
  add constraint candidate_onboarding_step_range check (onboarding_step between 0 and 4),
  add constraint candidate_onboarding_completed_step check (
    onboarding_completed_at is null or onboarding_step = 4
  ),
  add constraint candidate_onboarding_required_fields check (
    onboarding_completed_at is null or (
      length(trim(full_name)) > 0
      and length(trim(district)) > 0
      and length(trim(coalesce(personal_details->>'gender', ''))) > 0
      and length(trim(coalesce(personal_details->>'maritalStatus', ''))) > 0
      and length(trim(coalesce(personal_details->>'state', ''))) > 0
      and length(trim(coalesce(personal_details->>'birthMonth', ''))) > 0
      and jsonb_typeof(personal_details->'birthYear') = 'number'
      and length(trim(coalesce(education->>'educationLevel', ''))) > 0
      and length(trim(coalesce(education->>'qualification', ''))) > 0
      and jsonb_typeof(education->'graduationYear') = 'number'
      and cardinality(preferred_job_titles) between 1 and 4
      and jsonb_typeof(experience->'hasExperience') = 'boolean'
    ) is true
  );

drop policy if exists "Candidates can view and edit own profile" on public.candidate_profiles;
create policy candidate_profiles_read_own on public.candidate_profiles
  for select to authenticated using ((select auth.uid()) = user_id);
create policy candidate_profiles_insert_own on public.candidate_profiles
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy candidate_profiles_update_own on public.candidate_profiles
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
