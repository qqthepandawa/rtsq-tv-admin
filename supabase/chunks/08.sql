-- RTSQ TV — migrasi bagian 08 dari 10
-- Sumber: 0005_rls.sql
-- Jalankan di SQL Editor Supabase, satu bagian per Run, urut dari 01.

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

-- Selesai bagian 08. Lanjut ke bagian berikutnya.
