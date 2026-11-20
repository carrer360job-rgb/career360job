-- Existing paid orders and credits remain intact. Only new purchases use these plans.
update public.employer_plans set is_active=false, updated_at=now()
where id in ('standard_15','featured_30','elite_all_tn');

alter table public.employer_orders
  add column if not exists tax_mode text,
  add column if not exists tax_rate_bps integer,
  add column if not exists refund_status text,
  add column if not exists refund_id text,
  add column if not exists refund_reason text,
  add column if not exists refund_requested_at timestamptz;

insert into public.employer_plans
  (id,name,tier,price_paise,tax_mode,tax_rate_bps,job_credits,listing_days,
   credit_validity_days,profile_unlock_limit,reach,sort_order,features,is_active,version,badge)
values
  ('monthly','Monthly','monthly',19900,'inclusive',1800,10,30,30,1000,'district',0,
   array['10 job posts','Valid for one month','Manage applicants'],true,1,'1 month'),
  ('quarterly','Quarterly','quarterly',49900,'inclusive',1800,50,90,90,1000,'district',1,
   array['50 job posts','Valid for three months','Manage applicants'],true,1,'3 months'),
  ('yearly','Yearly','yearly',199900,'inclusive',1800,150,365,365,1000,'district',2,
   array['150 job posts','Valid for twelve months','Manage applicants'],true,1,'12 months')
on conflict (id) do nothing;

