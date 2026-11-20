-- Payment state is written only by the trusted backend and database RPCs.
-- Keep only the employer-owned read access required by the app.
revoke all on public.employer_orders, public.employer_entitlements,
  public.employer_subscriptions, public.employer_candidate_unlocks
  from public, anon, authenticated;

grant select on public.employer_orders, public.employer_subscriptions
  to authenticated;
