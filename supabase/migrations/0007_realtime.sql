-- 0007_realtime.sql
-- Publikasi realtime untuk contents, ticker, settings, commands (Blueprint 7.13).

do $$
declare
  v_table text;
begin
  if not exists (
    select 1 from pg_publication p where p.pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;

  foreach v_table in array array['contents', 'ticker', 'settings', 'commands']
  loop
    if not exists (
      select 1
        from pg_publication_tables t
       where t.pubname = 'supabase_realtime'
         and t.schemaname = 'public'
         and t.tablename = v_table
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        v_table
      );
    end if;
  end loop;
end;
$$;

-- Agar DELETE mengirim baris lama lengkap (dipakai panel admin).
alter table public.contents replica identity full;
alter table public.ticker replica identity full;
alter table public.settings replica identity full;
