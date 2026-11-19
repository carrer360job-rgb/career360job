alter table public.employers
  add column if not exists reviewed_by uuid,
  add column if not exists reviewed_at timestamptz,
  add column if not exists rejection_reason text;

create table if not exists public.admin_audit (
  id uuid primary key default gen_random_uuid(),
  actor_uid uuid not null,
  employer_uid uuid not null,
  action text not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.admin_audit enable row level security;
revoke all on table public.admin_audit from public, anon, authenticated;

create or replace function public.admin_review_employer(
  p_actor_uid uuid,
  p_employer_uid uuid,
  p_decision text,
  p_notes text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_employer_id uuid;
  v_reason text := left(trim(coalesce(p_notes, '')), 500);
  v_count integer;
begin
  if p_decision not in ('approved', 'rejected') then
    raise exception 'Invalid employer decision';
  end if;
  if p_decision = 'rejected' and length(v_reason) < 3 then
    raise exception 'A rejection reason is required';
  end if;

  select id into v_employer_id
  from public.employers
  where user_id = p_employer_uid
  for update;
  if v_employer_id is null then
    raise exception 'Employer account not found';
  end if;

  update public.profiles
  set status = case when p_decision = 'approved' then 'ACTIVE'::public.account_status
                    else 'SUSPENDED'::public.account_status end,
      updated_at = now()
  where id = p_employer_uid and role = 'EMPLOYER'::public.user_role;
  get diagnostics v_count = row_count;
  if v_count <> 1 then
    raise exception 'Employer profile not found';
  end if;

  update public.employers
  set is_verified = p_decision = 'approved',
      reviewed_by = p_actor_uid,
      reviewed_at = now(),
      rejection_reason = case when p_decision = 'rejected' then v_reason else null end,
      updated_at = now()
  where id = v_employer_id;

  if p_decision = 'rejected' then
    update public.jobs
    set status = 'CLOSED'::public.job_status, updated_at = now()
    where employer_id = v_employer_id and status = 'PUBLISHED'::public.job_status;
  end if;

  insert into public.notifications (user_id, title, message, type)
  values (p_employer_uid,
    case when p_decision = 'approved' then 'Company approved' else 'Company review update' end,
    case when p_decision = 'approved' then 'Your company profile has been approved.' else v_reason end,
    'employer_review');

  insert into public.admin_audit (actor_uid, employer_uid, action, notes)
  values (p_actor_uid, p_employer_uid, 'employer_' || p_decision,
    case when p_decision = 'rejected' then v_reason else null end);

  return jsonb_build_object('uid', p_employer_uid, 'status', p_decision);
end;
$$;

revoke all on function public.admin_review_employer(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.admin_review_employer(uuid, uuid, text, text) to service_role;
