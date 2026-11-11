# Blueprint RTSQ TV v2.2

**Aplikasi layar TV RTSQ (Android TV / Google TV) + panel admin**

| | |
|---|---|
| Versi | 2.2 – 6 November 2026 (revisi: TV lobby — mode sholat dihapus) |
| Status | Draf untuk persetujuan pemilik |
| Pemilik | RTSQ — Rumah Tahfizh Smart Qur'an, Batam |
| Perangkat target | AQUA MatrixTV CE, Android TV 14 |
| Backend | **Supabase — proyek baru `rtsq-tv`, terpisah penuh dari RTSQ Mobile** |
| Dokumen asal | Blueprint RTSQ TV v1 (Claude AI) |

---

## 0. Ringkasan perubahan dari v1

| # | Bagian | Perubahan di v2 | Alasan |
|---|---|---|---|
| 1 | Backend | Dikunci ke **Supabase**: proyek baru `rtsq-tv`, database baru, tanpa keterkaitan dengan RTSQ Mobile | Keputusan pemilik; RTSQ TV adalah produk terpisah |
| 2 | Admin | Dikunci ke **web admin** (bukan menu di aplikasi lain) dengan multi-akun dan peran | Pemilik butuh tambah/kurangi admin; web tidak perlu rilis app |
| 3 | Sumber jadwal | **myquran/Kemenag menjadi sumber utama**, Aladhan dibuang | Uji 4 Nov 2026: Aladhan salah kota dan selisih 2–4 menit |
| 4 | Waktu | Tambah layanan waktu UTC+7 + koreksi jam dari header HTTP | Hitung mundur harus benar walau jam TV melenceng |
| 5 | Jadwal offline | Simpan jadwal tahunan di dalam APK (aset) + refresh | TV tetap benar berbulan-bulan tanpa internet |
| 6 | Perangkat | Bagian 0.5 baru: uji perangkat nyata sebelum koding besar | Launcher Aqua adalah risiko terbesar proyek |
| 7 | Konten | Tambah status draf/tayang, prioritas, mode darurat, validasi media, kuota cache | v1 terlalu sederhana untuk operasi harian |
| 8 | Playlist | Tambah mesin playlist, preload, penanganan media gagal | Mencegah layar hitam dan item kedaluwarsa |
| 9 | Layar | Tambah state machine prioritas layar | Perlu aturan jelas saat mode darurat/slideshow bentrok |
| 10 | Keamanan | Tambah auth perangkat, token, RLS/rules, pencabutan, audit | Kode pairing saja tidak cukup |
| 11 | Operasional | Tambah skrip provisioning ADB, kartu pemulihan, backup keystore | Tanpa ini TV tidak bisa dirawat |
| 12 | Screenshot | Diganti tangkapan internal `RepaintBoundary` + ADB | MediaProjection tidak bisa otomatis di TV |
| 13 | Ruang lingkup | **TV lobi — bukan layar masjid**: mode sholat, iqamah, dan ihtiyati dihapus sepenuhnya | TV hanya mengingatkan masuknya waktu sholat, bukan menuntun ibadah |
| 14 | Admin | Pengaturan ihtiyati/iqamah/khutbah/mode sholat dihapus; layar & database diselaraskan | Konsisten dengan cakupan lobby |

Yang **tidak berubah**: tujuan, tata letak tiga zona, prinsip TV hanya menampilkan, roadmap bertahap, dan larangan menyimpan rahasia di repo.

---

## 1. Tujuan, cakupan, non-cakupan

### 1.1 Tujuan
TV lobi RTSQ menyala → langsung menampilkan RTSQ TV layar penuh → konten dapat diubah dari HP oleh lebih dari satu admin, tanpa menyentuh TV.

**Bukan untuk sholat.** TV lobi hanya mengingatkan masuknya waktu sholat (kartu aktif, hitung mundur); tidak ada mode sholat, iqamah, atau layar redup.

### 1.2 Cakupan
- Jam besar, nama & alamat lembaga, tanggal Masehi dan Hijriah.
- Jadwal sholat Batam, kartu aktif, hitung mundur — pengingat masuknya waktu sholat (bukan untuk sholat).
- Slideshow: pengumuman, prestasi santri, foto/poster, video kegiatan, jadwal kegiatan.
- Teks berjalan.
- Mode darurat (pesan mendesak menutupi layar).
- Panel admin web multi-pengguna.
- Pairing TV tanpa mengetik di remote.
- Tetap berfungsi saat internet putus (minimal 30 hari).
- Pemantauan: status online, log, perintah jarak jauh.
- Kiosk: app menjadi beranda atau dibuka otomatis saat TV menyala.

### 1.3 Non-cakupan (v2.2)
- Suara adzan (disiapkan arsitekturnya, tidak diaktifkan).
- Multi-lembaga dalam satu instalasi (satu `orgId`, field disiapkan).
- Statistik penayangan.
- Aplikasi pendamping di Muttaqin — **Muttaqin adalah proyek terpisah dan tidak disentuh**.
- Integrasi apa pun dengan RTSQ Mobile (database, auth, storage, dan repo berbeda).
- Aplikasi mobile native untuk admin (cukup web/PWA).
- Update APK otomatis tanpa konfirmasi (tidak realistis tanpa device owner).
- **Mode sholat, iqamah, dan pengaturan ihtiyati** — TV lobi tidak memimpin ibadah; hanya pengingat masuknya waktu sholat.

---

## 2. Lingkungan & perangkat

### 2.1 Spesifikasi terkonfirmasi
| Item | Nilai |
|---|---|
| Model | AQUA MatrixTV CE (HAIER) |
| OS | Android TV 14 |
| Patch keamanan | 1 Februari 2026 |
| Kernel | 5.15.180++ |
| Build | UKNV.260302.001 |
| Sertifikasi | Ada Netflix ESN → perangkat tersertifikasi Google |

