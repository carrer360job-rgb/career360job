-- Preserve the terms already advertised by the application for the three paid plans.
-- The preceding schema migration supplied generic defaults to existing rows.
update public.employer_plans
set badge = '15 days', credit_validity_days = 15, profile_unlock_limit = 25, sort_order = 0
where id = 'standard_15' and badge = '' and credit_validity_days = 30;

update public.employer_plans
set badge = '30 days', credit_validity_days = 30, profile_unlock_limit = 100, sort_order = 2
where id = 'featured_30' and badge = '' and profile_unlock_limit = 25;

update public.employer_plans
set badge = 'Statewide', credit_validity_days = 30, profile_unlock_limit = 300, sort_order = 3
where id = 'elite_all_tn' and badge = '' and profile_unlock_limit = 25;
