# Laporan Fitur Murottal RTSQ TV

Status: **selesai, terverifikasi di emulator Google TV, APK release siap pasang.** Admin web tidak di-build atau di-deploy pada tahap ini.

Tanggal: 9 November 2026

## 1. Ringkasan

Menambahkan menu tersembunyi murottal pada aplikasi TV (`rtsq_tv`):

- Dibuka dengan **menahan tombol OK selama 2 detik** di layar utama TV, tanpa PIN.
- Panel muncul tanpa langsung memutar audio; pemutaran dimulai setelah pengguna memilih surah atau menekan Putar.
- Sumber audio memakai **CDN gratis Islamic Network** (`cdn.islamic.network`), bukan storage Supabase, sehingga tidak menambah biaya.
- Hanya tersedia di layar TV yang sudah dipasangkan (`TvShell`), tidak di layar pairing.
- Membutuhkan koneksi internet saat memutar.

## 2. Kemampuan yang tersedia

| Kemampuan | Detail |
|---|---|
| Daftar surah | 114 surah, nama Indonesia + nama Arab, jumlah ayat, Makkiyah/Madaniyah |
| Qori | 17 qori unik (duplikat `-2` digabung), dipilih lewat grid 2 kolom |
| Sumber audio | Streaming MP3 per ayat dari CDN, dengan fallback bitrate sesuai ketersediaan qori (128/192/64/48/32 kbps) |
| Navigasi ayat | Sebelumnya / Berikutnya, lanjut otomatis ke ayat berikutnya |
| Basmalah | Diputar sebelum ayat 1 setiap surah, kecuali Al-Fatihah (basmalah adalah ayat pertamanya) dan At-Taubah |
| Pengulangan | Otomatis, Ayat 3x, Ayat 5x, Ayat tanpa batas, Surah tanpa batas |
| Kecepatan | 0.5x sampai 2.0x (preset 0.5 / 0.75 / 1 / 1.25 / 1.5 / 1.75 / 2) |
| Progres | Posisi dan durasi ayat ditampilkan di panel |
| Layar utama | Chip "Sedang diputar" (surah, ayat, kecepatan) di kanan atas saat panel ditutup |
| Latar belakang | Audio tetap berjalan setelah panel ditutup |
| Penyimpanan | Surah, ayat, qori, kecepatan, dan mode pengulangan terakhir dipulihkan saat panel dibuka lagi |
| Penanganan error | Pesan ramah saat audio gagal dimuat, timeout 12 detik per bitrate, lalu coba bitrate berikutnya |

Pemetaan nomor ayat memakai nomor global 1-6236, sehingga URL audio selalu tepat untuk setiap surah/ayat.

Audio basmalah memakai rekaman **Al-Fatihah ayat 1** dari qori yang sedang dipilih, jadi suaranya konsisten. Basmalah dimainkan sekali setiap kali masuk surah baru (termasuk saat mengulang surah), lalu otomatis berlanjut ke ayat 1. Tidak ada basmalah terpisah untuk **Al-Fatihah** dan **At-Taubah**. Saat basmalah berbunyi, chip dan header panel menampilkan "Bismillah".

## 3. Berkas yang dikerjakan

### Berkas baru

| Berkas | Isi |
|---|---|
| `rtsq_tv/lib/features/murottal/quran_data.dart` | Data 114 surah, offset ayat global, fungsi `globalAyahNumber` |
| `rtsq_tv/lib/features/murottal/qori_data.dart` | 17 qori, daftar bitrate, pembentuk URL audio |
| `rtsq_tv/lib/features/murottal/murottal_audio.dart` | Abstraksi pemutar audio + implementasi `just_audio` |
| `rtsq_tv/lib/features/murottal/murottal_controller.dart` | State pemutaran, pengulangan, kecepatan, persistensi, auto-next |
| `rtsq_tv/lib/features/murottal/murottal_store.dart` | Simpan/muat state JSON di `ApplicationSupportDirectory/murottal.json` |
| `rtsq_tv/lib/features/murottal/murottal_panel.dart` | Panel layar penuh, navigasi D-pad, daftar surah, kontrol, grid qori, chip now-playing |
| `rtsq_tv/test/support/fake_murottal.dart` | Pemutar dan penyimpanan palsu untuk tes |
| `rtsq_tv/test/murottal_test.dart` | Tes data, URL, auto-next, pengulangan, fallback bitrate, kecepatan, restore state |
| `rtsq_tv/test/murottal_panel_test.dart` | Tes gesture tahan OK, navigasi panel, pemutaran, golden 1920x1080 |
| `rtsq_tv/test/goldens/murottal_panel_1920x1080.png` | Golden panel murottal |

