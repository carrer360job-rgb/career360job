alter table public.employer_plans
  add column if not exists badge text not null default '',
  add column if not exists tax_mode text not null default 'inclusive',
  add column if not exists tax_rate_bps integer not null default 1800,
  add column if not exists credit_validity_days integer not null default 30,
  add column if not exists profile_unlock_limit integer not null default 25,
  add column if not exists sort_order integer not null default 0,
  add column if not exists version integer not null default 1,
  add column if not exists draft jsonb,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.platform_content (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('category', 'announcement')),
  title text not null,
  content text not null default '',
  active boolean not null default true,
  sort_order integer not null default 0,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists platform_content_public_order_idx
  on public.platform_content (kind, active, sort_order);

alter table public.platform_content enable row level security;
revoke all on table public.platform_content from public, anon, authenticated;

alter table public.admin_audit alter column employer_uid drop not null;
alter table public.admin_audit
  add column if not exists target_type text,
  add column if not exists target_id text;
