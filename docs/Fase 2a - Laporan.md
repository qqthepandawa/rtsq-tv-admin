# Laporan Fase 2a — Supabase & Sinkronisasi

Status: **kode sisi TV selesai dan berjalan di emulator; panel admin (Fase 3)
belum ada, jadi persetujuan pairing masih manual lewat SQL.**

Tanggal: 6 November 2026

## 1. Yang sudah jadi

### 1.1 Auth & perangkat

| Item | Status | Berkas |
|---|---|---|
| Sign-in anonim otomatis | ✅ | `lib/data/tv_repository.dart` |
| Registrasi perangkat (`register_device`) | ✅ | `TvRepository.registerDevice()` |
| Baca status perangkat (`pending/paired/revoked`) | ✅ | `TvRepository.fetchDevice()` |
| Simpan `state.json` atomik | ✅ | `lib/data/device_store.dart`, `device_state.dart` |
| Kode pairing kedaluwarsa → minta kode baru | ✅ | `lib/app/tv_bootstrap.dart` |

### 1.2 Layar pairing

| Item | Status | Berkas |
|---|---|---|
| Kode 6 digit besar | ✅ | `lib/features/pairing/pairing_screen.dart` |
| QR ke `https://tv.rtsq.id/pair?code=…` | ✅ | `package:qr_flutter` |
| Langkah 1–2–3 untuk admin | ✅ | `pairing_screen.dart` |
| Status koneksi server | ✅ | `pairing_screen.dart` |
| Layar khusus perangkat dicabut | ✅ | `pairing_screen.dart` (`revoked`) |
| Splash saat belum ada snapshot | ✅ | `lib/app/tv_bootstrap.dart` |

### 1.3 Sinkronisasi konten

| Item | Status | Berkas |
|---|---|---|
| `device_heartbeat()` tiap 60 detik | ✅ | `TvRepository.heartbeat()` |
| Polling 5 detik saat menunggu pairing | ✅ | `TvBootstrap._scheduleNext()` |
| Unduh `settings`, `contents`, `ticker` | ✅ | `TvRepository.downloadSnapshot()` |
| Snapshot atomik `snapshot.json` | ✅ | `lib/data/snapshot_store.dart` |
| Lewati unduhan bila versi tidak berubah | ✅ | perbandingan `settings_version` + `updated_at` |
| Pemetaan konten → slide TV | ✅ | `lib/data/tv_snapshot.dart` |
| Ticker mengikuti jendela `start_at`/`end_at` | ✅ | `TvTicker.isVisibleAt()` |
| Signed URL media gambar (7 hari) | ✅ | `TvRepository._resolveMediaUrls()` |
| Jam dikoreksi dari `server_time` heartbeat | ✅ | `TimeService.applyServerTime()` |
| Mode offline dengan snapshot terakhir | ✅ | `TvBootstrap` + `OfflineChip` |
| Buka app < 2 detik dari snapshot lokal | ✅ | snapshot dibaca sebelum jaringan |

### 1.4 Yang belum (masuk Fase 2b/3)

| Item | Alasan |
|---|---|
| Halaman `/pair?code=` di panel admin | Fase 3 (admin web) |
| Realtime Supabase | polling 60 detik sudah cukup untuk sekarang; realtime menyusul |
| Unduh media ke cache lokal + checksum | Fase 2b (saat video/playlist) |
| Kuota cache 500 MB + LRU | Fase 2b |
| Eksekusi `claim_commands`/`complete_command` | Fase 2b (perintah jarak jauh) |
| Kirim `logs` ke Supabase | Fase 2b |
| Terapkan `ihtiyati`/`iqamah` dari settings ke `PrayerService` | Fase 2b |
| Perangkat `revoked` bisa daftar ulang | RPC `register_device` saat ini menolak; perlu keputusan admin |

## 2. Bukti uji emulator

APK release 47,6 MB dipasang di AVD `google_tv_34` (Android 34, Google TV,
1920×1080).

