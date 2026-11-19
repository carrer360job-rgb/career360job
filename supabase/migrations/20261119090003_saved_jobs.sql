create table if not exists public.saved_jobs (
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (candidate_id, job_id)
);

alter table public.saved_jobs enable row level security;
create policy saved_jobs_read_own on public.saved_jobs for select to authenticated
using (candidate_id in (
  select id from public.candidate_profiles where user_id = (select auth.uid())
));
create policy saved_jobs_insert_own on public.saved_jobs for insert to authenticated
with check (candidate_id in (
  select id from public.candidate_profiles where user_id = (select auth.uid())
));
create policy saved_jobs_delete_own on public.saved_jobs for delete to authenticated
using (candidate_id in (
  select id from public.candidate_profiles where user_id = (select auth.uid())
));
grant select, insert, delete on public.saved_jobs to authenticated;
