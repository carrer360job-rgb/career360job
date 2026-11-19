do $$
begin
  if not exists (select 1 from pg_publication_tables
      where pubname='supabase_realtime' and schemaname='public' and tablename='institutions') then
    alter publication supabase_realtime add table public.institutions;
  end if;
  if not exists (select 1 from pg_publication_tables
      where pubname='supabase_realtime' and schemaname='public' and tablename='saved_jobs') then
    alter publication supabase_realtime add table public.saved_jobs;
  end if;
  if not exists (select 1 from pg_publication_tables
      where pubname='supabase_realtime' and schemaname='public' and tablename='employer_orders') then
    alter publication supabase_realtime add table public.employer_orders;
  end if;
end;
$$;
