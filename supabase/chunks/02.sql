-- RTSQ TV — migrasi bagian 02 dari 10
-- Sumber: 0003_tables.sql
-- Jalankan di SQL Editor Supabase, satu bagian per Run, urut dari 01.

create table if not exists public.devices (
  id                  uuid primary key default gen_random_uuid(),
  auth_uid            uuid not null unique,
  name                text not null default 'TV RTSQ',
  status              public.device_status not null default 'pending',
  pairing_code        text,
  pairing_expires_at  timestamptz,
  pairing_attempts    integer not null default 0,
  model               text,
  android_version     text,
  app_version         text,
  last_seen_at        timestamptz,
  last_sync_at        timestamptz,
  current_content_id  uuid references public.contents (id) on delete set null,
  screen_state        text not null default 'content'
                        check (screen_state in ('content', 'prayer', 'emergency', 'idle')),
  storage_used_bytes  bigint,
  storage_free_bytes  bigint,
  network             text check (network in ('wifi', 'ethernet', 'none')),
  paired_at           timestamptz,
  paired_by           uuid references public.profiles (id) on delete set null,
  created_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- commands: perintah jarak jauh untuk TV
-- ---------------------------------------------------------------------------

create table if not exists public.commands (
  id          uuid primary key default gen_random_uuid(),
  device_id   uuid not null references public.devices (id) on delete cascade,
  type        text not null,
  payload     jsonb not null default '{}'::jsonb,
  status      public.command_status not null default 'pending',
  created_by  uuid references public.profiles (id) on delete set null
                default auth.uid(),
  created_at  timestamptz not null default now(),
  claimed_at  timestamptz,
  executed_at timestamptz,
  result      jsonb
);

-- ---------------------------------------------------------------------------
-- logs: log dari TV, retensi 30 hari
-- ---------------------------------------------------------------------------

create table if not exists public.logs (
  id          bigserial primary key,
  device_id   uuid not null references public.devices (id) on delete cascade,
  level       public.log_level not null default 'info',
  message     text not null,
  context     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- audit_log: jejak perubahan admin, ditulis lewat trigger/fungsi definer
-- ---------------------------------------------------------------------------

create table if not exists public.audit_log (
  id          bigserial primary key,
  actor       uuid,
  action      text not null,
  entity      text not null,
  entity_id   text,
  diff        jsonb,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Indeks (Blueprint 7.14)
-- ---------------------------------------------------------------------------

create index if not exists contents_publish_idx
  on public.contents (status, active, start_at, end_at, sort_order);

create index if not exists contents_updated_idx
  on public.contents (updated_at desc);

create index if not exists ticker_active_idx
  on public.ticker (active, start_at, sort_order);

create index if not exists commands_pending_idx
  on public.commands (device_id, status, created_at);

create index if not exists logs_device_idx
  on public.logs (device_id, created_at desc);

create unique index if not exists devices_pairing_code_idx
  on public.devices (pairing_code)
  where status = 'pending';

create index if not exists devices_last_seen_idx
  on public.devices (last_seen_at desc);

create index if not exists audit_log_created_idx
  on public.audit_log (created_at desc);

-- ---------------------------------------------------------------------------
-- Trigger: updated_at + version untuk contents
-- ---------------------------------------------------------------------------

create or replace function public.touch_contents()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  new.version := old.version + 1;
  return new;
end;
$$;

drop trigger if exists contents_touch on public.contents;

create trigger contents_touch
  before update on public.contents
  for each row execute function public.touch_contents();

-- ---------------------------------------------------------------------------
-- Trigger: updated_at + version untuk settings
-- ---------------------------------------------------------------------------

create or replace function public.touch_settings()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  new.version := old.version + 1;
  return new;
end;
$$;

drop trigger if exists settings_touch on public.settings;

create trigger settings_touch
  before update on public.settings
  for each row execute function public.touch_settings();

-- ---------------------------------------------------------------------------
-- Trigger: updated_at untuk ticker
-- ---------------------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists ticker_touch on public.ticker;

-- Selesai bagian 02. Lanjut ke bagian berikutnya.
