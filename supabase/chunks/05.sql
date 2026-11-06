-- RTSQ TV — migrasi bagian 05 dari 10
-- Sumber: 0004_functions.sql
-- Jalankan di SQL Editor Supabase, satu bagian per Run, urut dari 01.

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

-- Selesai bagian 05. Lanjut ke bagian berikutnya.
