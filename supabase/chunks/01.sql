-- RTSQ TV — migrasi bagian 01 dari 10
-- Sumber: 0001_extensions.sql … 0003_tables.sql
-- Jalankan di SQL Editor Supabase, satu bagian per Run, urut dari 01.

-- 0001_extensions.sql
-- Ekstensi dasar RTSQ TV.
-- Catatan: di Supabase, ekstensi dipasang di skema `extensions`.
-- Tipe citext karena itu dipakai sebagai `extensions.citext`.

create extension if not exists pgcrypto with schema extensions;

create extension if not exists citext with schema extensions;

-- 0002_types.sql
-- Semua tipe enum. Dibungkus DO agar migrasi aman dijalankan ulang.

do $$ begin
  create type public.admin_role as enum ('super', 'editor');
exception when duplicate_object then null; end; $$;

do $$ begin
  create type public.device_status as enum ('pending', 'paired', 'revoked');
exception when duplicate_object then null; end; $$;

do $$ begin
  create type public.content_type as enum (
    'announcement', 'achievement', 'photo', 'video', 'schedule'
  );
exception when duplicate_object then null; end; $$;

do $$ begin
  create type public.content_status as enum ('draft', 'published', 'archived');
exception when duplicate_object then null; end; $$;

do $$ begin
  create type public.command_status as enum ('pending', 'running', 'done', 'failed');
exception when duplicate_object then null; end; $$;

do $$ begin
  create type public.log_level as enum ('info', 'warn', 'error');
exception when duplicate_object then null; end; $$;

-- 0003_tables.sql
-- Tabel, indeks, dan trigger dasar RTSQ TV.

-- ---------------------------------------------------------------------------
-- profiles: admin panel, 1:1 dengan auth.users
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       extensions.citext not null unique,
  name        text not null,
  role        public.admin_role not null default 'editor',
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  created_by  uuid references public.profiles (id) on delete set null
);

-- ---------------------------------------------------------------------------
-- admin_invites: undangan email, dihapus setelah dipakai
-- ---------------------------------------------------------------------------

create table if not exists public.admin_invites (
  email       extensions.citext primary key,
  role        public.admin_role not null default 'editor',
  invited_by  uuid references public.profiles (id) on delete set null,
  expires_at  timestamptz not null default (now() + interval '7 days'),
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- contents: pengumuman, prestasi, foto, video, jadwal
-- ---------------------------------------------------------------------------

create table if not exists public.contents (
  id              uuid primary key default gen_random_uuid(),
  type            public.content_type not null,
  title           text not null,
  body            text,
  media           jsonb not null default '[]'::jsonb,
  student_name    text,
  marhalah        text,
  achievement     text,
  achieved_at     date,
  schedule_items  jsonb not null default '[]'::jsonb,
  start_at        timestamptz,
  end_at          timestamptz,
  sort_order      integer not null default 0,
  duration_seconds integer,
  priority        integer not null default 0,
  pinned          boolean not null default false,
  active          boolean not null default true,
  status          public.content_status not null default 'draft',
  created_by      uuid references public.profiles (id) on delete set null
                    default auth.uid(),
  updated_by      uuid references public.profiles (id) on delete set null,
  approved_by     uuid references public.profiles (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  approved_at     timestamptz,
  version         integer not null default 1,
  constraint contents_window_valid
    check (start_at is null or end_at is null or end_at > start_at)
);

-- ---------------------------------------------------------------------------
-- ticker: teks berjalan, bisa dijadwalkan
-- ---------------------------------------------------------------------------

create table if not exists public.ticker (
  id          uuid primary key default gen_random_uuid(),
  text        text not null,
  start_at    timestamptz,
  end_at      timestamptz,
  sort_order  integer not null default 0,
  active      boolean not null default true,
  created_by  uuid references public.profiles (id) on delete set null
                default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint ticker_window_valid
    check (start_at is null or end_at is null or end_at > start_at)
);

-- ---------------------------------------------------------------------------
-- settings: satu baris, id = 1
-- ---------------------------------------------------------------------------

create table if not exists public.settings (
  id                      smallint primary key default 1 check (id = 1),
  org_name                text not null default 'Rumah Tahfizh Smart Qur''an',
  address                 text,
  city                    text not null default 'Batam',
  latitude                numeric(9, 6) not null default 1.130000,
  longitude               numeric(9, 6) not null default 104.050000,
  timezone                text not null default 'Asia/Jakarta',
  hijri_offset            jsonb not null default '{}'::jsonb,
  ihtiyati                jsonb not null default
    '{"subuh": 2, "dzuhur": 2, "ashar": 2, "maghrib": 2, "isya": 2}'::jsonb,
  iqamah_minutes          jsonb not null default
    '{"subuh": 10, "dzuhur": 10, "ashar": 10, "maghrib": 7, "isya": 10}'::jsonb,
  khutbah_minutes         integer not null default 15,
  prayer_duration_minutes integer not null default 12,
  slide_duration_seconds  integer not null default 10,
  ticker_speed            integer not null default 72,
  theme                   jsonb not null default '{}'::jsonb,
  prayer_mode_enabled     jsonb not null default
    '{"subuh": true, "dzuhur": true, "ashar": true, "maghrib": true, "isya": true}'::jsonb,
  emergency               jsonb,
  version                 integer not null default 1,
  updated_at              timestamptz not null default now(),
  updated_by              uuid references public.profiles (id) on delete set null
);

-- ---------------------------------------------------------------------------
-- devices: TV yang mendaftar lewat sesi anonim
-- ---------------------------------------------------------------------------

-- Selesai bagian 01. Lanjut ke bagian berikutnya.
