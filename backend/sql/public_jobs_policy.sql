-- Public job reads must not evaluate the employer-only policy.
drop policy if exists "Employers can manage own jobs" on public.jobs;
create policy jobs_employer_read_own on public.jobs for select to authenticated
  using (employer_id in (select id from public.employers where user_id = (select auth.uid())));
