-- RTSQ TV - gabungan migrasi 0001 sampai 0012
-- Tempel seluruh isi berkas ini ke Supabase SQL Editor, lalu Run sekali.
-- Dibuat otomatis dari supabase/migrations; jangan diedit manual.

begin;

-- ===========================================================================
-- 0001_extensions.sql
-- ===========================================================================

-- 0001_extensions.sql
-- Ekstensi dasar RTSQ TV.
-- Catatan: di Supabase, ekstensi dipasang di skema `extensions`.
-- Tipe citext karena itu dipakai sebagai `extensions.citext`.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;

-- ===========================================================================
-- 0002_types.sql
-- ===========================================================================

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

-- ===========================================================================
-- 0003_tables.sql
-- ===========================================================================

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
  slide_duration_seconds  integer not null default 10,
  ticker_speed            integer not null default 72,
  theme                   jsonb not null default '{}'::jsonb,
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

-- ===========================================================================
-- 0004_functions.sql
-- ===========================================================================

-- 0004_functions.sql
-- Helper RLS + RPC. Semua `security definer` memakai search_path tetap dan
-- memeriksa auth.uid() di dalam badan fungsi.

-- ---------------------------------------------------------------------------
-- Helper
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.active
  );
$$;

create or replace function public.is_super()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.active
      and p.role = 'super'
  );
$$;

create or replace function public.is_paired_device()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.devices d
    where d.auth_uid = auth.uid()
      and d.status = 'paired'
  );
$$;

