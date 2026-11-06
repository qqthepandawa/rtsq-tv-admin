-- 0001_extensions.sql
-- Ekstensi dasar RTSQ TV.
-- Catatan: di Supabase, ekstensi dipasang di skema `extensions`.
-- Tipe citext karena itu dipakai sebagai `extensions.citext`.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;
