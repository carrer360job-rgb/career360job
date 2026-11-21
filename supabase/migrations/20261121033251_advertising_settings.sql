create table public.ad_settings (
 id boolean primary key default true check (id),
 enabled boolean not null default false,
 banner boolean not null default true,
 native boolean not null default true,
 native_interval integer not null default 5 check (native_interval between 5 and 12),
 interstitial boolean not null default false,
 interstitial_views integer not null default 5 check(interstitial_views between 5 and 20),
 cooldown_minutes integer not null default 10 check(cooldown_minutes between 10 and 60),
 daily_cap integer not null default 2 check(daily_cap between 1 and 2),
 updated_by uuid references auth.users(id),
 updated_at timestamptz not null default now()
);
insert into public.ad_settings(id) values(true);
alter table public.ad_settings enable row level security;
revoke all on public.ad_settings from public, anon, authenticated;
create table public.ad_settings_audit (
 id bigint generated always as identity primary key,
 actor uuid references auth.users(id),
 settings jsonb not null,
 created_at timestamptz not null default now()
);
alter table public.ad_settings_audit enable row level security;
revoke all on public.ad_settings_audit from public, anon, authenticated;
create function public.audit_ad_settings() returns trigger language plpgsql set search_path = '' as $$
begin
 insert into public.ad_settings_audit(actor,settings) values(new.updated_by,to_jsonb(new));
 return new;
end $$;
create trigger ad_settings_audit after update on public.ad_settings for each row execute function public.audit_ad_settings();

revoke execute on function public.audit_ad_settings() from public, anon, authenticated;
