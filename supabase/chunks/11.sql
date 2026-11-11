-- 0009_remove_sholat_mode.sql (sama dengan supabase/migrations/0009_remove_sholat_mode.sql)
-- v2.2 (6 November 2026): TV lobi, bukan layar masjid.
-- Kolom dihapus: ihtiyati, iqamah_minutes, khutbah_minutes,
-- prayer_duration_minutes, prayer_mode_enabled.
-- Jalankan sekali di SQL Editor untuk project yang sudah pernah
-- menerapkan 0001-0008.

begin;

alter table public.settings
  drop column if exists ihtiyati,
  drop column if exists iqamah_minutes,
  drop column if exists khutbah_minutes,
  drop column if exists prayer_duration_minutes,
  drop column if exists prayer_mode_enabled;

commit;
