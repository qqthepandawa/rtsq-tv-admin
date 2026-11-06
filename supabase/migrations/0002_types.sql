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
