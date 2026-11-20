alter table public.job_applications
  add column if not exists applicant_email text,
  add column if not exists education_details text,
  add column if not exists experience_level text,
  add column if not exists notice_period text,
  add column if not exists skills text[] not null default '{}',
  add column if not exists cover_note text,
  add column if not exists resume_file_name text;

-- Resumes are private; the candidate uploads to a folder named with their auth ID.
create policy resumes_candidate_upload on storage.objects for insert to authenticated
with check (bucket_id='resumes' and (storage.foldername(name))[1]=(select auth.uid())::text
  and lower(storage.extension(name)) in ('pdf','doc','docx')
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='CANDIDATE' and p.status='ACTIVE'));
create policy resumes_candidate_read on storage.objects for select to authenticated
using (bucket_id='resumes' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy resumes_candidate_cleanup on storage.objects for delete to authenticated
using (bucket_id='resumes' and (storage.foldername(name))[1]=(select auth.uid())::text);

drop policy if exists applications_insert_own on public.job_applications;
create policy applications_insert_own on public.job_applications for insert to authenticated with check (
  candidate_id in (select cp.id from public.candidate_profiles cp where cp.user_id=(select auth.uid()))
  and status='SUBMITTED'
  and employer_id=(select j.employer_id from public.jobs j where j.id=job_id and j.status='PUBLISHED'
    and (j.expires_at is null or j.expires_at>now()))
  and (resume_url is null or resume_url like (select auth.uid())::text || '/%')
  and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='CANDIDATE' and p.status='ACTIVE')
);
