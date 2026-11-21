alter table public.job_reports
  add column if not exists resolved_at timestamptz,
  add column if not exists resolved_by uuid references auth.users(id),
  add column if not exists resolution_notes text not null default '';

alter table public.job_reports
  add constraint job_reports_status_check
  check (status in ('pending', 'dismissed', 'job_closed'));

create index if not exists job_reports_status_created_idx
  on public.job_reports (status, created_at desc, id desc);
create index if not exists job_reports_job_status_idx
  on public.job_reports (job_id, status);

create or replace function public.resolve_job_report(
  p_report_id uuid, p_actor_uid uuid, p_decision text, p_notes text
) returns jsonb
language plpgsql security invoker set search_path = public, pg_temp
as $$
declare
  v_job_id uuid;
  v_job public.jobs%rowtype;
  v_report public.job_reports%rowtype;
  v_affected integer;
  v_employer_uid uuid;
begin
  if p_decision not in ('dismissed', 'job_closed') then
    raise exception 'Invalid report decision';
  end if;
  if length(coalesce(p_notes, '')) > 1000 or
     (p_decision = 'job_closed' and length(trim(coalesce(p_notes, ''))) < 5) then
    raise exception 'A reason of 5 to 1000 characters is required to close a job';
  end if;

  select job_id into v_job_id from public.job_reports where id = p_report_id;
  if not found then raise exception 'Report not found'; end if;

  -- Lock the job first so concurrent reviews of its reports serialize.
  select * into v_job from public.jobs where id = v_job_id for update;
  if not found then raise exception 'Reported job not found'; end if;
  select * into v_report from public.job_reports where id = p_report_id for update;
  if not found or v_report.status <> 'pending' then
    raise exception 'Report has already been reviewed';
  end if;

  if p_decision = 'job_closed' then
    if v_job.status = 'PUBLISHED' then
      update public.jobs set status = 'CLOSED', updated_at = now(),
        review_notes = trim(p_notes)
      where id = v_job.id;
    elsif v_job.status <> 'CLOSED' then
      raise exception 'Only a published or already closed job can be resolved as closed';
    end if;
    update public.job_reports set status = 'job_closed',
      resolved_at = now(), resolved_by = p_actor_uid,
      resolution_notes = trim(p_notes)
    where job_id = v_job.id and status = 'pending';
  else
    update public.job_reports set status = 'dismissed',
      resolved_at = now(), resolved_by = p_actor_uid,
      resolution_notes = trim(coalesce(p_notes, ''))
    where id = p_report_id and status = 'pending';
  end if;
  get diagnostics v_affected = row_count;

  insert into public.admin_audit
    (actor_uid, action, target_type, target_id, notes)
  values
    (p_actor_uid, 'job_report_' || p_decision, 'job_report',
      p_report_id::text, trim(coalesce(p_notes, '')));

  select user_id into v_employer_uid from public.employers where id = v_job.employer_id;
  return jsonb_build_object(
    'status', p_decision, 'jobId', v_job.id, 'jobTitle', v_job.title,
    'employerUid', v_employer_uid, 'affectedReports', v_affected
  );
end;
$$;

revoke all on function public.resolve_job_report(uuid, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.resolve_job_report(uuid, uuid, text, text)
  to service_role;