### 2.2 Arti untuk teknis
- **Android 14**: `targetSdk` 34, `compileSdk` 35/36. Flutter 3.44 aman.
- Pembatasan *background activity launch* berlaku; app yang berperan sebagai **HOME** dikecualikan, jadi jalur launcher lebih aman daripada boot receiver.
- **Device owner tidak direncanakan**: TV kemungkinan sudah login akun Google, dan `dpm set-device-owner` akan gagal. Jalur kiosk utama: intent HOME + `cmd package set-home-activity`. Cadangan: nonaktifkan launcher bawaan lewat ADB, atau dongle HDMI.
- **Play Services tersedia** (perangkat tersertifikasi). Supabase tidak membutuhkannya — semua lewat HTTPS — tetapi sertifikasi ini berguna untuk perilaku Home dan Play Store di masa depan.

### 2.3 Data yang masih harus diambil lewat ADB (Fase 0.5)
```text
adb shell cat /proc/meminfo | findstr MemTotal
adb shell df -h /data
adb shell getprop ro.product.cpu.abi
adb shell getprop ro.sf.lcd_density
adb shell wm size
adb shell cmd package resolve-activity -c android.intent.category.HOME
adb shell pm list packages | findstr launcher
adb shell settings get global device_provisioned
adb shell dumpsys account | findstr Account
```
Hasilnya menentukan: batas ukuran media, jumlah pemutar video, dan apakah launcher bawaan boleh dinonaktifkan.

---

## 3. Arsitektur

```text
┌────────────────────┐        ┌──────────────────────────────┐
│  Admin web (HP/PC) │        │  Supabase (proyek baru)      │
│  Flutter Web       │◄──────►│  Auth • Postgres • Storage   │
│  Supabase Auth     │        │  Realtime • RPC • RLS        │
└────────────────────┘        └───────────────┬──────────────┘
                                              │ realtime + polling 60 dtk
┌────────────────────┐                        │
│  TV: RTSQ TV       │◄───────────────────────┘
│  Flutter + Android │
│  snapshot lokal    │──── heartbeat, log, status perintah ────►
│  media cache       │
└────────────────────┘
```

### 3.1 Pembagian tanggung jawab
- **TV**: hanya membaca. Menyimpan snapshot + media. Menjalankan timer lokal. Tidak pernah menulis konten.
- **Admin web**: satu-satunya penulis konten, pengaturan, dan perintah.
- **Postgres (Supabase)**: sumber kebenaran metadata, antrean perintah, log, dan audit.
- **Storage (Supabase)**: file media, bucket privat + signed URL.
- **Realtime**: memberi tahu TV saat konten berubah; polling 60 detik sebagai cadangan.
- **Hosting admin**: Cloudflare Pages atau Netlify (gratis). Supabase hanya backend.

### 3.2 Pemisahan dari RTSQ Mobile
- **Proyek Supabase baru**, bukan proyek RTSQ Mobile. Database, auth, storage, dan kunci berbeda.
- Tidak ada satu pun tabel, bucket, atau aturan yang dibagi dengan RTSQ Mobile.
- `applicationId` TV: `id.rtsq.tv`.
- Repo terpisah. Muttaqin dan RTSQ Mobile tidak disentuh.
- Keuntungan: perubahan skema TV tidak bisa merusak aplikasi lain, dan kuota Storage tidak berebut.

### 3.3 Sumber data jadwal sholat (keputusan)
Berdasarkan pengujian 4 November 2026:

| Sumber | Subuh | Dzuhur | Maghrib | Isya | Catatan |
|---|---|---|---|---|---|
| Aladhan `timingsByCity?city=Batam` | salah | salah | salah | salah | API mengembalikan koordinat 8.8888/7.7777, lokasi Jakarta |
| Aladhan koordinat benar, method 20 | 04:26 | 11:47 | 17:50 | 19:01 | Selisih 2–4 menit dari Kemenag |
| myquran `0506` KOTA BATAM | 04:28 | 11:51 | 17:53 | 19:03 | Lengkap: imsak 04:18, terbit 05:42, dhuha 06:10 |

**Keputusan:** myquran (data Kemenag) = sumber utama. `adhan` = cadangan untuk tanggal di luar data tersimpan. Aladhan tidak dipakai.

**Strategi data:**
1. Saat build, unduh jadwal Batam untuk 2026–2028 dari myquran, simpan di `assets/prayer/`.
2. Verifikasi sampel 3 bulan terhadap `bimasislam.kemenag.go.id`; catat hasil verifikasi di `docs/verifikasi-jadwal.md`.
3. Saat runtime, utamakan aset; jika tanggal di luar aset, coba unduh; jika gagal, hitung `adhan` dengan parameter Kemenag (Subuh 20°, Isya 18°, ihtiyati 2 menit — parameter metode resmi, tetap, bukan pengaturan pengguna).
4. Prefetch tahun berikutnya mulai 1 November.
5. Tidak ada koreksi manual per waktu sholat di admin. Data Kemenag bersifat final; jadwal resmi sudah termasuk ihtiyati.

---

## 4. Prinsip kerja & aturan proyek

1. Offline-first: tampilan pertama dari snapshot lokal, bukan menunggu jaringan.
2. TV tidak pernah menampilkan pesan error teknis; cukup indikator titik status kecil.
3. Satu fase per sesi. Tidak melompat fase, tidak menambah fitur di luar fase.
4. Setiap perubahan logika wajib punya unit test (waktu, jadwal, hijriah, filter konten, playlist).
5. Tidak ada kunci rahasia di repo. Kunci `anon` Supabase boleh dipublikasikan; **`service_role` tidak pernah** masuk app, repo, atau chat.
6. Struktur data tidak diubah tanpa persetujuan pemilik.
7. Bila ada asumsi belum jelas, bertanya — bukan menebak.
8. Semua waktu dihitung pada **UTC+7 eksplisit**, tidak bergantung pada timezone perangkat.
9. Tidak ada animasi berat. Target: 60 fps untuk jam, 30 fps untuk teks berjalan.
10. Setiap fase selesai dengan: kode, tes, cara menjalankan, daftar selesai/belum, risiko.
11. TV lobi hanya **mengingatkan** masuknya waktu sholat; tidak ada mode sholat, iqamah, layar redup, atau pengaturan ihtiyati.

---

## 5. Tata letak layar

### 5.1 Kanvas & skala
- Kanvas desain: **1920 × 1080**.
- Android TV umumnya melaporkan 1920×1080 ke aplikasi, bahkan pada panel 4K. Jangan berasumsi 4K.
- Skala: `FittedBox`/`Transform.scale` dari kanvas 1920×1080 ke ukuran layar; tidak ada ukuran piksel yang di-hardcode per perangkat.
- Safe area: **3%** (≈ 57 px horizontal, 32 px vertikal). Informasi penting tidak boleh di 5% tepi.

