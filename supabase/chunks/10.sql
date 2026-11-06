-- RTSQ TV — migrasi bagian 10 dari 10
-- Sumber: 0008_seed.sql
-- Jalankan di SQL Editor Supabase, satu bagian per Run, urut dari 01.

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

-- Selesai bagian 10. Lanjut ke bagian berikutnya.
