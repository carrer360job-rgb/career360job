-- Recruiter application reads go through the backend, which enforces profile unlocks.
-- Candidates retain their own read policy for application status.
drop policy if exists employer_applications_read_approved on public.job_applications;
drop policy if exists "Employers can view applications for their jobs" on public.job_applications;
