-- 0012_show_caption.sql
-- Pilihan per konten: tampilkan judul & keterangan bersama media di TV.
--
-- Default true agar perilaku konten lama tidak berubah. Panel admin
-- mengirim false untuk foto/video baru sampai admin secara sadar
-- mengaktifkan teks, sehingga judul/deskripsi tidak muncul tanpa izin.
-- Nilai ini hanya dipakai untuk konten bertipe foto/video; tipe lain
-- selalu menampilkan teksnya.

alter table public.contents
  add column if not exists show_caption boolean not null default true;

comment on column public.contents.show_caption is
  'Tampilkan judul/keterangan di samping media pada TV (foto/video).';
