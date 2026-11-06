-- RTSQ TV — migrasi bagian 07 dari 10
-- Sumber: 0004_functions.sql … 0005_rls.sql
-- Jalankan di SQL Editor Supabase, satu bagian per Run, urut dari 01.

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

-- Selesai bagian 07. Lanjut ke bagian berikutnya.
