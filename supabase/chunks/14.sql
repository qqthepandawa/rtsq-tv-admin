-- 0010 (lanjutan) - purge perangkat pending dan policy Storage
-- Jalankan setelah 13.sql.

begin;

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

