-- RTSQ TV — migrasi bagian 09 dari 10
-- Sumber: 0005_rls.sql … 0008_seed.sql
-- Jalankan di SQL Editor Supabase, satu bagian per Run, urut dari 01.

drop policy if exists logs_select on public.logs;

create policy logs_select on public.logs
  for select to authenticated
  using (public.is_admin() or device_id = public.my_device_id());

drop policy if exists logs_insert on public.logs;

create policy logs_insert on public.logs
  for insert to authenticated
  with check (device_id = public.my_device_id());

drop policy if exists logs_delete on public.logs;

create policy logs_delete on public.logs
  for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- audit_log (hanya baca untuk admin; tulis lewat trigger definer)
-- ---------------------------------------------------------------------------

drop policy if exists audit_select on public.audit_log;

create policy audit_select on public.audit_log
  for select to authenticated
  using (public.is_admin());

-- 0006_storage.sql
-- Bucket privat `tv-media` + policy Storage (Blueprint 7.12 / 18.6).
--
-- Ukuran mengikuti Global file size limit project (lihat 0012): paket Free
-- maksimum 50 MB/berkas, paket Pro dapat dinaikkan. Gambar dibatasi 4 MB di
-- panel admin. Hanya tipe yang diizinkan.

insert into storage.buckets (id, name, "public", file_size_limit, allowed_mime_types)
values (
  'tv-media',
  'tv-media',
  false,
  null,
  array['image/jpeg', 'image/png', 'image/webp', 'video/mp4']
)
on conflict (id) do update
  set "public" = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists tv_media_read on storage.objects;

create policy tv_media_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'tv-media'
    and (public.is_admin() or public.is_paired_device())
  );

drop policy if exists tv_media_insert on storage.objects;

create policy tv_media_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'tv-media' and public.is_admin());

drop policy if exists tv_media_update on storage.objects;

create policy tv_media_update on storage.objects
  for update to authenticated
  using (bucket_id = 'tv-media' and public.is_admin())
  with check (bucket_id = 'tv-media' and public.is_admin());

drop policy if exists tv_media_delete on storage.objects;

create policy tv_media_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'tv-media' and public.is_admin());

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

-- 0008_seed.sql
-- Baris settings awal untuk Batam (Blueprint 7.4 / 18.5).

insert into public.settings (
  id, org_name, address, city, latitude, longitude, timezone
)
values (
  1,
  'Rumah Tahfizh Smart Qur''an',
  'Batam, Kepulauan Riau',
  'Batam',
  1.045600,
  104.030500,
  'Asia/Jakarta'
)
on conflict (id) do nothing;

-- Teks berjalan sambutan. Bisa diedit/dihapus dari panel admin.

-- Selesai bagian 09. Lanjut ke bagian berikutnya.