| Uji | Hasil |
|---|---|
| Sign-in anonim | ✅ sesi dibuat otomatis |
| `register_device` | ✅ kode 6 digit dibuat Supabase |
| Kode tampil di TV | ✅ `938 000` |
| QR dirender | ✅ isi `tv.rtsq.id/pair?code=938000` |
| Status server | ✅ “Terhubung ke server RTSQ.” |
| Orientasi | ✅ tangkapan 1920×1080 landscape |
| Teks bergaris bawah | ✅ diperbaiki lewat `DefaultTextStyle` di `TvCanvas` |

Tangkapan layar: `docs/preview/fase2a-pairing.png`.

Logcat tidak menunjukkan `MissingPluginException` maupun kegagalan
`Sinkronisasi perangkat gagal`.

## 3. Verifikasi otomatis

```powershell
cd "C:\RTSQ TV\rtsq_tv"
flutter analyze   # No issues found
flutter test      # 18 tes lulus
flutter build apk --release
```

Tes baru:

- `test/snapshot_test.dart` — pemetaan konten ke slide, meta prestasi, jendela
  ticker, durasi slide, round-trip JSON, `DeviceState`.
- `test/snapshot_render_test.dart` — snapshot dari Supabase menggantikan data
  mock di layar TV, tanpa overflow.

## 4. Cara menyelesaikan pairing sebelum admin web ada

Panel admin belum tersedia, jadi persetujuan pairing dilakukan manual di
**Supabase → SQL Editor**:

```sql
-- Lihat perangkat yang menunggu
select id, name, status, pairing_code, pairing_expires_at, last_seen_at
  from public.devices
 order by created_at desc;

-- Setujui salah satu perangkat (ganti kode sesuai yang tampil di TV)
update public.devices
   set status = 'paired',
       pairing_code = null,
       pairing_expires_at = null,
       paired_at = now(),
       last_seen_at = now()
 where pairing_code = '938000'
   and status = 'pending';
```

TV memeriksa status setiap 5 detik. Setelah `paired`, TV langsung memanggil
`device_heartbeat()` dan mengunduh snapshot.

Untuk menguji pengumuman, tambahkan satu baris di SQL Editor:

```sql
insert into public.contents (type, title, body, status, active)
values ('announcement', 'Uji dari Supabase',
        'Konten ini muncul di TV dalam ±60 detik.', 'published', true);
```

## 5. Catatan keamanan

- APK hanya memuat **publishable key**; tidak ada `service_role`.
- Sebelum `paired`, RLS hanya mengizinkan perangkat membaca baris `devices`
  miliknya sendiri dan memanggil `register_device`.
- `settings`, `contents`, dan `ticker` baru bisa dibaca setelah
  `is_paired_device()` bernilai true.
- Storage `tv-media` privat; TV memakai signed URL 7 hari.
- Kode pairing 6 digit, berlaku 10 menit, dan dibuat ulang setelah kedaluwarsa.

## 6. Berkas baru

```text
lib/
  core/app_info.dart                 # versi app + URL admin
  app/tv_canvas.dart                 # kanvas 1920×1080 + DefaultTextStyle
  app/tv_bootstrap.dart              # orkestrasi boot/sync/pairing
  data/device_state.dart             # model state.json
  data/device_store.dart             # tulis state.json atomik
  data/tv_snapshot.dart              # model snapshot + pemetaan slide
  data/snapshot_store.dart           # tulis snapshot.json atomik
  data/tv_repository.dart            # auth, pairing, heartbeat, snapshot
  features/pairing/pairing_screen.dart
  features/status/offline_chip.dart
test/
  snapshot_test.dart
  snapshot_render_test.dart
```

Perubahan:

- `lib/main.dart` — `home` memakai `TvBootstrap`.
- `lib/app/tv_shell.dart` — menerima `snapshot`, memakai konten/ticker/durasi
  dari Supabase bila ada; fallback ke mock Fase 0.
- `lib/features/slideshow/slideshow_panel.dart` — mendukung gambar dari URL.
- `lib/core/time_service.dart` — `nowUtc` + `applyServerTime()`.
- `pubspec.yaml` — `qr_flutter`, `device_info_plus`.
