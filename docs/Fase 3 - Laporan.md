# Laporan Fase 3 — Panel Admin Web RTSQ TV

Status: **kode admin web selesai, terverifikasi di browser, dan sudah di-deploy ke Cloudflare Pages (domain gratis). QR di TV kini mengarah ke domain `pages.dev`; pairing end-to-end siap diuji.**

Domain admin gratis: **https://main.rtsq-tv-admin.pages.dev**

Tanggal: 6 November 2026 (deploy: 6 November 2026)

## 1. Scope Fase 3 (selesai)

Panel admin web (Flutter Web, folder `admin/`, project `rtsq_admin`) yang menjadi satu-satunya penulis konten, pengaturan, perangkat, dan akun admin RTSQ TV. Di-hosting di Cloudflare Pages domain gratis, tanpa rilis Play Store.

| Halaman | Isi | Berkas |
|---|---|---|
| Masuk / Daftar | Email/password, lupa sandi, daftar dengan nama (nama disimpan saat accept undangan) | `lib/features/auth/login_page.dart` |
| Pairing | Setujui TV via kode 6 digit dari `/?code=` atau input manual | `lib/features/pair/pair_page.dart` |
| Dasbor | Status TV online/offline, konten tayang, ticker, durasi slide, identitas layar, tombol konten baru | `lib/features/dashboard/dashboard_page.dart` |
| Konten | Daftar, tambah, ubah, hapus, urutkan, sematkan, pratinjau 16:9, status tayang/draf | `lib/features/content/content_page.dart`, `content_editor_page.dart` |
| Pratinjau TV | Kanvas 16:9 persis seperti TV (header, slide, sholat, ticker) | `lib/features/preview/preview_page.dart`, `tv_preview.dart` |
| Ticker | CRUD kalimat berjalan + jadwal mulai/selesai | `lib/features/ticker/ticker_page.dart` |
| Pengaturan | Identitas, koordinat, Hijriah, durasi slide, tema, mode darurat | `lib/features/settings/settings_page.dart` |
| Perangkat | Pairing (super saja), ganti nama, perintah (reload/restart/screenshot/sync), cabut, hapus | `lib/features/devices/devices_page.dart` |
| Log | Log perangkat dengan filter level, pembersihan log lama (super) | `lib/features/logs/logs_page.dart` |
| Akun | Undang admin, ubah peran, nonaktifkan (super saja) | `lib/features/accounts/accounts_page.dart` |
| Audit | Jejak perubahan konten, ticker, pengaturan, perangkat, akun | `lib/features/audit/audit_page.dart` |

### Peran
| Peran | Hak |
|---|---|
| `super` | Semua + kelola akun + pengaturan + pairing + perintah berisiko |
| `editor` | Konten, ticker, pratinjau, perintah ringan (reload); pengaturan baca saja; tidak bisa halaman akun |

## 2. Arsitektur & keamanan

- **Supabase** project terpisah `rtsq-tv` (ref `qrjamxhbfnemfinqbhfh`). Hanya **publishable key** di repo; tidak ada `service_role`.
- **Auth**: Supabase email/password. Profil 1:1 dengan `auth.users` lewat tabel `profiles` (RLS).
- **RLS**: semua tabel diaktifkan; `profiles`/`admin_invites` hanya `is_admin()`/`is_super()`; `settings`/`contents`/`ticker` readable perangkat paired via `is_paired_device()`.
- **RPC `security definer`**: `register_device`, `pair_device`, `device_heartbeat`, `accept_invite`, `set_admin_active`, `purge_old_logs`, command executor.
- **Path URL strategy** (`usePathUrlStrategy`) → URL bersih `/pair?code=123456`. Cloudflare Pages fallback: `web/_redirects` (`/* /index.html 200`).
- **Waktu**: semua tampilan pakai WIB (UTC+7) eksplisit lewat `Wib`, tidak bergantung zona perangkat.
- **Media**: unggah via `file_picker` (web API `pickFile` + `readAsBytes`), gambar dikompres ke maks 1920 px JPEG q85 + thumbnail 640, checksum sha256, bucket privat `tv-media`, signed URL 6 jam.
- **PWA**: `manifest.json` + ikon 192/512 + maskable dari logo resmi RTSQ, `web/index.html` berbranding dengan splash yang dihapus setelah first frame Flutter.

## 3. Verifikasi visual di browser (localhost:8088)

Build web release berhasil (`flutter build web --release` → `√ Built build\web`). Tujukan dengan Python static server + SPA fallback, lalu diperiksa di browser:

| Halaman | Hasil | Bukti |
|---|---|---|
| `/login` (desktop 800×526) | Branding RTSQ, formulir masuk/daftar, tombol Masuk, Lupa sandi, catatan bootstrap | `docs/preview/admin-login.png` |
| `/login` (seluler 360×740) | Tanpa overflow, panel merek versi ringkas (hanya logo + judul) | uji widget + layar nyata |
| `/pair?code=123456` | Kode TV ditampilkan besar di atas kartu masuk, pesan bootstrap terlihat | `docs/preview/admin-pair.png` |
| Tidak ada jaringan error | 14 request, 0 gagal | browser network log |

Tes otomatis: `flutter analyze` **No issues found**, `flutter test` **9 tes lulus** (format WIB, model konten/perangkat/pengaturan, format Hijriah, widget login seluler + lebar).

Catatan: persetujuan pairing memerlukan akun admin yang sudah ada di `profiles`; user sudah menjalankan bootstrap SQL, jadi pairing end-to-end siap dicoba.

## 4. Deploy ke Cloudflare Pages (diselesaikan)

Proyek `rtsq-tv-admin` terhubung ke GitHub (`qqthepandawa/rtsq-tv-admin`).

1. Build lokal berhasil, lalu **direct upload** melalui Wrangler:

   ```powershell
   cd "C:\RTSQ TV\admin\build\web"
   npx wrangler pages deploy . --project-name rtsq-tv-admin
   ```

   Hasil: deployment lengkap di `https://main.rtsq-tv-admin.pages.dev` (48 file sudah ter-upload, `_redirects` ikut).

2. **Auto-build dari Git gagal** (Cloudflare salah mendeteksi Worker: `Build command: None`, `Deploy command: npx wrangler deploy`). Solusi praktis: pakai direct upload. Jika ingin auto-build, set di project:
   - Root directory: `/admin`
   - Build command: `flutter build web --release`
   - Build output directory: (untuk Pages: `build/web`); pastikan `web/_redirects` tergabung.
   Atau tetap gunakan `wrangler pages deploy` setiap kali ada perubahan.

3. **`tv.rtsq.id` (kustom) tidak dipakai** karena proyek berjalan dengan 0 biaya dan `rtsq.id` dikelola di provider lain. QR di TV kini mengarah ke `https://main.rtsq-tv-admin.pages.dev/pair?code=…`.
   - Bila suatu saat Anda memiliki `tv.rtsq.id`, cukup tambahkan CNAME `tv` → `rtsq-tv-admin.pages.dev` di DNS provider (menu Custom domains di project Pages) — tidak perlu ubah kode.

## 5. Bootstrap admin pertama (sudah dijalankan user)

1. Pastikan **Authentication → Providers → Anonymous Sign-ins** aktif (untuk pairing TV).
2. Daftarkan email admin pertama lewat halaman Masuk panel admin.
3. Jalankan sekali di SQL Editor:

```sql
insert into public.profiles (id, email, name, role)
select id, email, 'Admin RTSQ', 'super'
  from auth.users
 where email = 'email-anda@contoh.id'
on conflict (id) do nothing;
```

4. Masuk kembali di panel → profil terbentuk sebagai `super`. Admin berikutnya ditambahkan lewat menu **Akun** (undangan berlaku 7 hari).

## 6. Kecepatan/PWA & entry point TV

- Admin: `https://main.rtsq-tv-admin.pages.dev` (login di `/login`, QR pairing menuju `/pair?code=…`).
- TV APK perlu di-rebuild agar QR mengarah ke domain gratis ini. Kode sudah diubah; rebuild + pasang ulang APK bila ingin QR bisa dipakai.
  - Build: `flutter build apk --release` (di folder `rtsq_tv`)
  - Jika hanya untuk verifikasi pairing, bisa langsung buka panel → **Perangkat → Pasangkan TV** → masukkan kode dari layar TV (tidak tergantung QR).

## 7. Langkah berikutnya

1. Rebuild APK TV, pasang, dan uji pairing menggunakan kode `233443` (atau kode baru di layar TV).
2. Verifikasi TV memuat snapshot + heartbeat end-to-end.
3. Tambahkan pengumuman pertama dari admin → verifikasi muncul di TV dalam ±60 detik.
4. Lanjutkan Fase 2b: media cache lokal 500 MB LRU, video/playlist engine,
   eksekusi perintah/logs, Realtime, layar idle, mode darurat.

## 8. Berkas baru / diubah

- `admin/` — seluruh project panel admin (baru)
- `docs/Fase 3 - Laporan.md` — laporan ini (diperbarui)
- `rtsq_tv/lib/core/app_info.dart` — `adminBaseUrl` → `https://main.rtsq-tv-admin.pages.dev`
- `admin/lib/core/supabase_config.dart` — `adminBaseUrl` → `https://main.rtsq-tv-admin.pages.dev`
- `supabase/README.md` — berisi petunjuk bootstrap admin