### 5.2 Zona
| Zona | Isi | Tinggi | Piksel |
|---|---|---|---|
| Header | Jam besar (kiri), logo + nama + alamat (tengah), tanggal Masehi & Hijriah (kanan) | 13% | 140 px |
| Konten | Slideshow gambar/video/kartu teks | 62% | 670 px |
| Strip sholat | 7 kartu: Imsak, Subuh, Syuruq, Dzuhur, Ashar, Maghrib, Isya | 17% | 184 px |
| Ticker | Teks berjalan | 8% | 86 px |

### 5.3 Tipografi
| Elemen | Ukuran | Berat |
|---|---|---|
| Jam | 104–120 px | 700 |
| Nama lembaga | 40 px | 700 |
| Alamat | 26–28 px | 400 |
| Tanggal | 30 px | 500 |
| Label kartu sholat | 24 px | 600 |
| Waktu sholat | 38 px | 700 |
| Hitung mundur | 28 px | 600 |
| Judul konten | 52–60 px | 700 |
| Isi konten | 34–38 px | 400 |
| Ticker | 30–34 px | 500 |

Font Latin: **Plus Jakarta Sans** (atau Inter). Font Arab: **Amiri** atau **Scheherazade New**, dengan dukungan RTL.
Tidak ada teks di bawah 24 px.

### 5.4 Palet (diturunkan dari logo resmi)
| Peran | Hex | Asal |
|---|---|---|
| Latar utama | `#0B1714` | turunan hijau gelap |
| Panel | `#12211D` | |
| Emas RTSQ | `#C9AE5C` | logo `#BBA84C` dicerahkan untuk kontras |
| Teal YKCA | `#12B3A0` | logo `#07A78F` |
| Teks utama | `#F7F3E8` | |
| Teks sekunder | `#9FB0A8` | |
| Sorot aktif | `#C9AE5C` 20% + garis emas | |
| Darurat | `#E0574A` | |

Kontras teks utama terhadap latar > 7:1.

### 5.5 Aturan logo
- **RTSQ** dominan di header, tinggi 110–130 px, memakai `RTSQ white Real.png` (teks putih).
- **YKCA** tinggi 72–88 px, ditempatkan di ujung kanan strip ticker atau layar idle. Bila kontras kurang pada latar gelap, dibuat versi putih/mono resmi.
- Kedua logo tidak berdampingan besar di header agar tidak ramai.
- Butuh file SVG/HD dari yayasan untuk ketajaman 4K dan cetak.

### 5.6 Prinsip render
- Jam dan hitung mundur di widget terpisah dengan `RepaintBoundary`, agar tidak me-rebuild seluruh layar tiap detik.
- Teks berjalan: satu `AnimationController` linear, 30 fps, `RepaintBoundary`.
- Tidak ada blur, shadow besar, atau gradien animasi.

---

## 6. Spesifikasi fitur

### 6.1 Jam & sinkronisasi waktu
- Sumber waktu: `DateTime.now().toUtc().add(7 jam)`.
- Koreksi: ambil header `Date` dari `https://www.gstatic.com/generate_204` saat start dan tiap 6 jam. Simpan `clockOffsetMs`.
- Jika koreksi gagal, pakai jam perangkat.
- Tampilkan jam `HH:mm` (detik dihilangkan atau kecil).
- Uji: jam TV dimajukan 10 menit → countdown tetap benar setelah koreksi.

### 6.2 Jadwal sholat
- 7 kartu. `terbit` dari API dipetakan ke **Syuruq**.
- Status kartu:
  - **Aktif**: waktu sholat terakhir yang sudah lewat (bukan Imsak/Syuruq).
  - **Berikutnya**: waktu berikutnya, dengan hitung mundur.
  - Imsak dan Syuruq ditampilkan tetapi tidak pernah menjadi "sholat aktif".
- Hari Jumat: label kartu Dzuhur menjadi **Jumat**.
- Tidak ada opsi ihtiyati per waktu di admin; ihtiyati 2 menit adalah bagian dari metode resmi Kemenag dan sudah termasuk di jadwal sumber.
- Ganti hari pada 00:00 lokal; jadwal bulan berikutnya sudah tersedia di cache.

### 6.3 Tanggal Hijriah
- Sumber: paket `hijri` (tabular) + **offset per bulan** yang dapat diatur admin.
- Nama bulan dan hari dalam Bahasa Indonesia.
- Opsi **tanggal berganti saat Maghrib** (default aktif).
- Tampil: `Rabu, 4 November 2026 • 24 Jumadil Awal 1448 H`.
- Offset disimpan sebagai peta `{ "1448-05": -1 }`, bukan satu angka global.

### 6.4 Slideshow & mesin playlist
Jenis item: pengumuman, prestasi, foto/poster, video, jadwal kegiatan.

Aturan:
- Setiap item: `startAt`, `endAt`, `order`, `durationSec`, `active`, `status`, `pinned`, `priority`.
- Urutan: `pinned` dulu, lalu `order`, lalu `updatedAt`.
- Item di luar rentang tanggal dilewati.
- Video diputar sampai selesai (maks 120 detik), tanpa suara kecuali diaktifkan per item.
- Gambar/teks tampil `durationSec` (default 10 detik, rentang 5–60).
- Preload item berikutnya: gambar di-`precacheImage`, video dengan pemutar kedua.
- Transisi: fade 300–400 ms. Tidak ada slide/zoom.
- Media gagal: coba sekali, lalu lewati + catat log; tidak menghentikan playlist.
- Jika tidak ada konten: layar idle (logo, jam, jadwal, kutipan).
- Video wajib H.264/AAC, `faststart`, maks 1080p, maks 60 MB.
- Gambar maks 1920×1080, maks 4 MB setelah kompresi.

### 6.5 Teks berjalan
- Daftar kalimat dengan `startAt`/`endAt`, urut, aktif.
- Digabung dengan pemisah `•`, kecepatan dapat diatur (default 60 px/detik).
- Berjalan terus; tidak ada jeda untuk sholat. Pada mode darurat, ticker disembunyikan.

