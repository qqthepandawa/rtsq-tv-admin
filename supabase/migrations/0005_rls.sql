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
