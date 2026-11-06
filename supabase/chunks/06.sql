-- RTSQ TV — migrasi bagian 06 dari 10
-- Sumber: 0004_functions.sql
-- Jalankan di SQL Editor Supabase, satu bagian per Run, urut dari 01.

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

-- Selesai bagian 06. Lanjut ke bagian berikutnya.