### 6.6 Pengingat waktu sholat (bukan mode sholat)
- TV lobi hanya mengingatkan masuknya waktu sholat: kartu sholat aktif di-highlight, kartu berikutnya menampilkan hitung mundur.
- Tidak ada layar penuh sholat, tidak ada iqamah, tidak ada hitung mundur iqamah, tidak ada layar redup.
- Jadwal tetap tampil di samping slideshow; konten berjalan terus tanpa dijeda.
- Hari Jumat: label kartu Dzuhur menjadi **Jumat**. Tidak ada khutbah/durasi terpisah.
- Pengingat ringan tidak pernah menjeda atau mengalahkan slideshow.

### 6.7 Mode darurat
- Admin mengirim pesan darurat (judul, isi, warna, durasi atau sampai dicabut).
- Menutupi seluruh layar, prioritas tertinggi.
- Setelah dicabut, layar kembali normal.
- Dicatat di audit log.

### 6.8 Layar idle
- Logo RTSQ + YKCA, jam, jadwal sholat, kutipan/ayat bergilir (opsional).
- Tampil bila tidak ada konten atau saat pairing.

### 6.9 Prioritas layar (state machine)
```text
darurat (100)
  > pairing (90)
  > slideshow (50)
  > idle (20)
  > boot/error (10)
```
- Error tidak menutupi layar jika snapshot terakhir masih bisa ditampilkan; cukup titik status.
- Transisi hanya lewat satu `ScreenController`, diuji dengan unit test.

### 6.10 Pairing TV
Alur:
1. TV start → login anonim Supabase → buat baris `devices` status `pending` → tampilkan 6 digit + QR.
2. QR berisi URL admin: `https://<host>/pair?code=482913`.
3. Admin scan QR / buka halaman pairing → melihat nama perangkat → konfirmasi.
4. Admin menulis `status: paired` + `orgId`; TV mendeteksi → menyimpan status → memuat konten.
5. Kode berlaku 10 menit, sekali pakai, maksimal 5 percobaan; percobaan dicatat.
6. Admin dapat mencabut perangkat (`revoked`); TV kembali ke layar pairing.
7. Jika TV offline saat pertama menyala: tampil mode offline (logo + jadwal lokal) dan pairing dicoba ulang tiap 30 detik.

### 6.11 Offline & cache
- Setelah sync sukses: tulis `snapshot.json` (atomik: tulis `.tmp` → rename).
- Media diunduh ke folder `media/` dengan nama hash + checksum.
- Anggaran cache: **maks 500 MB** (dapat diubah). Pembersihan LRU; item yang sedang tampil tidak dihapus.
- Buka app: baca snapshot < 2 detik, tampilkan; sinkronisasi di latar.
- Jika storage < 100 MB: berhenti mengunduh video, catat peringatan, beri tahu admin lewat heartbeat.

### 6.12 Heartbeat, log, perintah jarak jauh
- Heartbeat tiap 2 menit: `lastSeenAt`, versi app, status layar, konten aktif, sisa storage, jenis jaringan.
- Log: maksimal 50 entri/jam, dikirim tiap jam atau saat error; retensi 30 hari.
- Perintah: `reload_content`, `reload_prayer`, `restart_app`, `clear_cache`, `test_screen`, `screenshot`, `reload_settings`.
- Status perintah: `pending → running → done/failed`, dengan waktu dan hasil.
- Screenshot: `RepaintBoundary.toImage()` → JPEG 1280 px → Storage. Area video akan hitam (diketahui dan didokumentasikan).
- Alert offline: dasbor menandai TV offline > 10 menit. Notifikasi otomatis (Telegram/email) menyusul lewat `pg_cron` + Edge Function — tidak wajib untuk versi awal.

### 6.13 Kiosk & auto-start
- `AndroidManifest`: `LEANBACK_LAUNCHER` + `HOME` + `DEFAULT`, `singleTask`, `stateNotNeeded`.
- `uses-feature`: leanback (required=false), touchscreen (required=false).
- Immersive sticky, `FLAG_KEEP_SCREEN_ON`, `wakelock_plus`.
- Provisioning ADB mematikan screensaver dan mengatur home activity.
- Boot receiver disiapkan sebagai cadangan, tetapi bukan jalur utama.
- Watchdog: `runZonedGuarded` + restart terjadwal lewat `AlarmManager` bila crash.
- Restart malam otomatis pukul 03:00 sebagai katup memori.
- Jalur keluar darurat: tahan tombol `BACK` 5 detik → PIN 4 digit → buka Pengaturan/TV.

---

## 7. Model data Supabase (Postgres)

Database baru, tanpa prefiks warisan. Skema `public`, tipe waktu `timestamptz`, ID `uuid` (`gen_random_uuid()`).

### 7.0 Tipe enum
```sql
admin_role      : 'super' | 'editor'
device_status   : 'pending' | 'paired' | 'revoked'
content_type    : 'announcement' | 'achievement' | 'photo' | 'video' | 'schedule'
content_status  : 'draft' | 'published' | 'archived'
command_status  : 'pending' | 'running' | 'done' | 'failed'
log_level       : 'info' | 'warn' | 'error'
```

### 7.1 `profiles` (admin, 1:1 dengan `auth.users`)
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid PK | = `auth.users.id` |
| email | citext unique | |
| name | text | |
| role | admin_role | default `editor` |
| active | bool | default true |
| created_at / created_by | timestamptz / uuid | |

### 7.2 `admin_invites`
| Kolom | Tipe | Keterangan |
|---|---|---|
| email | citext PK | |
| role | admin_role | |
| invited_by | uuid | |
| expires_at | timestamptz | default +7 hari |
| created_at | timestamptz | |

Alur: super admin mengundang email → orang mendaftar → RPC `accept_invite()` membuat baris `profiles` → undangan dihapus.