create table if not exists public.employer_subscriptions (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.employers(id),
  order_id text unique references public.employer_orders(id),
  plan_id text not null,
  plan_version integer not null,
  plan_name text not null,
  total_posts integer not null check (total_posts > 0),
  used_posts integer not null default 0 check (used_posts >= 0 and used_posts <= total_posts),
  starts_at timestamptz not null,
  expires_at timestamptz not null,
  status text not null check (status in ('active','replaced','expired','suspended','refunded')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists employer_subscriptions_employer_created_idx
  on public.employer_subscriptions(employer_id, created_at desc);
create unique index if not exists employer_subscriptions_one_active_idx
  on public.employer_subscriptions(employer_id) where status='active';
alter table public.employer_subscriptions enable row level security;
revoke all on public.employer_subscriptions from public, anon, authenticated;
grant select on public.employer_subscriptions to authenticated;
create policy employer_subscriptions_read_own on public.employer_subscriptions
  for select to authenticated using (
    employer_id in (select id from public.employers where user_id=(select auth.uid()))
  );

create or replace function public.fulfill_employer_order(
  p_order_id text, p_payment_id text, p_amount bigint,
  p_currency text, p_amount_refunded bigint
) returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare
  v_order public.employer_orders%rowtype;
  v_employer public.employers%rowtype;
  v_now timestamptz := now();
  v_expiry timestamptz;
begin
  select * into v_order from public.employer_orders where id=p_order_id for update;
  if not found then raise exception 'Unknown payment order'; end if;
  if v_order.status='paid' then return jsonb_build_object('alreadyGranted',true); end if;
  if v_order.status='refunded' then raise exception 'This order was refunded'; end if;
  if p_amount<>v_order.amount_paise or p_currency<>v_order.currency
     or p_amount_refunded>0 or p_payment_id is null then
    raise exception 'Payment details do not match the order';
  end if;
  select * into v_employer from public.employers where id=v_order.employer_id for update;
  if not found then raise exception 'Company not found'; end if;
  v_expiry := v_now + make_interval(days=>v_order.credit_validity_days);
  update public.employer_subscriptions
    set status='replaced',updated_at=v_now
    where employer_id=v_order.employer_id and status='active';
  if v_order.plan_id in ('monthly','quarterly','yearly') then
    insert into public.employer_subscriptions
      (employer_id,order_id,plan_id,plan_version,plan_name,total_posts,starts_at,expires_at,status)
    values (v_order.employer_id,v_order.id,v_order.plan_id,v_order.plan_version,
            v_order.plan_name,v_order.job_credits,v_now,v_expiry,'active');
  end if;
  update public.employers set
    posting_credits=v_order.job_credits, credits_expire_at=v_expiry,
    listing_days=v_order.listing_days,active_plan=v_order.plan_id,
    active_plan_name=v_order.plan_name,plan_tier=v_order.tier,
    plan_reach=v_order.reach,updated_at=v_now
  where id=v_order.employer_id;
  insert into public.employer_entitlements
    (employer_id,order_id,plan_id,plan_name,tier,reach,
     profile_unlock_limit,unlocks_used,starts_at,expires_at)
  values (v_order.employer_id,v_order.id,v_order.plan_id,v_order.plan_name,
          v_order.tier,v_order.reach,v_order.profile_unlock_limit,0,v_now,v_expiry)
  on conflict (employer_id) do update set
    order_id=excluded.order_id,plan_id=excluded.plan_id,plan_name=excluded.plan_name,
    tier=excluded.tier,reach=excluded.reach,
    profile_unlock_limit=excluded.profile_unlock_limit,unlocks_used=0,
    starts_at=excluded.starts_at,expires_at=excluded.expires_at,updated_at=v_now;
  update public.employer_orders set status='paid',payment_id=p_payment_id,paid_at=v_now
    where id=p_order_id;
  insert into public.notifications(user_id,title,message,type)
    values(v_order.employer_user_id,'Subscription active',
           v_order.plan_name || ' is active with ' || v_order.job_credits || ' job posts.',
           'employer_payment');
  return jsonb_build_object('alreadyGranted',false);
end; $$;
revoke all on function public.fulfill_employer_order(text,text,bigint,text,bigint)
  from public,anon,authenticated;
grant execute on function public.fulfill_employer_order(text,text,bigint,text,bigint) to service_role;

create or replace function public.track_subscription_job()
returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
declare v_subscription public.employer_subscriptions%rowtype;
begin
  if new.status <> 'PUBLISHED' or new.plan_order_id is null then return new; end if;
  select * into v_subscription from public.employer_subscriptions
    where employer_id=new.employer_id and order_id=new.plan_order_id and status='active'
    for update;
  if not found then return new; end if; -- Legacy orders predate subscription records.
  if v_subscription.expires_at<=now() or v_subscription.used_posts>=v_subscription.total_posts then
    raise exception 'Subscription expired or job quota reached';
  end if;
  update public.employer_subscriptions set used_posts=used_posts+1,updated_at=now()
    where id=v_subscription.id;
  new.expires_at := least(new.expires_at,v_subscription.expires_at);
  return new;
end; $$;
drop trigger if exists track_subscription_job_before_insert on public.jobs;
create trigger track_subscription_job_before_insert before insert on public.jobs
for each row execute function public.track_subscription_job();

create or replace function public.refund_employer_order(
  p_order_id text,p_payment_id text,p_amount bigint,p_currency text
) returns boolean language plpgsql security invoker set search_path=public,pg_temp as $$
declare v_order public.employer_orders%rowtype;
begin
  select * into v_order from public.employer_orders where id=p_order_id for update;
  if not found or v_order.amount_paise<>p_amount or v_order.currency<>p_currency
     or (v_order.payment_id is not null and v_order.payment_id<>p_payment_id) then return false; end if;
  if v_order.status='refunded' then return true; end if;
  update public.employer_orders set status='refunded',payment_id=p_payment_id,
    refund_status='processed',refunded_at=now()
    where id=p_order_id;
  update public.employer_subscriptions set status='refunded',updated_at=now()
    where order_id=p_order_id and status<>'refunded';
  if exists(select 1 from public.employer_entitlements
      where employer_id=v_order.employer_id and order_id=p_order_id) then
    update public.employer_entitlements set expires_at=now(),updated_at=now()
      where employer_id=v_order.employer_id;
    update public.employers set posting_credits=0,credits_expire_at=now(),updated_at=now()
      where id=v_order.employer_id;
  end if;
  update public.jobs set status='CLOSED',updated_at=now()
    where plan_order_id=p_order_id and status='PUBLISHED';
  return true;
end; $$;
revoke all on function public.refund_employer_order(text,text,bigint,text) from public,anon,authenticated;
grant execute on function public.refund_employer_order(text,text,bigint,text) to service_role;

create or replace function public.admin_adjust_employer_quota(
  p_actor_uid uuid,p_employer_uid uuid,p_delta integer,p_reason text
) returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare
  v_employer public.employers%rowtype;
  v_subscription public.employer_subscriptions%rowtype;
  v_reason text := left(trim(coalesce(p_reason,'')),500);
begin
  if p_delta=0 or abs(p_delta)>10000 or length(v_reason)<5 then
    raise exception 'Enter a valid quota change and reason';
  end if;
  select * into v_employer from public.employers where user_id=p_employer_uid for update;
  if not found then raise exception 'Employer not found'; end if;
  select * into v_subscription from public.employer_subscriptions
    where employer_id=v_employer.id and status='active' and expires_at>now() for update;
  if not found then raise exception 'No active subscription'; end if;
  if v_subscription.total_posts+p_delta < v_subscription.used_posts or
     v_subscription.total_posts+p_delta < 1 then
    raise exception 'Quota cannot fall below posts already used';
  end if;
  update public.employer_subscriptions
    set total_posts=total_posts+p_delta,updated_at=now() where id=v_subscription.id;
  update public.employers
    set posting_credits=v_subscription.total_posts+p_delta-v_subscription.used_posts,
        updated_at=now() where id=v_employer.id;
  insert into public.admin_audit(actor_uid,employer_uid,action,notes,target_type,target_id)
    values(p_actor_uid,p_employer_uid,'employer_quota_adjusted',
           'Change '||p_delta||'; '||v_reason,'subscription',v_subscription.id::text);
  return jsonb_build_object('totalPosts',v_subscription.total_posts+p_delta,
                            'usedPosts',v_subscription.used_posts);
end; $$;
revoke all on function public.admin_adjust_employer_quota(uuid,uuid,integer,text)
  from public,anon,authenticated;
grant execute on function public.admin_adjust_employer_quota(uuid,uuid,integer,text) to service_role;

drop policy if exists applications_insert_own on public.job_applications;
create policy applications_insert_own on public.job_applications for insert to authenticated
with check (
  candidate_id in (select id from public.candidate_profiles where user_id=(select auth.uid()))
  and status='SUBMITTED'
  and exists(select 1 from public.profiles where id=(select auth.uid())
             and role='CANDIDATE' and status='ACTIVE')
  and exists(select 1 from public.jobs
             where id=job_id and status='PUBLISHED'
               and (expires_at is null or expires_at>now()))
);
