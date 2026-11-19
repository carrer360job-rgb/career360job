create or replace function public.prevent_employer_self_approval()
returns trigger language plpgsql security invoker set search_path = public, pg_temp
as $$
begin
  if (select auth.role()) = 'authenticated' and (
    new.is_verified is distinct from old.is_verified or
    new.posting_credits is distinct from old.posting_credits or
    new.credits_expire_at is distinct from old.credits_expire_at or
    new.active_plan is distinct from old.active_plan or
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

drop trigger if exists employers_privileged_fields_immutable on public.employers;
create trigger employers_privileged_fields_immutable before update on public.employers
for each row execute function public.prevent_employer_self_approval();
