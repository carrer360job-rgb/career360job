-- Jobs are private until an administrator publishes them.
alter type public.job_status add value if not exists 'PENDING_REVIEW';
alter type public.job_status add value if not exists 'REJECTED';
