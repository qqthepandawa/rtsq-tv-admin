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
insert into public.ticker (id, text, sort_order, active)
select
  '00000000-0000-4000-8000-000000000001'::uuid,
  'Selamat datang di Rumah Tahfizh Smart Qur''an  •  Dengan Al-Qur''an hidupmu pasti baik',
  0,
  true
where not exists (select 1 from public.ticker);

-- ---------------------------------------------------------------------------
-- Setelah migrasi:
--
-- 1) Aktifkan Anonymous Sign-ins di Authentication > Providers.
-- 2) Daftarkan email Bapak di web admin, lalu jalankan sekali:
--
--    insert into public.profiles (id, email, name, role)
--    select id, email, 'Admin RTSQ', 'super'
--      from auth.users
--     where email = 'email-bapak@contoh.id'
--    on conflict (id) do nothing;
--
-- 3) Opsional, retensi log otomatis (butuh ekstensi pg_cron):
--
--    select cron.schedule(
--      'rtsq-purge-old-logs',
--      '15 3 * * *',
--      $$select public.purge_old_logs()$$
--    );
-- ---------------------------------------------------------------------------