### 7.3 `devices`
| Kolom | Tipe | Keterangan |
|---|---|---|
| id | uuid PK | |
| auth_uid | uuid unique | pemilik sesi anonim |
| name | text | mis. "TV Kantor" |
| status | device_status | default `pending` |
| pairing_code | text | 6 digit, unik saat pending |
| pairing_expires_at | timestamptz | +10 menit |
| pairing_attempts | int | |
| model / android_version / app_version | text | |
| last_seen_at / last_sync_at | timestamptz | |
| current_content_id | uuid | |
| screen_state | text | `content`/`emergency`/`idle` |
| storage_used_bytes / storage_free_bytes | bigint | |
| network | text | `wifi`/`ethernet`/`none` |
| paired_at / paired_by | timestamptz / uuid | |
| created_at | timestamptz | |

### 7.4 `settings` (satu baris, `id = 1`)
| Kolom | Tipe |
|---|---|
| org_name, address, city | text |
| latitude, longitude | numeric(9,6) |
| timezone | text default `Asia/Jakarta` |
| hijri_offset | jsonb (peta bulan → hari) |
| slide_duration_seconds | int |
| ticker_speed | int |
| theme | jsonb |
| emergency | jsonb \| null |
| updated_at / updated_by | timestamptz / uuid |

### 7.5 `contents`
| Kolom | Tipe |
|---|---|
| id | uuid PK |
| type | content_type |
| title | text not null |
| body | text |
| media | jsonb `[{path, type, width, height, size_bytes, checksum, thumbnail_path}]` |
| student_name, marhalah, achievement | text |
| achieved_at | date |
| schedule_items | jsonb `[{title, date, time, place}]` |
| start_at, end_at | timestamptz |
| sort_order, duration_seconds, priority | int |
| pinned, active | bool |
| status | content_status |
| created_by, updated_by, approved_by | uuid |
| created_at, updated_at, approved_at | timestamptz |
| version | int default 1 |

### 7.6 `ticker`
`id`, `text`, `start_at`, `end_at`, `sort_order`, `active`, `created_by`, `created_at`.

### 7.7 `commands`
`id`, `device_id`, `type`, `payload`, `status`, `created_by`, `created_at`, `claimed_at`, `executed_at`, `result`.

Tipe awal: `reload_content`, `reload_prayer`, `restart_app`, `clear_cache`, `test_screen`, `screenshot`, `reload_settings`.

### 7.8 `logs`
`id bigserial`, `device_id`, `level`, `message`, `context jsonb`, `created_at`.
Retensi 30 hari (pg_cron).

### 7.9 `audit_log`
`id bigserial`, `actor`, `action`, `entity`, `entity_id`, `diff jsonb`, `created_at`.
Ditulis hanya lewat trigger/fungsi `security definer`.

### 7.10 RPC (wajib, agar perangkat tidak punya UPDATE bebas)
| Fungsi | Pemanggil | Fungsi |
|---|---|---|
| `pair_device(code, name)` | admin | Validasi kode + kedaluwarsa + percobaan; set `paired`; catat audit |
| `device_heartbeat(...)` | TV | Update `last_seen_at`, versi, storage, status layar; kembalikan versi settings/konten |
| `claim_commands()` | TV | Ambil perintah `pending` miliknya secara atomik, set `running` |
| `complete_command(id, status, result)` | TV | Tutup perintah |
| `accept_invite()` | admin baru | Cocokkan email dengan undangan, buat `profiles`, hapus undangan |
| `set_admin_active(uid, active)` | super | Aktif/nonaktifkan admin; tolak jika super terakhir |
| `purge_old_logs()` | pg_cron | Hapus log > 30 hari |

Semua fungsi `security definer` dengan `set search_path = public`, dan memeriksa `auth.uid()` di dalam badan fungsi.

### 7.11 RLS (ringkasan)
```text
is_admin()          -> profiles.active = true untuk auth.uid()
is_super()          -> is_admin() dan role = 'super'
is_paired_device()  -> devices.auth_uid = auth.uid() dan status = 'paired'
```
| Tabel | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| profiles | admin | RPC saja | super | super |
| admin_invites | super | super | — | super |
| settings | admin / device | — | super | — |
| contents | admin / device | admin | admin | admin |
| ticker | admin / device | admin | admin | admin |
| devices | admin / pemilik | pemilik (`pending`) | RPC/admin | admin |
| commands | admin / pemilik | admin | RPC saja | admin |
| logs | admin / pemilik | pemilik | — | admin |
| audit_log | admin | fungsi saja | — | — |

Aturan tambahan:
- Perangkat tidak boleh membaca konten lembaga lain (saat ini satu lembaga; `org_id` disiapkan bila multi-lembaga).
- Trigger menaikkan `contents.version` dan `updated_at`.
- Trigger mencegah super admin terakhir dinonaktifkan/dihapus.
- `anon` key aman dipublikasikan; **`service_role` tidak pernah masuk app/repo**.

### 7.12 Storage
- Bucket privat `tv-media`.
- Path: `contents/{content_id}/{uuid}.{ext}`, `screenshots/{device_id}/{timestamp}.jpg`.
- RLS Storage: baca = authenticated (admin + perangkat paired), tulis = admin.
- Batas: gambar ≤ 4 MB, video ≤ 60 MB, hanya `image/jpeg|png|webp`, `video/mp4`.
- TV memakai **signed URL 7 hari**; file sudah diunduh ke cache, jadi tetap bisa diputar setelah URL kedaluwarsa.
- Thumbnail dibuat di browser admin (canvas) dan diunggah terpisah.

### 7.13 Realtime
- Publikasi `supabase_realtime` untuk `contents`, `ticker`, `settings`, `commands`.
- TV berlangganan `postgres_changes`; bila koneksi putus, polling 60 detik mengambil `updated_at` terbaru.
- Dasbor admin berlangganan `devices` untuk status online.

### 7.14 Indeks
```text
contents (status, active, start_at, end_at, sort_order)
ticker (active, start_at)
commands (device_id, status, created_at)
logs (device_id, created_at desc)
devices (pairing_code) unique where status = 'pending'
devices (last_seen_at)
```

### 7.15 Bootstrap admin pertama
Setelah Bapak mendaftar di web admin, jalankan sekali di SQL Editor:
```sql
insert into public.profiles (id, email, name, role)
select id, email, 'Admin RTSQ', 'super' from auth.users where email = 'email-bapak@...';
```
Admin berikutnya cukup lewat undangan di panel.

---

## 8. Model data lokal TV

