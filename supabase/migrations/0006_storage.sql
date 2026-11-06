-- 0006_storage.sql
-- Bucket privat `tv-media` + policy Storage (Blueprint 7.12 / 18.6).
--
-- Batas bucket 60 MB (video). Gambar dibatasi 4 MB di panel admin.
-- Hanya tipe yang diizinkan.

insert into storage.buckets (id, name, "public", file_size_limit, allowed_mime_types)
values (
  'tv-media',
  'tv-media',
  false,
  62914560,
  array['image/jpeg', 'image/png', 'image/webp', 'video/mp4']
)
on conflict (id) do update
  set "public" = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists tv_media_read on storage.objects;
create policy tv_media_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'tv-media'
    and (public.is_admin() or public.is_paired_device())
  );

drop policy if exists tv_media_insert on storage.objects;
create policy tv_media_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'tv-media' and public.is_admin());

drop policy if exists tv_media_update on storage.objects;
create policy tv_media_update on storage.objects
  for update to authenticated
  using (bucket_id = 'tv-media' and public.is_admin())
  with check (bucket_id = 'tv-media' and public.is_admin());

drop policy if exists tv_media_delete on storage.objects;
create policy tv_media_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'tv-media' and public.is_admin());
