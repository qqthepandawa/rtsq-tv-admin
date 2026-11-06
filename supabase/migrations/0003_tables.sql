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
create trigger ticker_touch
  before update on public.ticker
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Trigger: audit otomatis untuk tabel yang dikelola admin
-- ---------------------------------------------------------------------------
create or replace function public.audit_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_entity_id text;
  v_row jsonb;
begin
  if tg_op = 'DELETE' then
    v_row := to_jsonb(old);
    v_entity_id := coalesce(v_row ->> 'id', v_row ->> 'email');
    insert into public.audit_log (actor, action, entity, entity_id, diff)
    values (v_actor, 'delete', tg_table_name, v_entity_id, v_row);
    return old;
  end if;

  v_row := to_jsonb(new);
  v_entity_id := coalesce(v_row ->> 'id', v_row ->> 'email');
  insert into public.audit_log (actor, action, entity, entity_id, diff)
  values (
    v_actor,
    lower(tg_op),
    tg_table_name,
    v_entity_id,
    case
      when tg_op = 'UPDATE' then
        coalesce(
          (
            select jsonb_object_agg(n.key, n.value)
              from jsonb_each(to_jsonb(new)) as n
             where to_jsonb(old) -> n.key is distinct from n.value
          ),
          '{}'::jsonb
        )
      else to_jsonb(new)
    end
  );
  return new;
end;
$$;

drop trigger if exists contents_audit on public.contents;
create trigger contents_audit
  after insert or update or delete on public.contents
  for each row execute function public.audit_row();

drop trigger if exists ticker_audit on public.ticker;
create trigger ticker_audit
  after insert or update or delete on public.ticker
  for each row execute function public.audit_row();

drop trigger if exists settings_audit on public.settings;
create trigger settings_audit
  after update on public.settings
  for each row execute function public.audit_row();

drop trigger if exists profiles_audit on public.profiles;
create trigger profiles_audit
  after insert or update or delete on public.profiles
  for each row execute function public.audit_row();

drop trigger if exists invites_audit on public.admin_invites;
create trigger invites_audit
  after insert or update or delete on public.admin_invites
  for each row execute function public.audit_row();
