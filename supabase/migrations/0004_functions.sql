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