### Berkas yang diubah

| Berkas | Perubahan |
|---|---|
| `rtsq_tv/lib/app/tv_shell.dart` | Handler tahan OK, pembukaan/penutupan panel, chip now-playing, permintaan fokus remote |
| `rtsq_tv/lib/app/tv_bootstrap.dart` | Perbaikan kepemilikan fokus wrapper kiosk |
| `rtsq_tv/lib/data/tv_repository.dart` | Fallback heartbeat saat `current_content_id` sudah tidak ada |
| `rtsq_tv/pubspec.yaml`, `pubspec.lock` | Dependensi `just_audio` dan `audio_session` |

## 4. Bug yang ditemukan saat verifikasi dan diperbaiki

### 4.1 Tombol remote tidak sampai ke layar TV

`_KioskWrapper` memakai `autofocus: true` sehingga memegang fokus utama. Handler tombol di `TvShell` berada di node turunan, jadi tidak pernah menerima event. Akibatnya bukan hanya tahan OK yang mati, tetapi juga navigasi kiri/kanan slide yang diminta pada tahap sebelumnya.

Perbaikan:

- `tv_bootstrap.dart`: wrapper kiosk tidak lagi mengambil fokus utama; event BACK tetap menggelembung ke wrapper saat panel tertutup.
- `tv_shell.dart`: `TvShell` meminta fokus setelah frame pertama sebagai jaminan.

Hasil: tombol kiri/kanan kembali berpindah slide dan tahan OK 2 detik membuka panel.

### 4.2 TV tertahan "Mode offline" terus-menerus

Heartbeat mengirim `current_content_id` milik konten yang sudah dihapus di server. Server menolak dengan FK `23503`, sehingga sinkronisasi gagal setiap siklus dan TV tidak pernah kembali online.

Perbaikan: `device_heartbeat` dicoba ulang sekali tanpa `current_content_id` bila error tersebut muncul. Setelah APK baru dipasang, badge "Mode offline" hilang dan sinkronisasi berjalan kembali.

## 5. Verifikasi di emulator Google TV

Perangkat: `google_tv_34` (Android TV x86, 1920x1080, Android 14), APK release.

| Skenario | Hasil |
|---|---|
| Tahan OK 2 detik | Panel "Murottal RTSQ TV" terbuka |
| Daftar | 114 surah dan 17 qori tampil |
| Putar Al-Fatihah | Audio streaming berjalan; log MediaCodec `audio/mpeg`, AudioTrack `started` 44,1 kHz |
| Ayat berikutnya | Tombol Berikutnya bekerja; ayat juga lanjut otomatis saat selesai |
| Kecepatan | Berubah ke 1.25x dan berlaku saat diputar |
| Pengulangan | Berubah ke "Ayat 3x" dan tampil di kartu now-playing |
| Ganti qori | Berpindah ke Mahmud Khalil Al-Husary; audio dimuat ulang dan berjalan |
| Back | Panel tertutup, audio tetap berjalan, chip now-playing tampil |
| Buka panel lagi | State terakhir (surah, ayat, qori, kecepatan, pengulangan) pulih |
| Sinkronisasi | Badge offline hilang setelah perbaikan heartbeat |

## 6. Pengujian otomatis

| Pemeriksaan | Hasil |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 38 tes lulus |
| Golden panel | `test/goldens/murottal_panel_1920x1080.png` diperiksa visual, tanpa overflow/underline |

## 7. Artefak APK

| Item | Nilai |
|---|---|
| Lokasi | `C:\Users\user\Desktop\rtsq-tv-0.1.0-release.apk` |
| Ukuran | 57.469.020 byte (54,8 MB) |
| SHA-256 | `1fa14542c04f64ea592899d73a3cd63d753f81e5f87a43955779572fa2565b01` |

## 8. Catatan dan batasan

- Tidak ada perubahan skema database, tidak ada kunci rahasia baru, dan tidak ada perubahan pada RTSQ Mobile/Muttaqin.
- Tidak ada build atau deploy admin web pada tahap ini, sesuai instruksi.
- Streaming bergantung pada internet dan ketersediaan CDN gratis; tidak ada unduhan audio ke perangkat.
- Panel hanya bisa dibuka dari layar TV utama yang sudah dipasangkan.
- Folder scratch generator data surah (`.tmp_quran`) sudah dihapus.
