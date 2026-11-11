-- 0012_show_caption.sql
alter table public.contents
  add column if not exists show_caption boolean not null default true;

comment on column public.contents.show_caption is
  'Tampilkan judul/keterangan di samping media pada TV (foto/video).';
