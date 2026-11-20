alter table public.employers
  add column if not exists review_state text not null default 'pending'
    check (review_state in ('pending', 'approved', 'rejected', 'suspended'));

update public.employers e
set review_state = case
  when e.is_verified then 'approved'
  when e.reviewed_at is not null and e.rejection_reason is not null then 'rejected'
  else 'pending'
end;

create or replace function public.prevent_employer_self_approval()
returns trigger language plpgsql security invoker set search_path = public, pg_temp
as $$
begin
  if (select auth.role()) = 'authenticated' and (
    new.email is distinct from old.email or
    new.review_state is distinct from old.review_state or
    new.is_verified is distinct from old.is_verified or
    new.posting_credits is distinct from old.posting_credits or
    new.credits_expire_at is distinct from old.credits_expire_at or
    new.active_plan is distinct from old.active_plan or
    new.active_plan_name is distinct from old.active_plan_name or
    new.listing_days is distinct from old.listing_days or
    new.plan_tier is distinct from old.plan_tier or
    new.plan_reach is distinct from old.plan_reach or
    new.reviewed_by is distinct from old.reviewed_by or
    new.reviewed_at is distinct from old.reviewed_at or
    new.rejection_reason is distinct from old.rejection_reason
  ) then
    raise exception 'Employer identity, approval, and plan fields cannot be changed';
  end if;
  return new;
end;
$$;

create or replace function public.admin_review_employer(
  p_actor_uid uuid, p_employer_uid uuid, p_decision text, p_notes text default null
) returns jsonb language plpgsql security invoker set search_path = public, pg_temp as $$
declare
  v_employer public.employers%rowtype;
  v_reason text := left(trim(coalesce(p_notes, '')), 500);
  v_state text;
begin
  if p_decision not in ('approved', 'rejected') then
    raise exception 'Invalid employer decision';
  end if;
  if p_decision = 'rejected' and length(v_reason) < 3 then
    raise exception 'A rejection reason is required';
  end if;
  select * into v_employer from public.employers
    where user_id = p_employer_uid for update;
  if v_employer.id is null then
    raise exception 'Employer account not found';
  end if;
  if p_decision = 'approved' then
    v_state := 'approved';
  elsif v_employer.review_state = 'approved' then
    v_state := 'suspended';
  else
    v_state := 'rejected';
  end if;
  update public.profiles
    set status = case when v_state = 'approved' then 'ACTIVE'::public.account_status
                      else 'SUSPENDED'::public.account_status end,
        updated_at = now()
    where id = p_employer_uid and role = 'EMPLOYER'::public.user_role;
  if not found then raise exception 'Employer profile not found'; end if;
  update public.employers
    set is_verified = v_state = 'approved', review_state = v_state,
        reviewed_by = p_actor_uid, reviewed_at = now(),
        rejection_reason = case when v_state = 'approved' then null else v_reason end,
        updated_at = now()
    where id = v_employer.id;
  if v_state <> 'approved' then
    update public.jobs set status = 'CLOSED'::public.job_status, updated_at = now()
      where employer_id = v_employer.id and status = 'PUBLISHED'::public.job_status;
  end if;
  insert into public.notifications (user_id, title, message, type)
    values (p_employer_uid,
      case when v_state = 'approved' then 'Company approved' else 'Company review update' end,
      case when v_state = 'approved' then 'Your company profile has been approved.' else v_reason end,
      'employer_review');
  insert into public.admin_audit (actor_uid, employer_uid, action, notes)
    values (p_actor_uid, p_employer_uid, 'employer_' || v_state,
      case when v_state = 'approved' then null else v_reason end);
  return jsonb_build_object('uid', p_employer_uid, 'status', v_state);
end;
$$;

-- Existing sessions must not read employer private data after review is revoked.
drop policy if exists jobs_employer_read_own on public.jobs;
create policy jobs_employer_read_own on public.jobs for select to authenticated
using (employer_id in (
  select e.id from public.employers e join public.profiles p on p.id=e.user_id
  where e.user_id=(select auth.uid()) and e.review_state='approved'
    and e.is_verified and p.status='ACTIVE'
));
drop policy if exists employer_orders_read_own on public.employer_orders;
create policy employer_orders_read_own on public.employer_orders for select to authenticated
using (employer_user_id=(select auth.uid()) and exists (
  select 1 from public.employers e join public.profiles p on p.id=e.user_id
  where e.id=employer_id and e.review_state='approved'
    and e.is_verified and p.status='ACTIVE'
));

drop policy if exists "Employers can view applications for their jobs" on public.job_applications;
create policy employer_applications_read_approved on public.job_applications
  for select to authenticated
  using (employer_id in (
    select e.id from public.employers e join public.profiles p on p.id=e.user_id
    where e.user_id=(select auth.uid()) and e.review_state='approved'
      and e.is_verified and p.status='ACTIVE'
  ));

do $$ begin
  if not exists (select 1 from pg_publication_tables
      where pubname='supabase_realtime' and schemaname='public' and tablename='employers') then
    alter publication supabase_realtime add table public.employers;
  end if;
end $$;