```text
<appSupport>/
  snapshot.json        # settings, contents, ticker, generatedAt, schemaVersion
  state.json           # deviceUid, paired, lastSyncAt, clockOffsetMs, appVersion
  prayer/2026.json     # salinan jadwal tahunan (seed dari aset)
  media/<sha1>.<ext>   # media terunduh
  logs/pending.jsonl   # log belum terkirim
```

`snapshot.json` ditulis atomik. `schemaVersion` dipakai untuk migrasi. Media hanya dihapus setelah snapshot baru sukses ditulis.

---

## 9. Panel admin web

### 9.1 Bentuk
Flutter Web di folder `admin/`, di-hosting **Cloudflare Pages** (atau Netlify) pada URL terpisah. Bisa dipasang sebagai PWA di HP (Add to Home Screen). Tidak perlu rilis ke Play Store, dan tidak memakai hosting Supabase karena Supabase hanya backend.

### 9.2 Halaman
| Halaman | Isi |
|---|---|
| Masuk | Email/password, lupa sandi (Supabase Auth), Google Sign-In opsional |
| Dasbor | Status TV (online/offline, terakhir terlihat), konten sedang tampil, versi app, sisa storage, tombol perintah cepat |
| Konten | Daftar, tambah, ubah, hapus, urutkan (drag), jadwal tayang, status draf/tayang, pin, prioritas |
| Pratinjau | Kanvas 16:9 persis seperti TV |
| Ticker | CRUD kalimat |
| Pengaturan | Nama/alamat, koordinat, Hijriah, durasi slide, tema, mode darurat |
| Perangkat | Pairing, ganti nama, cabut, lihat versi |
| Log | Filter level dan waktu |
| Akun | Undang admin, ubah peran, nonaktifkan |
| Audit | Siapa mengubah apa dan kapan |

### 9.3 Peran
| Peran | Hak |
|---|---|
| `super` | Semua + kelola akun + pengaturan + perintah berisiko |
| `editor` | Konten, ticker, pratinjau, perintah ringan (reload) |

### 9.4 Unggah media
1. Pilih file di HP.
2. Kompres gambar di browser ke maks 1920 px, JPEG kualitas 85.
3. Video divalidasi (durasi, codec, ukuran); jika terlalu besar, tolak dengan pesan jelas.
4. Unggah ke Storage, buat thumbnail, tulis metadata + checksum.
5. Pratinjau 16:9 sebelum menekan **Tayangkan**.

### 9.5 Notifikasi
- TV offline > 10 menit → tanda merah di dasbor.
- Konten berakhir < 2 hari → pengingat.
- Konten ditolak validasi → pesan spesifik.

---

## 10. Struktur folder

```text
rtsq_tv/
  lib/
    main.dart
    app/                 # shell, routing, ScreenController, kiosk
    core/                # tema, konstanta, util tanggal, hijriah, waktu
    data/                # model, supabase client, repository, snapshot store, cache
    features/
      header/
      prayer/
      slideshow/
      ticker/
      pairing/
      emergency/
      status/
  assets/
    brand/               # logo RTSQ, YKCA, font
    prayer/              # jadwal tahunan Batam
    mock/                # data Fase 0
  android/               # manifest TV, receiver, AlarmManager
  test/                  # unit + golden test
  admin/                 # Flutter Web admin
  supabase/
    migrations/          # skema, RLS, RPC, storage policies
    seed.sql
  tools/                 # skrip provisioning ADB, kompres media
  docs/                  # verifikasi jadwal, kartu pemulihan, ADR
  AGENTS.md
  Blueprint RTSQ TV v2.md
```

---

## 11. Stack & dependensi

| Kebutuhan | Pilihan | Alasan |
|---|---|---|
| UI TV | Flutter 3.44 | Satu bahasa, sudah dikuasai |
| Backend | **Supabase (proyek baru)** | Database baru, terpisah dari RTSQ Mobile |
| Auth | Supabase Auth (anonim untuk TV, email untuk admin) | Tanpa server sendiri |
| Media | Supabase Storage (bucket privat + signed URL) | Satu ekosistem, RLS |
| Admin | Flutter Web + Cloudflare Pages | Tanpa rilis app |
| Video | `video_player` (ExoPlayer) | Hardware decode, ringan |
| Gambar | `Image.file` + `cacheWidth` / `cached_network_image` | Kontrol RAM |
| Jadwal | `adhan` (fallback) + aset myquran | Terbukti dipakai Muttaqin, akurat |
| Database lokal | JSON snapshot + file (bukan drift) | Data kecil, tahan migrasi, mudah dipulihkan |
| HTTP | `http` atau `dio` | Sederhana |
| Waktu | `intl` + offset UTC+7 | Format Indonesia |
| Ticker | `AnimationController` + `RepaintBoundary` | Ringan |
| QR | `qr_flutter` | Pairing |
| Keamanan | `flutter_secure_storage` | Token perangkat |
| Watchdog | native `AlarmManager` + `runZonedGuarded` | Android 14 friendly |
| Info app | `package_info_plus`, `device_info_plus` | Heartbeat |

---

## 12. Roadmap & kriteria selesai

Estimasi part-time dengan AI-assisted development.

### Fase 0 — Fondasi & prototipe visual (2–3 hari)
**Kerja:**
- Repo Flutter, `applicationId id.rtsq.tv`, minSdk 23, targetSdk 34.
- Tema brand, font, logo, palet.
- UI 1920×1080 lengkap dengan data mock.
- Konfigurasi Android TV: leanback, banner 320×180, landscape, immersive.
- Unduh system image Android TV, buat AVD 1080p, jalankan.
- Golden test 1920×1080 dan 1280×720.

**Selesai bila:** tampil benar di emulator TV; teks terbaca dari 3 meter; tidak ada overflow; tidak ada animasi berat.

### Fase 0.5 — Uji perangkat nyata (0,5–1 hari)
**Kerja:**
- Aktifkan Opsi Pengembang + wireless debugging, pairing ADB.
- Kumpulkan RAM, storage, CPU, density, resolusi, paket launcher.
- Pasang APK Fase 0 di TV Aqua.
- Uji Home, boot, screensaver, 2 jam menyala.
- Tulis `docs/tv-aqua.md` + `tools/provision_tv.ps1`.

