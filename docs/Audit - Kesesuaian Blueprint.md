# Audit Kesesuaian — Blueprint RTSQ TV (v2.1 → v2.2)

Tanggal audit: 5 November 2026 (diperbarui 6 November 2026 untuk v2.2)
Objek: `rtsq_tv` (Flutter) + `supabase/migrations`
Metode: baca Blueprint §5–§13, lalu cocokkan dengan kode aktual (bukan ingatan).

**Catatan v2.2 (6 Nov 2026):** TV lobi, bukan layar masjid. Mode sholat,
iqamah, ihtiyati, khutbah, dan kolom pengaturan terkait dihapus dari blueprint,
aplikasi TV, panel admin, dan skema database (`0009_remove_sholat_mode.sql`).
Jadwal sholat kini murni pengingat masuknya waktu.

---

## 1. Kesimpulan

| Pertanyaan | Jawaban |
|---|---|
| Apakah aplikasi sudah sesuai Blueprint? | **Untuk kerangka visual Fase 0: sebagian besar sesuai.** Untuk keseluruhan Blueprint: **belum** — baru Fase 0. |
| Apakah Fase 0 sudah "selesai" menurut definisinya? | **Belum.** P0 sudah selesai; yang tersisa hanya uji di perangkat TV nyata dan kriteria "terbaca dari 3 meter". |
| Apakah ada penyimpangan pada yang sudah dibangun? | **Ya, 6 penyimpangan visual/teknis** yang perlu diputuskan (lihat §3). |
| Apakah backend sesuai §7? | **Ya.** Skema, enum, RPC, RLS, storage, realtime, dan seed sudah ditulis lengkap. Belum dijalankan ke proyek. |
| Apakah ada `service_role` di app/repo? | **Tidak.** Hanya publishable/anon key. |

Ringkas: **arahnya benar, tetapi belum "sesuai blueprint" secara menyeluruh.** Yang
sudah ada adalah fondasi visual + skema database; fitur inti (waktu, jadwal,
sinkronisasi, admin) masih fase berikutnya.

---

## 2. Matriks per fase

| Fase | Status | Bukti / catatan |
|---|---|---|
| **0 — Fondasi & prototipe visual** | 🟡 **6/7 item** | UI, tema, Android TV, APK, golden 1920 & 720 jadi. Emulator/perangkat TV belum. |
| **0.5 — Uji perangkat nyata** | ⚪ belum | Panduan ada; ADB/TV belum tersentuh. |
| **1 — Waktu & jadwal sholat** | ⚪ belum | Masih data mock statis. |
| **2a — Supabase & sinkronisasi** | 🟡 **DB siap, app belum** | 8 migrasi ditulis; auth anonim, pairing, heartbeat, cache belum. |
| **2b — Playlist & prioritas** | ⚪ belum | Belum ada state machine/playlist. |
| **3 — Admin web** | ⚪ belum | Folder `admin/` belum ada. |
| **4 — Kiosk & kestabilan** | ⚪ belum | Manifest HOME sudah; watchdog/PIN keluar belum. |
| **5 — Opsional** | ⚪ belum | — |

Kriteria selesai Fase 0:

| Kriteria | Status |
|---|---|
| Tampil benar di emulator TV | ❌ belum dijalankan |
| Teks terbaca dari 3 meter | ❌ belum diuji |
| Tidak ada overflow | ✅ 1920×1080 dan 1280×720 (golden lulus, tanpa overflow) |
| Tidak ada animasi berat | ✅ satu controller ticker + fade |

---

## 3. Penyimpangan yang sudah ada (perlu keputusan)

> Catatan: bagian ini merekam kondisi **sebelum P0**. Status terkini ada di §8.

### 3.1 Tipografi jauh di bawah spesifikasi

Blueprint §5.3 menetapkan ukuran dan aturan **"tidak ada teks di bawah 24 px"**.
Kenyataannya ada **10 tingkat ukuran di bawah 24 px** (12–22 px).

