# Supabase — RTSQ TV

Proyek Supabase terpisah dari RTSQ Mobile. Tidak ada Firestore, tidak ada
`service_role` di aplikasi maupun repo.

> **Status 6 Nov 2026:** migrasi sudah diterapkan ke proyek
> `qrjamxhbfnemfinqbhfh` (160 statement, sukses). **Anonymous Sign-ins aktif**
> (verifikasi API 200, `is_anonymous: true`). Aplikasi TV sudah memakai auth
> anonim, `register_device`, heartbeat, dan snapshot (Fase 2a). Sisa: panel
> admin untuk menyetujui pairing + bootstrap profil admin pertama.

## Isi migrasi

Jalankan **berurutan** di SQL Editor (atau `supabase db push`):

> Cara tercepat: buka `supabase/apply_all.sql` (gabungan 0001–0010, sudah
> dibungkus `begin; … commit;`), tempel seluruh isinya ke SQL Editor, lalu
> **Run** sekali. Berkas itu dibuat ulang dengan
> `node tools/build_apply_all.mjs`.
>
> **Jika paste terpotong** (mis. editor berhenti di baris tertentu), gunakan
> folder `supabase/chunks/` — 14 berkas berurutan yang masing-masing < 175
> baris. Jalankan `01.sql` sampai `14.sql`, satu per **Run**. Panduan ada di
> `supabase/chunks/README.md`.
>
> **Perbaikan v2.2 (6 Nov 2026):** `0009_remove_sholat_mode.sql` menghapus
> kolom `ihtiyati`, `iqamah_minutes`, `khutbah_minutes`,
> `prayer_duration_minutes`, dan `prayer_mode_enabled` dari `settings`.
> Jalankan sekali di SQL Editor (atau `11.sql` di folder chunks).
>
> **Perbaikan 5 Nov 2026:** blok `DO` di `0002` kini ditutup `end; $$;`
> (PL/pgSQL mewajibkan titik koma), dan diff audit di `0003` memakai
> `jsonb_object_agg` — bukan operator `jsonb - jsonb` yang tidak ada di
> PostgreSQL. Seluruh migrasi 0002–0008 sudah diuji lokal dengan PGlite.

| Berkas | Isi |
|---|---|
| `0001_extensions.sql` | `pgcrypto`, `citext` |
| `0002_types.sql` | enum `admin_role`, `device_status`, `content_type`, `content_status`, `command_status`, `log_level` |
| `0003_tables.sql` | tabel, indeks, trigger `updated_at`/`version`, audit |
| `0004_functions.sql` | helper RLS + RPC pairing, heartbeat, commands, invite, admin |
| `0005_rls.sql` | RLS + policy tiap tabel |
| `0006_storage.sql` | bucket privat `tv-media` + policy |
| `0007_realtime.sql` | publikasi `contents`, `ticker`, `settings`, `commands` |
| `0008_seed.sql` | baris `settings` Batam + ticker sambutan |
| `0009_remove_sholat_mode.sql` | hapus kolom ihtiyati/iqamah/khutbah/prayer mode (v2.2) |
| `0010_consistency_fixes.sql` | constraint `screen_state`, consent santri, guard super terakhir, batas log, pairing 5x, heartbeat dengan jumlah konten, pembersihan perangkat pending, policy Storage berprefix |
| `0011_screenshot_policy.sql` | policy Storage `screenshots/` untuk perangkat TV |
| `0012_show_caption.sql` | kolom `contents.show_caption` (izin menampilkan teks foto/video di TV) |

## Setelah migrasi

1. **Authentication → Providers → Anonymous Sign-ins: aktifkan.**
   Dipakai TV untuk mendaftar sebagai perangkat.
2. Daftarkan email admin pertama lewat panel web, lalu jalankan sekali:

   ```sql
   insert into public.profiles (id, email, name, role)
   select id, email, 'Admin RTSQ', 'super'
     from auth.users
    where email = 'email-bapak@contoh.id'
   on conflict (id) do nothing;
   ```

3. Opsional: jadwalkan pembersihan log (butuh `pg_cron`):

   ```sql
   select cron.schedule(
     'rtsq-purge-old-logs', '15 3 * * *',
     $$select public.purge_old_logs()$$
   );
   ```

## Yang dibutuhkan aplikasi

Hanya dua nilai, keduanya aman dipublikasikan (sudah tersedia di aplikasi):

- `SUPABASE_URL` — `https://qrjamxhbfnemfinqbhfh.supabase.co`
- `SUPABASE_PUBLISHABLE_KEY` (anon key)

**Jangan pernah** memakai/menyimpan `service_role`.

Project ref: `qrjamxhbfnemfinqbhfh`.

## CLI (opsional, jika ingin `db push`)

```powershell
npm i -g supabase
supabase login
supabase init
supabase link --project-ref qrjamxhbfnemfinqbhfh
supabase db push
```

Jika tidak ingin menginstal CLI, tempelkan `supabase/apply_all.sql` sekali di
**SQL Editor** Supabase, atau 10 berkas migrasi secara berurutan (lihat daftar
di atas).

## Verifikasi setelah migrasi

1. Buka **Authentication → Providers**.
2. Pastikan **Anonymous Sign-in** diaktifkan (wajib untuk pairing TV).
3. Daftarkan email Anda di panel web admin, lalu jalankan sekali di SQL Editor:

   ```sql
   insert into public.profiles (id, email, name, role)
   select id, email, 'Admin RTSQ', 'super'
     from auth.users
    where email = 'email-anda@contoh.id'
   on conflict (id) do nothing;
   ```

4. Admin berikutnya cukup ditambahkan lewat menu undangan di panel web.

## Alur perangkat (TV)

1. TV memanggil `register_device()` → dapat `pairing_code` 6 digit, berlaku 10 menit.
2. Admin membuka panel → masukkan kode → RPC `pair_device(code)`.
3. TV polling `device_heartbeat()`; bila `status = paired`, TV mengunduh snapshot.
4. Perintah dari admin diambil lewat `claim_commands()`, ditutup dengan
   `complete_command()`.

## Catatan keamanan

- Semua tabel memakai RLS. Perangkat paired hanya bisa **membaca** konten
  `published` + `active`, ticker aktif, dan settings.
- Perangkat tidak punya policy `UPDATE` bebas; perubahan status hanya lewat RPC
  `security definer`.
- `audit_log` hanya bisa dibaca admin; penulisan lewat trigger definer.
- Storage `tv-media` privat; TV memakai signed URL 7 hari dan menyimpan cache.
