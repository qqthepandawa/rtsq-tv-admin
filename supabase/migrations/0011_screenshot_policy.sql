-- 0011_screenshot_policy.sql
-- Perangkat TV boleh mengunggah tangkapan layar ke prefix
-- `screenshots/{device_id}/` pada bucket privat `tv-media`.
--
-- Sebelumnya hanya admin yang boleh insert, sehingga perintah `screenshot`
-- tidak pernah bisa menyimpan hasil tangkapan layar.

drop policy if exists tv_media_screenshot_insert on storage.objects;
create policy tv_media_screenshot_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'tv-media'
    and public.is_paired_device()
    and (storage.foldername(name))[1] = 'screenshots'
    and (storage.foldername(name))[2] = (
      select d.id::text
        from public.devices d
       where d.auth_uid = auth.uid()
         and d.status = 'paired'
       limit 1
    )
  );

drop policy if exists tv_media_screenshot_update on storage.objects;
create policy tv_media_screenshot_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'tv-media'
    and public.is_paired_device()
    and (storage.foldername(name))[1] = 'screenshots'
    and (storage.foldername(name))[2] = (
      select d.id::text
        from public.devices d
       where d.auth_uid = auth.uid()
         and d.status = 'paired'
       limit 1
    )
  )
  with check (
    bucket_id = 'tv-media'
    and public.is_paired_device()
    and (storage.foldername(name))[1] = 'screenshots'
    and (storage.foldername(name))[2] = (
      select d.id::text
        from public.devices d
       where d.auth_uid = auth.uid()
         and d.status = 'paired'
       limit 1
    )
  );
