-- RTSQ TV — migrasi bagian 04 dari 10
-- Sumber: 0004_functions.sql
-- Jalankan di SQL Editor Supabase, satu bagian per Run, urut dari 01.

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

-- Selesai bagian 04. Lanjut ke bagian berikutnya.