**Selesai bila:** hasil uji terdokumentasi dan keputusan launcher diambil (tetap Aqua atau pindah dongle).

### Fase 1 — Waktu & jadwal sholat (3–4 hari)
**Kerja:**
- `TimeService` UTC+7 + koreksi header Date.
- Aset jadwal 2026–2028 + verifikasi Kemenag.
- Engine jadwal, hitung mundur, highlight, Jumat.
- Hijriah + offset + pergantian Maghrib.
- Pengingat masuknya waktu sholat: kartu aktif, hitung mundur, label Jumat.
- Unit test rollover, bulan baru, Jumat, jam salah, offline.

**Selesai bila:** cocok dengan jadwal resmi Batam; tetap benar setelah restart dan setelah internet dimatikan.

### Fase 2a — Supabase & sinkronisasi (3–4 hari)
**Kerja:**
- Buat proyek Supabase `rtsq-tv`, simpan migrasi SQL di repo (`supabase/migrations/`).
- Auth anonim untuk TV, tabel `devices`, RPC pairing, QR.
- RLS + RPC heartbeat/command, indeks, Realtime.
- Realtime + polling 60 detik, snapshot atomik, unduh media (signed URL), checksum, kuota 500 MB.
- Heartbeat + log.

**Selesai bila:** konten baru muncul ≤ 60 detik; TV jalan 24 jam offline; pairing berhasil dari HP; `service_role` tidak ada di APK.

### Fase 2b — Playlist & prioritas (2–3 hari)
**Kerja:**
- Mesin playlist, preload, video, fade, fallback.
- Ticker.
- State machine: darurat, slideshow, idle.
- Log & perintah jarak jauh.

**Selesai bila:** tidak ada layar hitam antar item; media rusak dilewati; mode darurat mengalahkan slideshow dan kembali dengan benar.

### Fase 3 — Admin web (5–7 hari)
**Kerja:**
- Flutter Web, login, peran, undangan akun.
- CRUD konten + unggah + kompres + thumbnail + pratinjau 16:9.
- Pengaturan, perangkat, log, audit, darurat.
- Deploy ke Cloudflare Pages.

**Selesai bila:** guru non-teknis dapat menambah satu pengumuman dari HP tanpa bantuan, dan hasilnya sama dengan pratinjau.

### Fase 4 — Kiosk & kestabilan (3–4 hari)
**Kerja:**
- Home intent, provisioning, wakelock, screensaver off.
- Watchdog, restart malam, layar error.
- Uji 7 hari.

**Selesai bila:** TV menyala langsung masuk RTSQ TV; 7 hari tanpa disentuh; pulih otomatis setelah crash; pemulihan ADB tercatat dan pernah diuji.

### Fase 5 — Opsional
Suara adzan, mode Ramadhan (imsak/iftar), multi-TV, statistik, update APK, notifikasi otomatis.

---

## 13. Rencana uji

| Uji | Cara | Kriteria |
|---|---|---|
| Jam & countdown | Ubah jam TV +10 menit | Tetap benar setelah koreksi |
| Offline 24 jam | Cabut internet, restart TV | Konten & jadwal tetap tampil |
| Rollover bulan | Set tanggal ke akhir bulan | Jadwal bulan baru benar |
| Hijriah | Cek 3 tanggal terhadap Kemenag | Selisih ≤ offset yang diset |
| Jumat | Set tanggal Jumat | Label Jumat |
| Media rusak | Ganti file dengan byte acak | Item dilewati, log tercatat |
| Video besar | Unggah 4K 5 menit | Ditolak dengan pesan jelas |
| Storage penuh | Isi cache > kuota | LRU berjalan, app tetap tampil |
| Pairing | Kode salah 5× | Kode hangus |
| Crash | Paksa exception | App pulih ≤ 30 detik |
| 7 hari | Biarkan menyala | Tidak ada freeze, RAM stabil |
| Golden | 1920×1080 & 1280×720 | Tidak ada overflow/teks terpotong |

---

## 14. Risiko & mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Launcher Aqua tidak bisa diganti | Home kembali ke Google TV | Uji Fase 0.5; cadangan dongle HDMI |
| Device owner tidak tersedia | Tidak ada kiosk penuh | Jalur HOME + PIN keluar |
| RAM TV kecil | Video patah-patah | Batas 1080p, satu pemutar aktif, preload terbatas |
| Internet kantor tidak stabil | Konten lama | Snapshot + media lokal, 30 hari |
| Captive portal WiFi | TV offline setelah reboot | Ethernet atau bypass MAC |
| Supabase Free membatasi storage/egress | Media tidak bisa diunggah | Cek kuota; kompres; upgrade Pro bila perlu |
| Jam TV melenceng | Countdown salah | Koreksi header Date |
| Jadwal beda 1-2 menit | Komplain | Data Kemenag |
| Hijriah beda 1 hari | Komplain | Offset per bulan |
| Update APK terhambat | Versi lama | ADB/Tailscale + Play internal track |
| Kehilangan keystore | Tidak bisa update | Backup di password manager + cetak |
| Kuota penyimpanan habis | TV berhenti sync | Kuota 500 MB + LRU + peringatan |
| Data santri | Privasi | Izin orang tua + hanya nama depan/kelas |
| Screenshot video hitam | Salah paham | Dokumentasi + pratinjau admin |

---

## 15. Operasional & pemulihan

### 15.1 Provisioning satu kali (ADB)
```text
adb connect <ip-tv>:5555
adb install -r rtsq_tv.apk
adb shell settings put system screen_off_timeout 2147483647
adb shell settings put global stay_on_while_plugged_in 3
adb shell settings put secure screensaver_enabled 0
adb shell settings put global auto_time 1
adb shell settings put global auto_time_zone 1
adb shell cmd package set-home-activity id.rtsq.tv/.MainActivity
# hanya jika perlu, setelah dicatat:
# adb shell pm disable-user --user 0 <paket-launcher-bawaan>
```
Semua perintah disimpan di `tools/provision_tv.ps1` dan `docs/tv-aqua.md`, termasuk perintah pemulihan `pm enable`.

### 15.2 Kartu pemulihan (dicetak, disimpan di ruang TV)
- Nama paket launcher bawaan: ______________
- Perintah pemulihan: `pm enable ______________`
- IP TV / Tailscale: ______________
- Akun Google TV: ______________
- PIN keluar darurat: ______________
- Kontak admin: ______________

