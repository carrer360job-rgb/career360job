-- The client needs these column grants to create its own account row after
-- email verification or OAuth. RLS still limits inserts to auth.uid(),
-- ACTIVE status, and the three public registration roles. Status is never
-- client-writable; existing role changes remain blocked by the trigger.
grant insert (id, email, phone, role, fcm_token, device_type, last_active_at, updated_at)
  on public.profiles to authenticated;
grant update (id, email, phone, role, fcm_token, device_type, last_active_at, updated_at)
  on public.profiles to authenticated;