| Elemen | Blueprint | Aktual | Status |
|---|---|---|---|
| Jam | 104–120 px | **96 px** | ⚠️ |
| Nama lembaga | 40 px | **28 px** | ⚠️ |
| Alamat | 26–28 px | 26 px | ✅ |
| Tanggal | 30 px | 30 px | ✅ |
| Label kartu sholat | 24 px | **21 px** | ⚠️ |
| Waktu sholat | 38 px | 40 px | ✅ |
| Hitung mundur | 28 px | **15 px** | ❌ |
| Judul konten | 52–60 px | 56 px | ✅ |
| Isi konten | 34–38 px | **31 px** | ⚠️ |
| Ticker | 30–34 px | 31 px | ✅ |
| Teks minimum | ≥ 24 px | **12–22 px di 10 tempat** | ❌ |

Contoh teks < 24 px: indikator `01 / 04` (14), label `RTSQ • BATAM` (14),
`WAKTU INDONESIA BARAT` (15), `AKTIF • …` (15), `BERIKUTNYA` (15), `WIB` (14),
`SANTRI` (12), `INFO` (22), meta slide (21), tempat acara (19).

Dampak: dari jarak 3 meter di TV 1080p, teks 12–15 px praktis tidak terbaca —
bertentangan dengan tujuan utama layar informasi.

### 3.2 Safe area vertikal belum 3%

Blueprint §5.1: safe area **3%** (≈57 px horizontal, **32 px vertikal**).

- Horizontal: padding 56 px → **sesuai** (≈2,9%).
- Vertikal: jam mulai ≈12–13 px dari atas; teks ticker berakhir ≈25 px dari bawah
  → **kurang dari 32 px**. Informasi penting berada di zona tepi.

### 3.3 Golden 1280×720 belum ada

Blueprint Fase 0 mewajibkan golden **1920×1080 dan 1280×720**. Yang ada hanya dua
golden 1920×1080 (`tampilan utama`, `slide jadwal`).

### 3.4 Ticker belum sesuai aturan

| Aturan §6.5 | Aktual |
|---|---|
| Daftar kalimat + `startAt`/`endAt` | Satu string tetap (`mockTicker`) |
| Kecepatan default 60 px/detik, bisa diatur | **72 px/detik hardcode** |
| Berhenti saat mode sholat/darurat | Belum ada (mode belum ada) |
| 30 fps | Mengikuti vsync (60 fps) |

### 3.5 Slideshow belum lengkap

- Jenis item Blueprint: pengumuman, prestasi, foto/poster, **video**, jadwal.
  Enum aktual: `announcement, achievement, schedule, photo` — **tanpa video**.
- Slide foto masih berupa panel placeholder berikon, belum merender gambar nyata.
- Transisi fade **420 ms**; Blueprint 300–400 ms (minor).
- Aturan playlist (`pinned`, `order`, `priority`, rentang tanggal, preload,
  fallback media rusak) belum ada — memang Fase 2b, tetapi berarti slideshow
  belum "sesuai" §6.4.

### 3.6 Jam, tanggal, dan Hijriah masih statis

- Jam memakai `DateTime.now()` perangkat, **bukan** `now().toUtc() + 7 jam`
  dengan koreksi header `Date` (§6.1).
- Tanggal Hijriah **hardcode** `24 Jumadil Awal 1448 H` di `format.dart:40`.
  Jika aplikasi menyala tanggal lain, tanggal Hijriah salah.
- Belum ada paket `hijri`, offset per bulan, atau pergantian saat Maghrib (§6.3).

### 3.7 Penyimpangan kecil lain

| Item | Blueprint | Aktual |
|---|---|---|
| `minSdk` | 23 | 24 (tidak berdampak untuk Android TV 14) |
| Logo YKCA | tinggi 72–88 px | **62 px** |
| Warna latar utama | `#0B1714` | `#07110E` (lebih gelap; `bgTop` tetap `#0B1714`) |
| Inisialisasi Supabase | harus tahan offline | `await Supabase.initialize(...)` tanpa `try/catch` di `main.dart` |
| Lokasi klien Supabase | `data/` (§10) | `core/supabase_client.dart` |
| Struktur folder | `admin/`, `tools/`, `assets/prayer/`, `assets/mock/`, `AGENTS.md` | Belum ada |
| Path Storage | `contents/{id}/…`, `screenshots/{id}/…` | Policy hanya membatasi bucket, belum prefix path |
| Penandatanganan APK | keystore rilis terpisah | `android/key.properties` dibaca `build.gradle.kts`; tanpa berkas itu build rilis jatuh ke debug key (contoh di `android/key.properties.example`) |

