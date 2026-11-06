-- RTSQ TV — migrasi bagian 03 dari 10
-- Sumber: 0003_tables.sql … 0004_functions.sql
-- Jalankan di SQL Editor Supabase, satu bagian per Run, urut dari 01.

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

-- Selesai bagian 03. Lanjut ke bagian berikutnya.
