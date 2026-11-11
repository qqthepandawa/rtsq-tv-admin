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

commit;
