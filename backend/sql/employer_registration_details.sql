-- Store all fields collected by the three employer registration steps.
-- Company approval, credits, and plan fields remain server controlled.
alter table public.employers
  add column if not exists industry text,
  add column if not exists company_size text,
  add column if not exists description text,
  add column if not exists whatsapp_phone text,
  add column if not exists whatsapp_same_as_phone boolean not null default false,
  add column if not exists website text,
  add column if not exists address text,
  add column if not exists state text,
  add column if not exists postal_code text;

grant insert (
  industry, company_size, description, whatsapp_phone,
  whatsapp_same_as_phone, website, address, state, postal_code
) on public.employers to authenticated;
grant update (
  industry, company_size, description, whatsapp_phone,
  whatsapp_same_as_phone, website, address, state, postal_code
) on public.employers to authenticated;