### 15.3 Backup
- Keystore APK + password: password manager + salinan cetak.
- Konten: tombol **Ekspor JSON** di admin (bulan depan) + media di Storage.
- Skema & RLS: disimpan di repo (`supabase/migrations/`) dan diterapkan lewat CLI.
- Database: `supabase db dump` berkala (mingguan) disimpan di luar repo.
- Daftar admin dan undangan: diekspor berkala.

### 15.4 Pemeliharaan rutin
- Cek dasbor mingguan: TV online, storage, versi.
- Perbarui aset jadwal tiap November.
- Bersihkan log > 30 hari.
- Uji pemulihan ADB setiap 6 bulan.

---

## 16. Yang dibutuhkan dari pemilik (checklist Supabase)

| # | Item | Cara | Untuk apa |
|---|---|---|---|
| 1 | **Proyek Supabase baru** bernama `rtsq-tv`, region **Singapore (ap-southeast-1)** | Supabase Dashboard → New project | Database baru, terpisah dari RTSQ Mobile |
| 2 | **Project URL** + **anon public key** | Project Settings → API | Konfigurasi app TV & admin |
| 3 | Aktifkan **Anonymous Sign-ins** | Authentication → Providers → Anonymous | Login TV tanpa akun |
| 4 | Aktifkan **Email provider** | Authentication → Providers → Email | Login admin |
| 5 | Tentukan **konfirmasi email** aktif atau tidak | Authentication → Settings | Alur undangan admin |
| 6 | **Site URL** dan **Redirect URLs** admin | Authentication → URL Configuration | Reset sandi & login web |
| 7 | Email admin awal (Bapak + lainnya) | — | Undangan akun |
| 8 | Paket Supabase (Free/Pro) + kuota Storage | Dashboard → Billing | Batas media |
| 9 | Konfirmasi proyek **tidak dipakai** aplikasi lain | — | Isolasi data |
| 10 | Cara menerapkan migrasi: Bapak jalankan sendiri, atau beri akses CLI | SQL Editor / Supabase CLI | Membuat tabel, RLS, bucket |

**Jangan kirim:** `service_role` key, password database, atau access token pribadi. Cukup URL + anon key. Migrasi SQL akan saya siapkan sebagai berkas yang bisa Bapak tempel di SQL Editor.

Catatan: `anon` key memang dirancang untuk publik; keamanan dijaga oleh RLS, bukan oleh kerahasiaan kunci.

---

## 17. Keputusan terbuka

1. ~~URL admin~~ → **diputusi: `main.rtsq-tv-admin.pages.dev` (gratis)**. `tv.rtsq.id` tidak dipakai; QR TV sudah diarahkan ke domain gratis.
2. Perlu persetujuan sebelum konten tayang? (default: tidak, semua editor langsung tayang; status draf tersedia).
3. Nama lengkap santri pada konten prestasi: nama lengkap atau nama depan + kelas?
4. Logo YKCA: apakah ada versi putih/mono dan aturan co-branding dari yayasan?
5. Jam operasional TV (mis. mati otomatis 22:00–05:00) atau menyala 24 jam?
6. Apakah TV sudah login akun Google? (menentukan jalur kiosk)
7. Siapa pemegang akun Supabase (super admin) dan siapa yang boleh menambah admin?

---

## 18. Lampiran

### 18.1 Endpoint jadwal
```text
Daftar kota:  GET https://api.myquran.com/v2/sholat/kota/semua
Bulanan:      GET https://api.myquran.com/v2/sholat/jadwal/0506/{tahun}/{bulan}
Harian:       GET https://api.myquran.com/v2/sholat/jadwal/0506/{tahun}/{bulan}/{hari}
```
Kota Batam = `0506`.

### 18.2 Contoh `snapshot.json`
```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-11-04T10:00:00+07:00",
  "settings": { "namaLembaga": "RTSQ", "durasiSlideDefault": 10 },
  "contents": [],
  "ticker": [],
  "prayer": { "source": "myquran", "year": 2026 }
}
```

### 18.3 Templat perintah per fase
> Baca `AGENTS.md` dan `Blueprint RTSQ TV v2.md` bagian 12. Kerjakan Fase [N] saja. Buat rencana singkat, tunggu persetujuan, lalu implementasikan. Sertakan tes dan cara menjalankan di emulator/TV. Di akhir, laporkan selesai/belum dan risiko.

### 18.4 Isi `AGENTS.md` (ringkas)
- Tujuan & arsitektur.
- Aturan satu fase per sesi.
- Aturan kualitas: `flutter analyze`, `flutter test`, golden test.
- Larangan: rahasia di repo, ubah skema tanpa izin, sentuh proyek Muttaqin/RTSQ Mobile.
- Perintah build & run TV.
- Konvensi penamaan dan struktur folder.

### 18.5 Urutan migrasi Supabase
```text
supabase/migrations/0001_extensions.sql    -- pgcrypto, citext
0002_types.sql                             -- semua enum
0003_tables.sql                            -- tabel + indeks + trigger updated_at/version
0004_functions.sql                         -- is_admin, is_super, is_paired_device,
                                              pair_device, heartbeat, claim/complete,
                                              accept_invite, set_admin_active, purge_logs
0005_rls.sql                               -- enable RLS + policy per tabel
0006_storage.sql                           -- bucket tv-media + policy storage.objects
0007_realtime.sql                          -- publication untuk 4 tabel
0008_seed.sql                              -- baris settings awal (Batam)
```

### 18.6 Contoh policy Storage
```sql
insert into storage.buckets (id, name, public)
values ('tv-media', 'tv-media', false)
on conflict (id) do nothing;

create policy "tv_media_read" on storage.objects
  for select to authenticated
  using (bucket_id = 'tv-media');

create policy "tv_media_write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'tv-media' and public.is_admin());
```

### 18.7 Perintah CLI (dijalankan pemilik)
```text
npm i -g supabase
supabase login
supabase link --project-ref <project-ref>
supabase db push
```
Jika Bapak tidak ingin memakai CLI, semua berkas migrasi bisa ditempel berurutan di **SQL Editor**.
