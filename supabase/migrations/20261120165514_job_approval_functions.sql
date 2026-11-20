alter table public.jobs add column if not exists reviewed_by uuid;
alter table public.jobs add column if not exists reviewed_at timestamptz;
alter table public.jobs add column if not exists review_notes text;

-- Replace all previous read policies so candidates cannot retrieve pending listings.
do $$ declare p record; begin
  for p in select policyname from pg_policies where schemaname='public' and tablename='jobs' and cmd in ('SELECT','ALL') loop
    execute format('drop policy if exists %I on public.jobs',p.policyname);
  end loop;
end $$;
alter table public.jobs enable row level security;
create policy jobs_public_live_read on public.jobs for select to anon,authenticated
  using (status='PUBLISHED' and (expires_at is null or expires_at>now()));
create policy jobs_employer_read_own on public.jobs for select to authenticated
  using (employer_id in (select e.id from public.employers e join public.profiles p on p.id=e.user_id
    where e.user_id=(select auth.uid()) and e.review_state='approved' and e.is_verified and p.status='ACTIVE'));

create or replace function public.submit_employer_job(p_user_id uuid, p_job jsonb)
returns uuid language plpgsql security invoker set search_path = public, pg_temp
as $$
declare
  v_employer public.employers%rowtype;
  v_entitlement public.employer_entitlements%rowtype;
  v_id uuid;
  v_now timestamptz := now();
begin
  select e.* into v_employer from public.employers e
    join public.profiles p on p.id=e.user_id
    where e.user_id=p_user_id and e.is_verified=true and e.reviewed_at is not null
      and e.reviewed_by is not null and p.role='EMPLOYER' and p.status='ACTIVE'
    for update of e;
  if not found then raise exception 'Your company is awaiting approval'; end if;
  select * into v_entitlement from public.employer_entitlements
    where employer_id=v_employer.id for update;
  if not found or v_entitlement.expires_at <= v_now or
      v_employer.credits_expire_at <= v_now or v_employer.posting_credits < 1 then
    raise exception 'Buy a valid posting plan before publishing';
  end if;
  if v_entitlement.reach <> 'statewide' and p_job->>'district'='All Tamil Nadu' then
    raise exception 'Choose a district for this plan';
  end if;
  insert into public.jobs (
    employer_id,company_name,is_verified,title,category,district,description,salary_text,work_mode,
    vacancies,contact_name,contact_phone,contact_whatsapp,contact_email,
    status,is_featured,reach,expires_at,plan_order_id,plan_tier,plan_name
  ) values (
    v_employer.id,v_employer.company_name,true,
    p_job->>'title',p_job->>'category',p_job->>'district',
    p_job->>'description',p_job->>'salaryText',p_job->>'workMode',
    (p_job->>'vacanciesCount')::integer,
    coalesce(nullif(p_job->>'contactName',''),v_employer.contact_name),
    coalesce(nullif(p_job->>'phone',''),v_employer.phone),
    coalesce(nullif(p_job->>'whatsappNumber',''),v_employer.whatsapp_phone,v_employer.phone),
    coalesce(nullif(p_job->>'email',''),v_employer.email),
    'PENDING_REVIEW',v_entitlement.tier in ('featured','elite'),
    case when v_entitlement.reach='statewide' and coalesce((p_job->>'isStatewide')::boolean,true)
      then 'statewide' else 'district' end,
    v_now + make_interval(days=>v_employer.listing_days),
    v_entitlement.order_id,v_entitlement.tier,v_entitlement.plan_name
  ) returning id into v_id;
  update public.employers set posting_credits=posting_credits-1,updated_at=v_now
    where id=v_employer.id;
  return v_id;
end;
$$;
revoke all on function public.submit_employer_job(uuid,jsonb) from public, anon, authenticated;
grant execute on function public.submit_employer_job(uuid,jsonb) to service_role;

-- Submission reserves one credit. Approval consumes the subscription post once.
create or replace function public.review_employer_job(p_job_id uuid,p_reviewer uuid,p_decision text,p_notes text default null)
returns text language plpgsql security invoker set search_path=public,pg_temp as $$
declare v_job public.jobs%rowtype; v_employer public.employers%rowtype;
  v_subscription public.employer_subscriptions%rowtype; v_now timestamptz:=now();
begin
  if not exists(select 1 from public.profiles where id=p_reviewer and role='ADMIN' and status='ACTIVE') then
    raise exception 'Administrator required';
  end if;
  if p_decision not in ('approved','rejected') then raise exception 'Invalid review decision'; end if;
  if p_decision='rejected' and length(trim(coalesce(p_notes,'')))<5 then
    raise exception 'A rejection reason is required';
  end if;
  select * into v_job from public.jobs where id=p_job_id for update;
  if not found or v_job.status<>'PENDING_REVIEW' then raise exception 'Job is no longer awaiting review'; end if;
  select * into v_employer from public.employers where id=v_job.employer_id for update;
  if p_decision='approved' then
    if not v_employer.is_verified or v_employer.review_state<>'approved' or
      not exists(select 1 from public.profiles where id=v_employer.user_id and role='EMPLOYER' and status='ACTIVE') then
      raise exception 'Employer is no longer approved';
    end if;
    select * into v_subscription from public.employer_subscriptions
      where employer_id=v_employer.id and order_id=v_job.plan_order_id and status='active' for update;
    if not found or v_subscription.expires_at<=v_now or v_subscription.used_posts>=v_subscription.total_posts then
      raise exception 'Subscription expired or job quota reached';
    end if;
    update public.employer_subscriptions set used_posts=used_posts+1,updated_at=v_now where id=v_subscription.id;
    update public.jobs set status='PUBLISHED',reviewed_by=p_reviewer,reviewed_at=v_now,
      review_notes=null,expires_at=least(v_now+make_interval(days=>v_employer.listing_days),v_subscription.expires_at),updated_at=v_now
      where id=p_job_id;
    return 'PUBLISHED';
  end if;
  update public.jobs set status='REJECTED',reviewed_by=p_reviewer,reviewed_at=v_now,
    review_notes=trim(p_notes),updated_at=v_now where id=p_job_id;
  update public.employers set posting_credits=posting_credits+1,updated_at=v_now
    where id=v_employer.id and credits_expire_at>v_now and exists (
      select 1 from public.employer_entitlements en
      where en.employer_id=v_employer.id and en.order_id=v_job.plan_order_id and en.expires_at>v_now);
  return 'REJECTED';
end; $$;
revoke all on function public.review_employer_job(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.review_employer_job(uuid,uuid,text,text) to service_role;
