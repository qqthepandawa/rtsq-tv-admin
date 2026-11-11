-- 0012_storage_unlimited.sql
-- Hapus batas ukuran per-bucket `tv-media`; batas efektif mengikuti
-- "Global file size limit" project (Dashboard → Storage → Settings).
--
-- Catatan paket Supabase:
-- - Free : global limit maksimum 50 MB per berkas (tidak bisa dinaikkan).
-- - Pro  : global limit dapat dinaikkan sampai 500 GB.
--
-- Jadi, untuk mengunggah video >50 MB, naikkan Global file size limit di
-- Dashboard lebih dulu; bucket ini tidak lagi menambah batas sendiri.

update storage.buckets
   set file_size_limit = null
 where id = 'tv-media';