Catatan: `minSdk 24` dan latar `#07110E` bisa dianggap keputusan sadar, bukan
cacat. Tetapi tipografi dan safe area berdampak langsung ke keterbacaan.

---

## 4. Yang belum ada — sesuai fase, bukan cacat Fase 0

Semua ini memang belum dijadwalkan sampai fase berikutnya:

- **Fase 0:** system image Android TV, AVD 1080p, menjalankan di emulator/TV.
- **Fase 0.5:** ADB wireless, data perangkat, `docs/tv-aqua.md`,
  `tools/provision_tv.ps1`, uji 2 jam.
- **Fase 1:** `TimeService`, myquran/Kemenag + cache tahunan, fallback `adhan`,
  Hijriah + offset, unit test rollover/Jumat/offline.
- **Fase 2a:** anonymous sign-in, registrasi perangkat, layar pairing + QR,
  heartbeat, log, realtime/polling, snapshot atomik, unduh media + checksum,
  kuota 500 MB.
- **Fase 2b:** mesin playlist, prioritas, state machine, darurat, idle,
  perintah jarak jauh.
- **Fase 3:** panel admin web, Cloudflare Pages, `tv.rtsq.id`.
- **Fase 4:** watchdog, restart malam 03:00, PIN keluar, uji 7 hari.
- **Fase 5:** adzan, Ramadhan, multi-TV, statistik.

---

## 5. Kesesuaian backend dengan §7

| Bagian §7 | Status |
|---|---|
| 7.0 Enum | ✅ semua |
| 7.1 `profiles` | ✅ |
| 7.2 `admin_invites` | ✅ |
| 7.3 `devices` | ✅ + `register_device` |
| 7.4 `settings` | ✅ |
| 7.5 `contents` | ✅ |
| 7.6 `ticker` | ✅ |
| 7.7 `commands` | ✅ |
| 7.8 `logs` | ✅ |
| 7.9 `audit_log` | ✅ + trigger audit |
| 7.10 RPC | ✅ 7 RPC wajib + 3 pembantu |
| 7.11 RLS | ✅ per tabel |
| 7.12 Storage | ✅ bucket privat + policy; prefix path belum |
| 7.13 Realtime | ✅ 4 tabel |
| 7.14 Indeks | ✅ + indeks tambahan |
| 7.15 Bootstrap admin | ✅ didokumentasikan |
| `org_id` multi-lembaga | ⚪ ditunda (sesuai catatan blueprint) |

**Belum dijalankan:** migrasi belum dieksekusi ke proyek
`qrjamxhbfnemfinqbhfh`. Aplikasi juga baru **menginisialisasi** klien Supabase;
belum ada auth anonim, pairing, atau pembacaan konten.

---

## 6. Rekomendasi prioritas

### P0 — sebelum menyebut Fase 0 selesai

1. **Jalankan migrasi** 0001→0008 di SQL Editor, aktifkan Anonymous Sign-in.
2. **Golden 1280×720** (satu tes tambahan; kanvas sudah diskalakan).
3. **Naikkan tipografi** ke spesifikasi/floor 24 px — perlu penyesuaian tinggi
   header atau pengurangan elemen.
4. **Putuskan safe area vertikal**: 32 px (sesuai blueprint) atau sadar memakai
   ~13 px.
5. **Bungkus `Supabase.initialize` dengan `try/catch`** agar TV tidak layar
   hitam saat konfigurasi/offline bermasalah.
6. **Hijriah dinamis** (minimal dari paket `hijri`) supaya tidak salah tanggal.

### P1 — Fase 1

