-- Allow candidates to complete older submitted applications that predate resume uploads.
-- Grant only the two resume columns; application status and employer fields remain protected.
grant update (resume_url, resume_file_name) on public.job_applications to authenticated;

create policy applications_attach_missing_resume on public.job_applications
for update to authenticated
using (
  status='SUBMITTED' and resume_url is null
  and candidate_id in (select cp.id from public.candidate_profiles cp
    where cp.user_id=(select auth.uid()))
  and exists(select 1 from public.profiles p where p.id=(select auth.uid())
    and p.role='CANDIDATE' and p.status='ACTIVE')
)
with check (
  status='SUBMITTED' and resume_url like (select auth.uid())::text || '/%'
  and length(resume_file_name) between 1 and 200
  and lower(resume_file_name) ~ '[.](pdf|doc|docx)$'
  and candidate_id in (select cp.id from public.candidate_profiles cp
    where cp.user_id=(select auth.uid()))
  and exists(select 1 from storage.objects o
    where o.bucket_id='resumes' and o.name=resume_url)
);