create or replace function public.my_device_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select d.id from public.devices d where d.auth_uid = auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- register_device: dipanggil TV (sesi anonim) untuk membuat kode pairing.
-- ---------------------------------------------------------------------------
create or replace function public.register_device(
  p_name text default null,
  p_model text default null,
  p_android_version text default null,
  p_app_version text default null
)
returns table (
  device_id uuid,
  status public.device_status,
  pairing_code text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_status public.device_status;
  v_code text;
  v_exp timestamptz := now() + interval '10 minutes';
  v_attempt integer := 0;
begin
  if v_uid is null then
    raise exception 'Sesi tidak valid. Masuk ulang di TV.'
      using errcode = '28000';
  end if;

  select d.id, d.status
    into v_id, v_status
    from public.devices d
   where d.auth_uid = v_uid;

  if v_id is not null and v_status = 'paired' then
    update public.devices d
       set last_seen_at = now(),
           model = coalesce(p_model, d.model),
           android_version = coalesce(p_android_version, d.android_version),
           app_version = coalesce(p_app_version, d.app_version)
     where d.id = v_id;

    return query
      select d.id, d.status, d.pairing_code, d.pairing_expires_at
        from public.devices d
       where d.id = v_id;
    return;
  end if;

  if v_id is not null and v_status = 'revoked' then
    raise exception 'Perangkat ini sudah dicabut aksesnya oleh admin.'
      using errcode = '42501';
  end if;

  -- Buat kode 6 digit yang belum dipakai perangkat pending lain.
  loop
    v_code := lpad((floor(random() * 1000000))::integer::text, 6, '0');
    exit when not exists (
      select 1
        from public.devices d
       where d.pairing_code = v_code
         and d.status = 'pending'
    );
    v_attempt := v_attempt + 1;
    if v_attempt > 50 then
      raise exception 'Gagal membuat kode pairing. Coba lagi.';
    end if;
  end loop;

  if v_id is null then
    insert into public.devices (
      auth_uid, name, status, pairing_code, pairing_expires_at,
      model, android_version, app_version, last_seen_at
    )
    values (
      v_uid,
      coalesce(nullif(p_name, ''), 'TV RTSQ'),
      'pending',
      v_code,
      v_exp,
      p_model,
      p_android_version,
      p_app_version,
      now()
    )
    returning id into v_id;
  else
    update public.devices d
       set name = coalesce(nullif(p_name, ''), d.name),
           status = 'pending',
           pairing_code = v_code,
           pairing_expires_at = v_exp,
           pairing_attempts = 0,
           model = coalesce(p_model, d.model),
           android_version = coalesce(p_android_version, d.android_version),
           app_version = coalesce(p_app_version, d.app_version),
           last_seen_at = now()
     where d.id = v_id;
  end if;

  return query
    select d.id, d.status, d.pairing_code, d.pairing_expires_at
      from public.devices d
     where d.id = v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- pair_device: admin memasukkan kode yang tampil di TV.
-- ---------------------------------------------------------------------------
create or replace function public.pair_device(
  p_code text,
  p_name text default null
)
returns table (
  device_id uuid,
  device_name text,
  paired_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device public.devices%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat memasangkan perangkat.'
      using errcode = '42501';
  end if;

  select *
    into v_device
    from public.devices d
   where d.pairing_code = trim(p_code)
     and d.status = 'pending'
   for update;

  if not found then
    raise exception 'Kode pairing tidak dikenal atau sudah dipakai.';
  end if;

  if v_device.pairing_expires_at is null
     or v_device.pairing_expires_at < now() then
    raise exception 'Kode pairing sudah kedaluwarsa. Minta TV menampilkan kode baru.';
  end if;

  if v_device.pairing_attempts >= 10 then
    raise exception 'Terlalu banyak percobaan. Minta TV menampilkan kode baru.';
  end if;

  update public.devices d
     set status = 'paired',
         name = coalesce(nullif(p_name, ''), d.name),
         pairing_code = null,
         pairing_expires_at = null,
         paired_at = now(),
         paired_by = auth.uid(),
         last_seen_at = now()
   where d.id = v_device.id;

  insert into public.audit_log (actor, action, entity, entity_id, diff)
  values (
    auth.uid(),
    'pair',
    'devices',
    v_device.id::text,
    jsonb_build_object('name', coalesce(nullif(p_name, ''), v_device.name))
  );

  return query
    select d.id, d.name, d.paired_at
      from public.devices d
     where d.id = v_device.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- device_heartbeat: TV melapor status dan mengambil versi konten terbaru.
-- ---------------------------------------------------------------------------
create or replace function public.device_heartbeat(
  p_app_version text default null,
  p_storage_used bigint default null,
  p_storage_free bigint default null,
  p_network text default null,
  p_screen_state text default null,
  p_current_content_id uuid default null
)
returns table (
  settings_version integer,
  contents_updated_at timestamptz,
  ticker_updated_at timestamptz,
  server_time timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device public.devices%rowtype;
begin
  select *
    into v_device
    from public.devices d
   where d.auth_uid = auth.uid();

  if not found then
    raise exception 'Perangkat belum terdaftar.' using errcode = '42501';
  end if;

  if v_device.status = 'revoked' then
    raise exception 'Perangkat sudah dicabut aksesnya.' using errcode = '42501';
  end if;

  update public.devices d
     set last_seen_at = now(),
         last_sync_at = case when v_device.status = 'paired' then now() else d.last_sync_at end,
         app_version = coalesce(p_app_version, d.app_version),
         storage_used_bytes = coalesce(p_storage_used, d.storage_used_bytes),
         storage_free_bytes = coalesce(p_storage_free, d.storage_free_bytes),
         network = coalesce(p_network, d.network),
         screen_state = coalesce(p_screen_state, d.screen_state),
         current_content_id = coalesce(p_current_content_id, d.current_content_id)
   where d.id = v_device.id;

  return query
    select
      coalesce((select s.version from public.settings s where s.id = 1), 0),
      (select max(c.updated_at) from public.contents c
        where c.status = 'published' and c.active),
      (select max(t.updated_at) from public.ticker t where t.active),
      now();
end;
$$;

-- ---------------------------------------------------------------------------
-- claim_commands: ambil perintah pending milik perangkat ini secara atomik.
-- ---------------------------------------------------------------------------
create or replace function public.claim_commands(p_limit integer default 10)
returns setof public.commands
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device uuid := public.my_device_id();
begin
  if v_device is null then
    raise exception 'Perangkat belum terdaftar.' using errcode = '42501';
  end if;

  return query
    with claimed as (
      select c.id
        from public.commands c
       where c.device_id = v_device
         and c.status = 'pending'
       order by c.created_at
       limit greatest(1, least(p_limit, 50))
       for update skip locked
    )
    update public.commands c
       set status = 'running',
           claimed_at = now()
      from claimed
     where c.id = claimed.id
    returning c.*;
end;
$$;

-- ---------------------------------------------------------------------------
-- complete_command: TV menutup perintah.
-- ---------------------------------------------------------------------------
create or replace function public.complete_command(
  p_id uuid,
  p_status public.command_status,
  p_result jsonb default null
)
returns public.commands
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device uuid := public.my_device_id();
  v_row public.commands%rowtype;
begin
  if v_device is null then
    raise exception 'Perangkat belum terdaftar.' using errcode = '42501';
  end if;

  if p_status not in ('done', 'failed') then
    raise exception 'Status akhir harus done atau failed.';
  end if;

  update public.commands c
     set status = p_status,
         executed_at = now(),
         result = p_result
   where c.id = p_id
     and c.device_id = v_device
     and c.status in ('pending', 'running')
  returning * into v_row;

  if not found then
    raise exception 'Perintah tidak ditemukan atau sudah selesai.';
  end if;

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- accept_invite: admin baru mendaftar lalu profilnya dibuat dari undangan.
-- ---------------------------------------------------------------------------
create or replace function public.accept_invite(p_name text default null)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_invite public.admin_invites%rowtype;
  v_profile public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'Sesi tidak valid.' using errcode = '28000';
  end if;

  select lower(u.email::text)
    into v_email
    from auth.users u
   where u.id = v_uid;

  if v_email is null then
    raise exception 'Akun ini tidak memiliki email.';
  end if;

  select *
    into v_invite
    from public.admin_invites i
   where i.email = v_email::extensions.citext
   for update;

  if not found then
    raise exception 'Email % belum diundang admin.' , v_email
      using errcode = '42501';
  end if;

  if v_invite.expires_at < now() then
    delete from public.admin_invites i where i.email = v_invite.email;
    raise exception 'Undangan sudah kedaluwarsa. Minta admin mengirim ulang.';
  end if;

  insert into public.profiles (id, email, name, role, created_by)
  values (
    v_uid,
    v_email::extensions.citext,
    coalesce(nullif(p_name, ''), split_part(v_email, '@', 1)),
    v_invite.role,
    v_invite.invited_by
  )
  on conflict (id) do nothing;

  select * into v_profile from public.profiles p where p.id = v_uid;

  delete from public.admin_invites i where i.email = v_invite.email;

  return v_profile;
end;
$$;

-- ---------------------------------------------------------------------------
-- set_admin_active: super admin menonaktifkan/mengaktifkan admin lain.
-- ---------------------------------------------------------------------------
create or replace function public.set_admin_active(
  p_uid uuid,
  p_active boolean
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target public.profiles%rowtype;
  v_other_supers integer;
begin
  if not public.is_super() then
    raise exception 'Hanya super admin yang dapat mengubah status admin.'
      using errcode = '42501';
  end if;

  if p_uid = auth.uid() and not p_active then
    raise exception 'Super admin tidak dapat menonaktifkan dirinya sendiri.';
  end if;

  select * into v_target from public.profiles p where p.id = p_uid;
  if not found then
    raise exception 'Admin tidak ditemukan.';
  end if;

  if not p_active and v_target.role = 'super' and v_target.active then
    select count(*)
      into v_other_supers
      from public.profiles p
     where p.role = 'super'
       and p.active
       and p.id <> p_uid;

    if v_other_supers = 0 then
      raise exception 'Harus ada minimal satu super admin yang aktif.';
    end if;
  end if;

  update public.profiles p
     set active = p_active
   where p.id = p_uid
  returning * into v_target;

  return v_target;
end;
$$;

-- ---------------------------------------------------------------------------
-- purge_old_logs: dijalankan pg_cron harian (retensi 30 hari).
-- ---------------------------------------------------------------------------
create or replace function public.purge_old_logs()
returns table (logs_deleted bigint, invites_deleted bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_logs bigint;
  v_invites bigint;
begin
  delete from public.logs l
   where l.created_at < now() - interval '30 days';
  get diagnostics v_logs = row_count;

  delete from public.admin_invites i
   where i.expires_at < now() - interval '7 days';
  get diagnostics v_invites = row_count;

  return query select v_logs, v_invites;
end;
$$;

-- ---------------------------------------------------------------------------
-- Hak eksekusi: hanya pengguna login (termasuk sesi anonim TV).
-- ---------------------------------------------------------------------------
revoke all on function public.is_admin() from public, anon;
revoke all on function public.is_super() from public, anon;
revoke all on function public.is_paired_device() from public, anon;
revoke all on function public.my_device_id() from public, anon;
revoke all on function public.register_device(text, text, text, text) from public, anon;
revoke all on function public.pair_device(text, text) from public, anon;
revoke all on function public.device_heartbeat(text, bigint, bigint, text, text, uuid) from public, anon;
revoke all on function public.claim_commands(integer) from public, anon;
revoke all on function public.complete_command(uuid, public.command_status, jsonb) from public, anon;
revoke all on function public.accept_invite(text) from public, anon;
revoke all on function public.set_admin_active(uuid, boolean) from public, anon;
revoke all on function public.purge_old_logs() from public, anon, authenticated;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_super() to authenticated;
grant execute on function public.is_paired_device() to authenticated;
grant execute on function public.my_device_id() to authenticated;
grant execute on function public.register_device(text, text, text, text) to authenticated;
grant execute on function public.pair_device(text, text) to authenticated;
grant execute on function public.device_heartbeat(text, bigint, bigint, text, text, uuid) to authenticated;
grant execute on function public.claim_commands(integer) to authenticated;
grant execute on function public.complete_command(uuid, public.command_status, jsonb) to authenticated;
grant execute on function public.accept_invite(text) to authenticated;
grant execute on function public.set_admin_active(uuid, boolean) to authenticated;

-- ===========================================================================
-- 0005_rls.sql
-- ===========================================================================

-- 0005_rls.sql
-- Aktifkan RLS dan pasang policy per tabel (Blueprint 7.11).

alter table public.profiles      enable row level security;
alter table public.admin_invites enable row level security;
alter table public.contents      enable row level security;
alter table public.ticker        enable row level security;
alter table public.settings      enable row level security;
alter table public.devices       enable row level security;
alter table public.commands      enable row level security;
alter table public.logs          enable row level security;
alter table public.audit_log     enable row level security;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (public.is_admin());

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update to authenticated
  using (public.is_super())
  with check (public.is_super());

drop policy if exists profiles_delete on public.profiles;
create policy profiles_delete on public.profiles
  for delete to authenticated
  using (public.is_super());

-- INSERT sengaja tidak ada: hanya lewat RPC accept_invite() / bootstrap SQL.

-- ---------------------------------------------------------------------------
-- admin_invites
-- ---------------------------------------------------------------------------
drop policy if exists invites_select on public.admin_invites;
create policy invites_select on public.admin_invites
  for select to authenticated
  using (public.is_super());

drop policy if exists invites_insert on public.admin_invites;
create policy invites_insert on public.admin_invites
  for insert to authenticated
  with check (public.is_super());

drop policy if exists invites_delete on public.admin_invites;
create policy invites_delete on public.admin_invites
  for delete to authenticated
  using (public.is_super());

-- ---------------------------------------------------------------------------
-- settings
-- ---------------------------------------------------------------------------
drop policy if exists settings_select on public.settings;
create policy settings_select on public.settings
  for select to authenticated
  using (public.is_admin() or public.is_paired_device());

drop policy if exists settings_update on public.settings;
create policy settings_update on public.settings
  for update to authenticated
  using (public.is_super())
  with check (public.is_super());

-- ---------------------------------------------------------------------------
-- contents
-- ---------------------------------------------------------------------------
drop policy if exists contents_select on public.contents;
create policy contents_select on public.contents
  for select to authenticated
  using (
    public.is_admin()
    or (public.is_paired_device() and status = 'published' and active)
  );

drop policy if exists contents_insert on public.contents;
create policy contents_insert on public.contents
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists contents_update on public.contents;
create policy contents_update on public.contents
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists contents_delete on public.contents;
create policy contents_delete on public.contents
  for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- ticker
-- ---------------------------------------------------------------------------
drop policy if exists ticker_select on public.ticker;
create policy ticker_select on public.ticker
  for select to authenticated
  using (
    public.is_admin()
    or (public.is_paired_device() and active)
  );

drop policy if exists ticker_insert on public.ticker;
create policy ticker_insert on public.ticker
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists ticker_update on public.ticker;
create policy ticker_update on public.ticker
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists ticker_delete on public.ticker;
create policy ticker_delete on public.ticker
  for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- devices
-- ---------------------------------------------------------------------------
drop policy if exists devices_select on public.devices;
create policy devices_select on public.devices
  for select to authenticated
  using (public.is_admin() or auth_uid = auth.uid());

drop policy if exists devices_insert on public.devices;
create policy devices_insert on public.devices
  for insert to authenticated
  with check (
    auth_uid = auth.uid()
    and status = 'pending'
    and pairing_code is not null
  );

drop policy if exists devices_update on public.devices;
create policy devices_update on public.devices
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists devices_delete on public.devices;
create policy devices_delete on public.devices
  for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- commands
-- ---------------------------------------------------------------------------
drop policy if exists commands_select on public.commands;
create policy commands_select on public.commands
  for select to authenticated
  using (public.is_admin() or device_id = public.my_device_id());

drop policy if exists commands_insert on public.commands;
create policy commands_insert on public.commands
  for insert to authenticated
  with check (public.is_admin());

-- UPDATE hanya lewat RPC claim_commands()/complete_command().
drop policy if exists commands_delete on public.commands;
create policy commands_delete on public.commands
  for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- logs
-- ---------------------------------------------------------------------------
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

-- ===========================================================================
-- 0006_storage.sql
-- ===========================================================================

-- 0006_storage.sql
-- Bucket privat `tv-media` + policy Storage (Blueprint 7.12 / 18.6).
--
-- Batas bucket 60 MB (video). Gambar dibatasi 4 MB di panel admin.
-- Hanya tipe yang diizinkan.

insert into storage.buckets (id, name, "public", file_size_limit, allowed_mime_types)
values (
  'tv-media',
  'tv-media',
  false,
  62914560,
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

-- ===========================================================================
-- 0007_realtime.sql
-- ===========================================================================

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

-- ===========================================================================
-- 0008_seed.sql
-- ===========================================================================

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

-- ===========================================================================
-- 0009_remove_sholat_mode.sql
-- ===========================================================================

-- 0009_remove_sholat_mode.sql
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

-- ===========================================================================
-- 0010_consistency_fixes.sql
-- ===========================================================================

-- 0010_consistency_fixes.sql
-- Perbaikan konsistensi v2.2:
--   1. `screen_state` tidak lagi mengenal mode sholat.
--   2. Kecepatan ticker default 60 px/detik (Blueprint §6.5).
--   3. Kolom persetujuan orang tua/wali untuk konten santri.
--   4. Super admin terakhir tidak bisa dihapus/dinonaktifkan lewat RLS.
--   5. Batas 50 log per jam per perangkat (Blueprint §6.12).
--   6. Batas percobaan pairing 5 kali (Blueprint §6.10) dan pencatatan
--      percobaan pada kode kedaluwarsa.
--   7. Heartbeat mengirim jumlah konten/ticker agar penghapusan terdeteksi.
--   8. Pembersihan perangkat pending yang tidak pernah dipasangkan.
--   9. Policy Storage dibatasi ke prefix `contents/`.
--
-- Idempoten: aman dijalankan ulang.

begin;

-- ---------------------------------------------------------------------------
-- 1. screen_state: buang nilai mode sholat
-- ---------------------------------------------------------------------------
update public.devices
   set screen_state = 'content'
 where screen_state = 'prayer';

alter table public.devices
  drop constraint if exists devices_screen_state_check;
alter table public.devices
  add constraint devices_screen_state_check
  check (screen_state in ('content', 'emergency', 'idle'));

-- ---------------------------------------------------------------------------
-- 2. Kecepatan ticker default sesuai Blueprint
-- ---------------------------------------------------------------------------
alter table public.settings
  alter column ticker_speed set default 60;

update public.settings
   set ticker_speed = 60
 where ticker_speed = 72;

-- ---------------------------------------------------------------------------
-- 3. Persetujuan orang tua/wali untuk konten yang memuat nama santri
-- ---------------------------------------------------------------------------
alter table public.contents
  add column if not exists consent_confirmed boolean not null default false;

create or replace function public.require_student_consent()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'published'
     and coalesce(btrim(new.student_name), '') <> ''
     and new.consent_confirmed is not true then
    raise exception 'Centang persetujuan orang tua/wali sebelum menayangkan konten santri.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists contents_consent_guard on public.contents;
create trigger contents_consent_guard
  before insert or update on public.contents
  for each row execute function public.require_student_consent();

-- ---------------------------------------------------------------------------
-- 4. Super admin terakhir tidak boleh hilang
-- ---------------------------------------------------------------------------
create or replace function public.guard_last_super()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_remaining integer;
begin
  if old.role = 'super' and old.active then
    if tg_op = 'DELETE' then
      null;
    elsif new.role = 'super' and new.active then
      return new;
    end if;

    select count(*)
      into v_remaining
      from public.profiles p
     where p.role = 'super'
       and p.active
       and p.id <> old.id;

    if v_remaining = 0 then
      raise exception 'Harus ada minimal satu super admin yang aktif.'
        using errcode = '23514';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_guard_last_super on public.profiles;
create trigger profiles_guard_last_super
  before update or delete on public.profiles
  for each row execute function public.guard_last_super();

-- ---------------------------------------------------------------------------
-- 5. Batas 50 log per jam per perangkat
-- ---------------------------------------------------------------------------
create or replace function public.enforce_log_rate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  select count(*)
    into v_count
    from public.logs l
   where l.device_id = new.device_id
     and l.created_at > now() - interval '1 hour';

  if v_count >= 50 then
    raise exception 'Batas 50 log per jam per perangkat terlampaui.'
      using errcode = '53400';
  end if;
  return new;
end;
$$;

drop trigger if exists logs_rate_guard on public.logs;
create trigger logs_rate_guard
  before insert on public.logs
  for each row execute function public.enforce_log_rate();

-- ---------------------------------------------------------------------------
-- 6. pair_device: batas 5 percobaan + catat percobaan kedaluwarsa
-- ---------------------------------------------------------------------------
create or replace function public.pair_device(
  p_code text,
  p_name text default null
)
returns table (
  device_id uuid,
  device_name text,
  paired_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device public.devices%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat memasangkan perangkat.'
      using errcode = '42501';
  end if;

  select *
    into v_device
    from public.devices d
   where d.pairing_code = trim(p_code)
     and d.status = 'pending'
   for update;

  if not found then
    raise exception 'Kode pairing tidak dikenal atau sudah dipakai.';
  end if;

  if v_device.pairing_attempts >= 5 then
    update public.devices d
       set pairing_code = null,
           pairing_expires_at = null
     where d.id = v_device.id;
    raise exception 'Terlalu banyak percobaan. Minta TV menampilkan kode baru.'
      using errcode = '42901';
  end if;

  if v_device.pairing_expires_at is null
     or v_device.pairing_expires_at < now() then
    update public.devices d
       set pairing_attempts = d.pairing_attempts + 1
     where d.id = v_device.id;
    raise exception 'Kode pairing sudah kedaluwarsa. Minta TV menampilkan kode baru.';
  end if;

  update public.devices d
     set status = 'paired',
         name = coalesce(nullif(p_name, ''), d.name),
         pairing_code = null,
         pairing_expires_at = null,
         pairing_attempts = 0,
         paired_at = now(),
         paired_by = auth.uid(),
         last_seen_at = now()
   where d.id = v_device.id;

  insert into public.audit_log (actor, action, entity, entity_id, diff)
  values (
    auth.uid(),
    'pair',
    'devices',
    v_device.id::text,
    jsonb_build_object('name', coalesce(nullif(p_name, ''), v_device.name))
  );

  return query
    select d.id, d.name, d.paired_at
      from public.devices d
     where d.id = v_device.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. device_heartbeat: sertakan jumlah konten & ticker
-- ---------------------------------------------------------------------------
drop function if exists public.device_heartbeat(
  text, bigint, bigint, text, text, uuid
);

create function public.device_heartbeat(
  p_app_version text default null,
  p_storage_used bigint default null,
  p_storage_free bigint default null,
  p_network text default null,
  p_screen_state text default null,
  p_current_content_id uuid default null
)
returns table (
  settings_version integer,
  contents_updated_at timestamptz,
  contents_count bigint,
  ticker_updated_at timestamptz,
  ticker_count bigint,
  server_time timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device public.devices%rowtype;
begin
  select *
    into v_device
    from public.devices d
   where d.auth_uid = auth.uid();

  if not found then
    raise exception 'Perangkat belum terdaftar.' using errcode = '42501';
  end if;

  if v_device.status = 'revoked' then
    raise exception 'Perangkat sudah dicabut aksesnya.' using errcode = '42501';
  end if;

  update public.devices d
     set last_seen_at = now(),
         last_sync_at = case when v_device.status = 'paired' then now() else d.last_sync_at end,
         app_version = coalesce(p_app_version, d.app_version),
         storage_used_bytes = coalesce(p_storage_used, d.storage_used_bytes),
         storage_free_bytes = coalesce(p_storage_free, d.storage_free_bytes),
         network = coalesce(p_network, d.network),
         screen_state = coalesce(p_screen_state, d.screen_state),
         current_content_id = coalesce(p_current_content_id, d.current_content_id)
   where d.id = v_device.id;

  return query
    select
      coalesce((select s.version from public.settings s where s.id = 1), 0),
      (select max(c.updated_at) from public.contents c
        where c.status = 'published' and c.active),
      (select count(*) from public.contents c
        where c.status = 'published' and c.active),
      (select max(t.updated_at) from public.ticker t where t.active),
      (select count(*) from public.ticker t where t.active),
      now();
end;
$$;

revoke all on function public.device_heartbeat(
  text, bigint, bigint, text, text, uuid
) from public, anon;
grant execute on function public.device_heartbeat(
  text, bigint, bigint, text, text, uuid
) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. purge_old_logs: bersihkan perangkat pending yang tidak pernah dipakai
-- ---------------------------------------------------------------------------
drop function if exists public.purge_old_logs();

create function public.purge_old_logs()
returns table (
  logs_deleted bigint,
  invites_deleted bigint,
  devices_deleted bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_logs bigint;
  v_invites bigint;
  v_devices bigint;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Hanya admin yang dapat membersihkan log.'
      using errcode = '42501';
  end if;

  delete from public.logs l
   where l.created_at < now() - interval '30 days';
  get diagnostics v_logs = row_count;

  delete from public.admin_invites i
   where i.expires_at < now() - interval '7 days';
  get diagnostics v_invites = row_count;

  delete from public.devices d
   where d.status = 'pending'
     and coalesce(d.last_seen_at, d.created_at) < now() - interval '7 days';
  get diagnostics v_devices = row_count;

  return query select v_logs, v_invites, v_devices;
end;
$$;

revoke all on function public.purge_old_logs() from public, anon;
grant execute on function public.purge_old_logs() to authenticated;

-- ---------------------------------------------------------------------------
-- 9. Storage: admin hanya menulis di prefix `contents/`
-- ---------------------------------------------------------------------------
drop policy if exists tv_media_insert on storage.objects;
create policy tv_media_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'tv-media'
    and public.is_admin()
    and name like 'contents/%'
  );

drop policy if exists tv_media_update on storage.objects;
create policy tv_media_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'tv-media'
    and public.is_admin()
    and name like 'contents/%'
  )
  with check (
    bucket_id = 'tv-media'
    and public.is_admin()
    and name like 'contents/%'
  );

drop policy if exists tv_media_delete on storage.objects;
create policy tv_media_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'tv-media'
    and public.is_admin()
    and name like 'contents/%'
  );

commit;

-- ===========================================================================
-- 0011_screenshot_policy.sql
-- ===========================================================================

-- 0011_screenshot_policy.sql
-- Perangkat TV boleh mengunggah tangkapan layar ke prefix
-- `screenshots/{device_id}/` pada bucket privat `tv-media`.
--
-- Sebelumnya hanya admin yang boleh insert, sehingga perintah `screenshot`
-- tidak pernah bisa menyimpan hasil tangkapan layar.

drop policy if exists tv_media_screenshot_insert on storage.objects;
create policy tv_media_screenshot_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'tv-media'
    and public.is_paired_device()
    and (storage.foldername(name))[1] = 'screenshots'
    and (storage.foldername(name))[2] = (
      select d.id::text
        from public.devices d
       where d.auth_uid = auth.uid()
         and d.status = 'paired'
       limit 1
    )
  );

drop policy if exists tv_media_screenshot_update on storage.objects;
create policy tv_media_screenshot_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'tv-media'
    and public.is_paired_device()
    and (storage.foldername(name))[1] = 'screenshots'
    and (storage.foldername(name))[2] = (
      select d.id::text
        from public.devices d
       where d.auth_uid = auth.uid()
         and d.status = 'paired'
       limit 1
    )
  )
  with check (
    bucket_id = 'tv-media'
    and public.is_paired_device()
    and (storage.foldername(name))[1] = 'screenshots'
    and (storage.foldername(name))[2] = (
      select d.id::text
        from public.devices d
       where d.auth_uid = auth.uid()
         and d.status = 'paired'
       limit 1
    )
  );

-- ===========================================================================
-- 0012_show_caption.sql
-- ===========================================================================

-- 0012_show_caption.sql
-- Pilihan per konten: tampilkan judul & keterangan bersama media di TV.
--
-- Default true agar perilaku konten lama tidak berubah. Panel admin
-- mengirim false untuk foto/video baru sampai admin secara sadar
-- mengaktifkan teks, sehingga judul/deskripsi tidak muncul tanpa izin.
-- Nilai ini hanya dipakai untuk konten bertipe foto/video; tipe lain
-- selalu menampilkan teksnya.

alter table public.contents
  add column if not exists show_caption boolean not null default true;

comment on column public.contents.show_caption is
  'Tampilkan judul/keterangan di samping media pada TV (foto/video).';

commit;