TimeService UTC+7 + koreksi `Date`, jadwal myquran + cache, `adhan` fallback,
jadwal myquran + cache, `adhan` fallback,
dan unit test rollover/Jumat/offline.

### P2 — Fase 2a

Auth anonim, `register_device`, layar pairing + QR, heartbeat/log, snapshot,
media cache, realtime + polling.

### P3 — seterusnya

Fase 2b → 3 → 4 sesuai roadmap.

---

## 7. Keputusan yang diminta

1. **Tipografi:** naikkan ke spesifikasi (jam 104+, label 24+, countdown 28+,
   isi 34+) dengan konsekuensi tata letak berubah, atau pertahankan tampilan
   sekarang dan catat sebagai penyimpangan resmi?
2. **Safe area:** terapkan 32 px vertikal (sesuai blueprint) atau tetap?
3. **Urutan kerja:** rapikan P0 dulu, atau langsung Fase 1 (waktu & jadwal)?
4. **Migrasi:** Bapak tempel manual di SQL Editor, atau saya bantu lewat CLI
   (butuh `supabase login` + password database)?

Rekomendasi saya: **selesaikan P0 tipografi + safe area + 720p + migrasi dulu**,
karena semua fitur Fase 1–4 akan memakai kerangka visual dan skema ini.

---

## 8. Tindak lanjut P0 (5 November 2026)

| Item P0 | Status | Bukti |
|---|---|---|
| Tipografi sesuai §5.3 + floor 24 px | ✅ selesai | Ukuran aktif: 24/28/30/32/34/40/56/58/104 px; dijaga `test/typography_test.dart`. |
| Safe area 3% | ✅ selesai | Padding horizontal 57 px, atas 32 px. |
| Golden 1280×720 | ✅ selesai | `test/goldens/tv_shell_1280x720.png`; tanpa overflow. |
| `Supabase.initialize` tahan gagal | ✅ selesai | `try/catch` + timeout 8 detik di `main.dart`. |
| Hijriah dinamis | ✅ selesai | `lib/core/hijri.dart` + `hijri 3.0.1`, rollover Maghrib, offset admin; 3 unit test. |
| Zona layar | ✅ disesuaikan | Header 180 / konten 616 / sholat 184 / ticker 100 = 1080. |
| Ticker 60 px/detik | ✅ selesai | Kecepatan diturunkan dari 72 → 60 px/detik. |
| Fade 300–400 ms | ✅ selesai | 420 → 380 ms. |
| Migrasi Supabase dijalankan | ✅ 5 Nov 2026 | 160 statement sukses di SQL Editor (“Success. No rows returned”); REST `settings`/`contents`/`ticker`/`devices` mengembalikan 200. |
| Anonymous Sign-ins | ✅ selesai | API `POST /auth/v1/signup` → 200, `is_anonymous: true` (verifikasi 6 Nov 2026). |
| Uji perangkat TV nyata | ⏳ belum | Menunggu ADB / pemasangan manual. |

Catatan: keputusan desain yang tetap dipertahankan — `minSdk 24` (tidak
berdampak pada Android TV 14), latar `#07110E`, dan lokasi klien Supabase di
`core/` — dicatat sebagai penyimpangan sadar, bukan cacat.

## 9. Tindak lanjut Fase 1 (6 November 2026)

