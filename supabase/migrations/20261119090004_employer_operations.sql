alter table public.employers
  add column if not exists listing_days integer not null default 7,
  add column if not exists active_plan_name text;

create or replace function public.prevent_employer_self_approval()
returns trigger language plpgsql security invoker set search_path = public, pg_temp
as $$
begin
  if (select auth.role()) = 'authenticated' and (
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
    raise exception 'Employer approval and plan fields cannot be changed';
  end if;
  return new;
end;
$$;

alter table public.jobs
  add column if not exists company_name text,
  add column if not exists is_verified boolean not null default false,
  add column if not exists salary_text text,
  add column if not exists work_mode text,
  add column if not exists contact_name text,
  add column if not exists plan_order_id text,
  add column if not exists plan_tier text,
  add column if not exists plan_name text;

update public.jobs j set company_name=e.company_name, is_verified=e.is_verified
from public.employers e where j.employer_id=e.id and j.company_name is null;

create table if not exists public.employer_orders (
  id text primary key,
  employer_id uuid not null references public.employers(id),
  employer_user_id uuid not null references auth.users(id),
  plan_id text not null,
  plan_version integer not null,
  plan_name text not null,
  tier text not null,
  amount_paise bigint not null check (amount_paise >= 100),
  base_paise bigint not null default 0,
  tax_paise bigint not null default 0,
  currency text not null default 'INR',
  job_credits integer not null check (job_credits > 0),
  listing_days integer not null check (listing_days > 0),
  credit_validity_days integer not null check (credit_validity_days > 0),
  profile_unlock_limit integer not null default 0,
  reach text not null default 'district',
  status text not null default 'created' check (status in ('created','failed','paid','refunded')),
  payment_id text,
  failure_code text,
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  failed_at timestamptz,
  refunded_at timestamptz
);
create index if not exists employer_orders_employer_created_idx
  on public.employer_orders(employer_id, created_at desc);
alter table public.employer_orders enable row level security;
create policy employer_orders_read_own on public.employer_orders for select to authenticated
using (employer_user_id = (select auth.uid()));
grant select on public.employer_orders to authenticated;

create table if not exists public.employer_entitlements (
  employer_id uuid primary key references public.employers(id) on delete cascade,
  order_id text not null references public.employer_orders(id),
  plan_id text not null,
  plan_name text not null,
  tier text not null,
  reach text not null,
  profile_unlock_limit integer not null,
  unlocks_used integer not null default 0,
  starts_at timestamptz not null,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);
alter table public.employer_entitlements enable row level security;
revoke all on public.employer_entitlements from public, anon, authenticated;

create table if not exists public.employer_candidate_unlocks (
  employer_id uuid not null references public.employers(id) on delete cascade,
  candidate_id uuid not null references public.candidate_profiles(id) on delete cascade,
  order_id text not null references public.employer_orders(id),
  application_id uuid not null references public.job_applications(id),
  unlocked_at timestamptz not null default now(),
  primary key (employer_id, candidate_id, order_id)
);
alter table public.employer_candidate_unlocks enable row level security;
revoke all on public.employer_candidate_unlocks from public, anon, authenticated;

create table if not exists public.job_reports (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  candidate_user_id uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  details text not null default '',
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  unique(job_id, candidate_user_id)
);
alter table public.job_reports enable row level security;
revoke all on public.job_reports from public, anon, authenticated;

create or replace function public.fulfill_employer_order(
  p_order_id text, p_payment_id text, p_amount bigint,
  p_currency text, p_amount_refunded bigint
) returns jsonb language plpgsql security invoker set search_path = public, pg_temp
as $$
declare
  v_order public.employer_orders%rowtype;
  v_employer public.employers%rowtype;
  v_now timestamptz := now();
  v_expiry timestamptz;
begin
  select * into v_order from public.employer_orders where id = p_order_id for update;
  if not found then raise exception 'Unknown payment order'; end if;
  if v_order.status = 'paid' then return jsonb_build_object('alreadyGranted', true); end if;
  if v_order.status = 'refunded' then raise exception 'This order was refunded'; end if;
  if p_amount <> v_order.amount_paise or p_currency <> v_order.currency
      or p_amount_refunded > 0 or p_payment_id is null then
    raise exception 'Payment details do not match the order';
  end if;
  select * into v_employer from public.employers where id = v_order.employer_id for update;
  if not found then raise exception 'Company not found'; end if;
  v_expiry := greatest(coalesce(v_employer.credits_expire_at, v_now),
    v_now + make_interval(days => v_order.credit_validity_days));
  update public.employers set
    posting_credits = (case when credits_expire_at > v_now then coalesce(posting_credits,0) else 0 end)
      + v_order.job_credits,
    credits_expire_at = v_expiry,
    listing_days = v_order.listing_days,
    active_plan = v_order.plan_id,
    active_plan_name = v_order.plan_name,
    plan_tier = v_order.tier,
    plan_reach = v_order.reach,
    updated_at = v_now
  where id = v_order.employer_id;
  insert into public.employer_entitlements (
    employer_id, order_id, plan_id, plan_name, tier, reach,
    profile_unlock_limit, unlocks_used, starts_at, expires_at
  ) values (
    v_order.employer_id, v_order.id, v_order.plan_id, v_order.plan_name,
    v_order.tier, v_order.reach, v_order.profile_unlock_limit, 0, v_now,
    v_now + make_interval(days => v_order.credit_validity_days)
  ) on conflict (employer_id) do update set
    order_id = excluded.order_id, plan_id = excluded.plan_id,
    plan_name = excluded.plan_name, tier = excluded.tier, reach = excluded.reach,
    profile_unlock_limit = excluded.profile_unlock_limit, unlocks_used = 0,
    starts_at = excluded.starts_at, expires_at = excluded.expires_at, updated_at = v_now;
  update public.employer_orders set status='paid', payment_id=p_payment_id, paid_at=v_now
    where id=p_order_id;
  insert into public.notifications (user_id,title,message,type)
    values (v_order.employer_user_id,'Posting credit ready',
      v_order.job_credits || ' job posting credit(s) added to your company account.',
      'employer_payment');
  return jsonb_build_object('alreadyGranted', false);
end;
$$;
revoke all on function public.fulfill_employer_order(text,text,bigint,text,bigint)
  from public, anon, authenticated;
grant execute on function public.fulfill_employer_order(text,text,bigint,text,bigint)
  to service_role;

create or replace function public.refund_employer_order(
  p_order_id text, p_payment_id text, p_amount bigint, p_currency text
) returns boolean language plpgsql security invoker set search_path = public, pg_temp
as $$
declare v_order public.employer_orders%rowtype;
begin
  select * into v_order from public.employer_orders where id=p_order_id for update;
  if not found or v_order.amount_paise <> p_amount or v_order.currency <> p_currency
      or (v_order.payment_id is not null and v_order.payment_id <> p_payment_id) then
    return false;
  end if;
  if v_order.status = 'refunded' then return true; end if;
  update public.employer_orders set status='refunded', payment_id=p_payment_id,
    refunded_at=now() where id=p_order_id;
  if exists (select 1 from public.employer_entitlements
      where employer_id=v_order.employer_id and order_id=p_order_id) then
    update public.employer_entitlements set expires_at=now(), updated_at=now()
      where employer_id=v_order.employer_id;
    update public.employers set posting_credits=0, credits_expire_at=now(), updated_at=now()
      where id=v_order.employer_id;
  end if;
  update public.jobs set status='CLOSED', updated_at=now()
    where plan_order_id=p_order_id and status='PUBLISHED';
  return true;
end;
$$;
revoke all on function public.refund_employer_order(text,text,bigint,text)
  from public, anon, authenticated;
grant execute on function public.refund_employer_order(text,text,bigint,text)
  to service_role;

create or replace function public.publish_employer_job(p_user_id uuid, p_job jsonb)
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
    'PUBLISHED',v_entitlement.tier in ('featured','elite'),
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
revoke all on function public.publish_employer_job(uuid,jsonb) from public, anon, authenticated;
grant execute on function public.publish_employer_job(uuid,jsonb) to service_role;

create or replace function public.unlock_employer_candidate(
  p_user_id uuid, p_application_id uuid
) returns jsonb language plpgsql security invoker set search_path = public, pg_temp
as $$
declare
  v_employer public.employers%rowtype;
  v_entitlement public.employer_entitlements%rowtype;
  v_application public.job_applications%rowtype;
begin
  select * into v_employer from public.employers where user_id=p_user_id and is_verified=true;
  if not found then raise exception 'Approved company required'; end if;
  select * into v_application from public.job_applications
    where id=p_application_id and employer_id=v_employer.id;
  if not found then raise exception 'Application not found'; end if;
  select * into v_entitlement from public.employer_entitlements
    where employer_id=v_employer.id for update;
  if not found or v_entitlement.expires_at <= now() then
    raise exception 'Choose an active plan to unlock applicants';
  end if;
  if exists (select 1 from public.employer_candidate_unlocks
      where employer_id=v_employer.id and candidate_id=v_application.candidate_id
        and order_id=v_entitlement.order_id) then
    return jsonb_build_object('alreadyUnlocked', true);
  end if;
  if v_entitlement.unlocks_used >= v_entitlement.profile_unlock_limit then
    raise exception 'Your plan has no profile unlocks remaining';
  end if;
  insert into public.employer_candidate_unlocks
    (employer_id,candidate_id,order_id,application_id)
    values (v_employer.id,v_application.candidate_id,v_entitlement.order_id,p_application_id);
  update public.employer_entitlements set unlocks_used=unlocks_used+1,updated_at=now()
    where employer_id=v_employer.id;
  return jsonb_build_object('alreadyUnlocked', false);
end;
$$;
revoke all on function public.unlock_employer_candidate(uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.unlock_employer_candidate(uuid,uuid) to service_role;
