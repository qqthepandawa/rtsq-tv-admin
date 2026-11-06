# Laporan Fase 3 — Panel Admin Web RTSQ TV

Status: **kode admin web selesai, diverifikasi secara visual di browser, siap di-deploy ke Cloudflare Pages setelah DNS `tv.rtsq.id` aktif dan bootstrap admin pertama dijalankan.**

Tanggal: 6 November 2026

## 1. Scope Fase 3 (selesai)

Panel admin web (Flutter Web, folder `admin/`, project `rtsq_admin`) yang menjadi satu-satunya penulis konten, pengaturan, perangkat, dan akun admin RTSQ TV. Di-hosting terpisah dari aplikasi TV pada `https://tv.rtsq.id` (Cloudflare Pages), tanpa rilis Play Store.

| Halaman | Isi | Berkas |
|---|---|---|
| Masuk / Daftar | Email/password, lupa sandi, daftar dengan nama (nama disimpan saat accept undangan) | `lib/features/auth/login_page.dart` |
| Pairing | Setujui TV via kode 6 digit dari `/?code=` atau input manual | `lib/features/pair/pair_page.dart` |
| Dasbor | Status TV online/offline, konten tayang, ticker, durasi slide, identitas layar, tombol konten baru | `lib/features/dashboard/dashboard_page.dart` |
| Konten | Daftar, tambah, ubah, hapus, urutkan, sematkan, pratinjau 16:9, status tayang/draf | `lib/features/content/content_page.dart`, `content_editor_page.dart` |
| Pratinjau TV | Kanvas 16:9 persis seperti TV (header, slide, sholat, ticker) | `lib/features/preview/preview_page.dart`, `tv_preview.dart` |
| Ticker | CRUD kalimat berjalan + jadwal mulai/selesai | `lib/features/ticker/ticker_page.dart` |
| Pengaturan | Identitas, koordinat, ihtiyati/iqamah, Hijriah, durasi slide, mode darurat | `lib/features/settings/settings_page.dart` |
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

Build web release berhasil (`flutter build web --release` → `√ Built build\web`). Diserpak dengan Python static server + SPA fallback, lalu diperiksa di browser:

| Halaman | Hasil | Bukti |
|---|---|---|
| `/login` (desktop 800×526) | Branding RTSQ, formulir masuk/daftar, tombol Masuk, Lupa sandi, catatan bootstrap | `docs/preview/admin-login.png` |
| `/login` (seluler 360×740) | Tanpa overflow, panel merek versi ringkas (hanya logo + judul) | uji widget + layar nyata |
| `/pair?code=123456` | Kode TV ditampilkan besar di atas kartu masuk, pesan bootstrap terlihat | `docs/preview/admin-pair.png` |
| Tidak ada jaringan error | 14 request, 0 gagal | browser network log |

Tes otomatis: `flutter analyze` **No issues found**, `flutter test` **9 tes lulus** (format WIB, model konten/perangkat/pengaturan, format Hijriah, widget login seluler + lebar).

Catatan: persetujuan pairing sebenarnya memerlukan akun admin yang sudah ada di `profiles` (bootstrap SQL di `supabase/README.md`), sehingga endpoint `/pair` hanya bisa diuji utuh setelah admin pertama dibuat manual di Supabase SQL Editor.

## 4. Bootstrap admin pertama (perlu dijalankan pengguna di Supabase SQL Editor)

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

## 5. Langkah ke depan (Fase 3 selesai → deploy)

1. Konfirmasi DNS `tv.rtsq.id` milik RTSQ dan arahkan ke Cloudflare Pages.
2. Buat proyek Cloudflare Pages, hubungkan repo, build settings:
   - Build command: `flutter build web --release`
   - Build directory: `admin/build/web`
   - Output directory: `build/web`
   - Pastikan `web/_redirects` tergabung (SPA fallback untuk `/pair?code=`).
3. Deploy, lalu buka `https://tv.rtsq.id/pair?code=<kode-TV>` dari TV untuk pairing end-to-end.
4. Pair emulator `google_tv_34` (kode `938000` atau baru) dari admin UI, verifikasi TV memuat snapshot + heartbeat.
5. Tambahkan pengumuman pertama dari admin → verifikasi muncul di TV dalam ±60 detik.
6. Lanjutkan Fase 2b: media cache lokal 500 MB LRU, video/playlist engine, terapkan `ihtiyati`/`iqamah` di TV, eksekusi perintah/logs, Realtime.

## 6. Berkas baru / diubah

- `admin/` — seluruh project panel admin (baru)
- `docs/Fase 3 - Laporan.md` — laporan ini (baru)
- `supabase/README.md` — sudah ada, berisi petunjuk bootstrap admin
