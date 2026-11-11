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