| Item Fase 1 | Status | Bukti |
|---|---|---|
| `TimeService` UTC+7 + koreksi header Date | ✅ selesai | `lib/core/time_service.dart`, timeout 8 detik, fallback jam perangkat. |
| Jadwal myquran/Kemenag `0506` Batam | ✅ selesai | `lib/features/prayer/prayer_service.dart`, sumber utama. |
| Aset jadwal offline 2026 | ✅ selesai | `assets/prayer/2026.json` (12 bulan, 365+ hari). |
| Fallback `adhan` | ✅ selesai | Subuh 20°, Isya 18°, ihtiyati 2 menit (parameter Kemenag). |
| Verifikasi 3 bulan vs Kemenag | ✅ selesai | `docs/verifikasi-jadwal.md` (Nov–Des 2026, Jan 2027). |
| Hitung mundur, highlight aktif/berikutnya | ✅ selesai | `PrayerService.activePrayerIndex()`, `nextPrayerIndex()`. |
| Label Jumat pada Dzuhur | ✅ selesai | `prayer_strip.dart` (isFriday → 'JUMAT'). |
| Hijriah dinamis + Maghrib rollover + offset | ✅ selesai | `lib/core/hijri.dart`, `formatHijri()` dipakai di `tv_shell.dart`. |
| (v2.2) Iqamah/ihtiyati dihapus (TV lobi, bukan layar masjid) | ✅ selesai | `PrayerService` tidak lagi punya `iqamahMinutes()`; pengaturan di SQL/admin dihapus. |
| Unit test rollover/Jumat/Hijriah/tipografi | ✅ selesai | `test/mock_data_test.dart`, `test/hijri_test.dart`, `test/typography_test.dart`. |
| Aplikasi TV terhubung ke Supabase | ✅ selesai (Fase 2a) | Auth anonim, pairing, heartbeat, snapshot — lihat `docs/Fase 2a - Laporan.md`. |

Fase 1 dinilai **selesai** untuk logika waktu & jadwal sholat. Sisa pekerjaan
adalah operasional (Fase 0.5 uji perangkat) dan fitur Fase 2b/3, bukan
perubahan logika jadwal.

Fase 0 dinilai **selesai untuk bagian visual**; sisa pekerjaan adalah operasional
(migrasi + uji perangkat), bukan perubahan tata letak.

## 10. Tindak lanjut Fase 0.5 & 2a (6 November 2026)

### 10.1 Fase 0.5 — uji perangkat

| Item | Status | Bukti |
|---|---|---|
| AVD Google TV 34 dibuat | ✅ selesai | `google_tv_34`, 1920×1080, density 320 |
| APK terpasang & berjalan | ✅ selesai | `adb install` sukses; `id.rtsq.tv/.MainActivity` fullscreen |
| Dokumentasi uji perangkat | ✅ selesai | `docs/tv-aqua.md` |
| Skrip provisioning ADB | ✅ selesai | `tools/provision_tv.ps1` |
| Uji TV AQUA fisik | ⏳ belum | Menunggu ADB jaringan di TV asli |
| Uji 7 hari | ⏳ belum | Fase 4 |

### 10.2 Fase 2a — Supabase & sinkronisasi

| Item | Status | Bukti |
|---|---|---|
| Auth anonim TV | ✅ selesai | `TvRepository.ensureSession()` |
| `devices` + `register_device` | ✅ selesai | Kode 6 digit nyata dibuat di emulator |
| Layar pairing + QR | ✅ selesai | `docs/preview/fase2a-pairing.png` |
| Heartbeat 60 detik | ✅ selesai | `TvRepository.heartbeat()` |
| Polling 5 detik saat pending | ✅ selesai | `TvBootstrap._scheduleNext()` |
| Snapshot atomik | ✅ selesai | `snapshot_store.dart` (tmp → rename) |
| Konten & ticker dari Supabase | ✅ selesai | `tv_snapshot.dart`, `TvShell(snapshot:)` |
| Signed URL media | ✅ selesai | `_resolveMediaUrls()` |
| Koreksi jam dari `server_time` | ✅ selesai | `TimeService.applyServerTime()` |
| Mode offline + snapshot terakhir | ✅ selesai | `OfflineChip` |
| Realtime | ⏳ belum | Polling 60 detik dipakai lebih dulu |
| Cache media + kuota 500 MB | ⏳ belum | Fase 2b |
| Perintah jarak jauh & log | ⏳ belum | Fase 2b |
| Halaman `/pair` di admin | ⏳ belum | Fase 3 |

Fase 2a dinilai **selesai untuk jalur data TV**: perangkat dapat mendaftar,
menampilkan kode, disetujui (manual/SQL), lalu memuat konten. Sisa pekerjaan
adalah panel admin untuk menyetujui pairing dan fitur media/playlist Fase 2b.
