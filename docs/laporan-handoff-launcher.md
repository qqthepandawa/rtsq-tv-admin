# Laporan — Launcher Mode + Layout 16:9 (RTSQ TV)

Tanggal: 2026-11-11 (diperbarui)
Status: **SELESAI & terverifikasi di TV.** RTSQ TV = beranda; tombol HOME,
dock aplikasi, ikon merek, dan **panel pengaturan cepat (sidebar)** berfungsi.
Pratinjau admin sudah disamakan dengan tata letak aplikasi. Video kini berjalan
sampai habis (tanpa batas 120 detik) dengan kontrol suara bawaan **mati**, dan
murottal **lanjut otomatis ke surah berikutnya**.

---

## 1. Konteks Tujuan

1. Mengganti home launcher Google TV (penuh film/rekomendasi) agar RTSQ TV
   menjadi beranda, dengan akses cepat YouTube dan YouTube Music.
2. Mengubah layout layar: area konten dari rasio ~3:1 menjadi **16:9
   (crop-to-fill)**, jadwal sholat **vertikal di pojok kiri** (atas→bawah),
   header dirampingkan.
3. (Tambahan) Ikon YouTube/YouTube Music di dock memakai logo asli.

## 2. Hasil Akhir (terverifikasi di perangkat)

| Uji | Perintah | Hasil |
|---|---|---|
| HOME resolve | `cmd package resolve-activity -c android.intent.category.HOME` | `id.rtsq.tv/.MainActivity` |
| Role HOME | `cmd role get-role-holders android.app.role.HOME` | `id.rtsq.tv` |
| Tekan HOME | `input keyevent KEYCODE_HOME` | tetap `id.rtsq.tv/.MainActivity` |
| Dock → YouTube | bawah + OK | `com.google.android.youtube.tv` terbuka |
| Dock → YouTube Music | bawah + → + OK | diluncurkan (TV meneruskan ke shell YouTube) |
| Dock → Pengaturan | bawah + → → + OK | `com.android.tv.settings/.MainSettings` |
| HOME dari app lain | `input keyevent KEYCODE_HOME` | kembali `id.rtsq.tv/.MainActivity` |
| BACK singkat | `input keyevent KEYCODE_BACK` | tidak keluar app (tetap RTSQ) |
| Tahan nyala ulang | reboot TV | RTSQ tampil otomatis (BootReceiver) + HOME ke RTSQ |

Build: `flutter analyze` bersih; `flutter test` **44/44 lolos**.

## 2A. Panel Pengaturan Cepat (pengganti sidebar Google TV)

Sidebar gerigi milik launcher Google TV (`launcherx`) ikut hilang saat RTSQ
dijadikan beranda. Karena itu panel dibuat **di dalam RTSQ**, meniru panel
quick-settings Google TV: kartu ikon + label, sorotan teal, dan baris
**"Pengaturan Lengkap"** berwarna emas.

Penting soal tombol gerigi di remote ini:

> **Tombol GEAR tidak dapat dipakai aplikasi mana pun di TV ini.** Remote AQUA
> mengirim pemindaian HID yang oleh firmware dipetakan ke `KEY_UNKNOWN`
> (Linux `keycode 240`). Android membuangnya sebelum sampai ke aplikasi —
> terbukti: `getevent` merekam 46 event `linuxKey=240` saat GEAR ditekan
> berulang kali, sementara `dispatchKeyEvent` aplikasi **tidak menerima satu
> pun** event (`keyCode` 20/22/23 untuk DOWN/RIGHT/OK tetap masuk normal).

Karena itu panel dibuka lewat **tombol ▲ (atas)** yang sebelumnya tidak
dipakai di layar utama. Handler native untuk `KEYCODE_SETTINGS` / `MENU` /
`INFO` / `HELP` tetap dipertahankan agar otomatis bekerja bila kelak ada
remote yang meneruskannya.

| Uji | Hasil |
|---|---|
| Tekan ▲ di beranda (injeksi `KEYCODE_DPAD_UP`) | panel meluncur dari kanan — screenshot `docs/screenshots/tv-panel.png` |
| ▲/▼ | memilih baris |
| OK | membuka layar Pengaturan Android |
| BACK / ◀ | menutup panel |
| Uji widget | `test/quick_settings_test.dart` (kanal native + tombol ▲) |
| Golden | `test/goldens/quick_settings_1920x1080.png` |

Baris panel dan action Settings yang sudah diverifikasi dapat dibuka di TV:
`WIFI_SETTINGS` → `NetworkActivity`, `DISPLAY_SETTINGS` → `PictureActivity`,
`ACCESSIBILITY_SETTINGS`, `DEVICE_INFO_SETTINGS` → `AboutActivity`, dan
`SETTINGS` → `MainSettings`.

## 2B. Tombol Remote AQUA: Fungsi & Status

Diuji langsung di TV (AQUA MatrixTV CE, Android 14). "Sampai app" berarti
event benar-benar diterima `MainActivity.dispatchKeyEvent`.

| Tombol | Fungsi di RTSQ TV | Sampai app? |
|---|---|---|
| ▲ (atas) | **Buka/tutup panel pengaturan cepat** | ✅ `keyCode 19` |
| ▼ (bawah) | Buka dock aplikasi (YouTube / YouTube Music / Pengaturan) | ✅ `keyCode 20` |
| ◀ / ▶ | Ganti slide konten; saat dock terbuka = pindah ikon | ✅ `21` / `22` |
| OK | Jalankan ikon dock; **tahan 2 detik** = panel murottal | ✅ `keyCode 23` |
| BACK singkat | Tidak keluar aplikasi (tetap di beranda) | ✅ `4` |
| BACK tahan 5 detik | Dialog PIN → `2468` → Pengaturan Android | ✅ |
| HOME | Tetap di RTSQ (RTSQ adalah HOME) | ✅ `3` |
| VOLUME + / − | Volume TV (ditangani sistem) | ✅ (sistem) |
| **GEAR / gerigi** | Tidak ada — ditelan firmware TV | ❌ `KEY_UNKNOWN (240)` |
| 3 tombol di atas GEAR | Tidak ada (semua `KEY_UNKNOWN`) | ❌ |
| Tombol AUDIO | Tidak ada (semua `KEY_UNKNOWN`) | ❌ |

Catatan: tombol HOME/GEAR/AUDIO yang tidak berfungsi sebelum perubahan
launcher pun tetap tidak berfungsi — bukan regresi dari RTSQ. Tombol GEAR
baru terasa "hilang" karena sidebar Google TV yang dulu ia buka sudah tidak
aktif.

## 2C. Pemutaran Video & Murottal

**Video tanpa batas waktu.** Sebelumnya video dipotong di 120 detik. Sekarang
video diputar **sampai habis** (tidak di-loop), lalu slideshow lanjut otomatis
lewat `onMediaComplete`. Jaring pengaman: bila berkas video gagal dimuat, slide
tetap lanjut setelah 8 detik agar antrean tidak macet.

**Kontrol suara video (bawaan mati).** Preferensi runtime `AppPrefs.videoSound`
(bawaan `false`) mengatur volume pemutar video (`1` nyala / `0` mati). Baris
**"Suara Video"** ditambahkan di panel pengaturan cepat (tepat sebelum
"Pengaturan Lengkap"); ▲/▼ memilih, **OK menyalakan/mematikan** tanpa menutup
panel, dan subjudulnya berubah (Mati ⇄ Nyala). Bawaan mati supaya murottal
tetap terdengar sambil video berjalan.

**Murottal lanjut ke surah berikutnya.** Mode **"Lanjut otomatis"**
(`MurottalRepeat.off`) kini berpindah ke **surah berikutnya** (mulai ayat 1)
setelah ayat terakhir sebuah surah, bukan berhenti. Mode **"Ulangi surah ∞"**
tetap mengulang surah yang sama, dan pada surah terakhir (114) pemutaran
berhenti seperti sebelumnya.

**Bismillah sebelum ayat 1 (kecuali Al-Fatihah & At-Taubah).** Setiap surah
dibuka dengan audio basmalah lebih dulu, lalu otomatis memuat **ayat 1**.
Aturannya ada di `surahNeedsBasmalah(n) => n != 1 && n != 9`:
Al-Fatihah tidak perlu basmalah tambahan karena basmalah adalah ayat
pertamanya, dan At-Taubah memang tidak dibuka basmalah. Audio basmalah memakai
**Al-Fatihah ayat 1 dari qori yang sama** (`basmalahGlobalAyah = 1`) sehingga
tidak menambah aset dan suaranya konsisten. Basmalah berlaku saat memilih
surah, saat **lanjut otomatis** ke surah berikutnya, dan saat **"Ulangi surah
∞"**. Selama basmalah berbunyi, panel dan chip menampilkan **"Bismillah"**
(`docs/screenshots/murottal-bismillah.png`), lalu berganti menjadi
"ayat 1" setelah basmalah selesai. At-Taubah langsung menampilkan "ayat 1"
(`docs/screenshots/murottal-taubah.png`).

**Verifikasi di emulator (12 Nov 2026).** AVD **Google TV** API 34 di mesin
ini hanya tersedia sebagai image **x86 32-bit**, sedangkan Flutter 3.44 tidak
lagi menyertakan engine x86 (APK hanya berisi `libflutter.so` x86_64) sehingga
aplikasi tidak bisa start di AVD tersebut (`MissingLibraryException`). Karena
itu uji perilaku dilakukan di AVD **Pixel 6 (x86_64)** memakai entrypoint uji
`lib/dev/murottal_check.dart` yang menampilkan `MurottalPanel` dan audio asli
(tanpa perlu pairing Supabase). Hasil:

| Uji | Hasil |
|---|---|
| Al-Baqarah (2) | `bismillah=true`, durasi 6,1 dtk → lanjut ayat 1 |
| At-Taubah (9) | `bismillah=false`, langsung ayat 1 |
| Al-Fatihah (1) | `bismillah=false`, langsung ayat 1 |
| Al-Ikhlas ayat 4 habis | lanjut Al-Falaq dan memutar basmalahnya lebih dulu |

Entrypoint `lib/dev/murottal_check.dart` hanya alat bantu manual dan tidak
dipakai pada build produksi (`flutter build apk` tetap memakai `lib/main.dart`).

**Batas ukuran unggahan video.** Panel admin tidak lagi memblokir ukuran
(sebelumnya 60 MB). Batas sebenarnya ada di **Supabase Storage**: `413 Payload
too large` muncul bila berkas melebihi *Global file size limit* project. Sesuai
dokumentasi Supabase, **paket Free maksimal 50 MB per berkas** (tidak bisa
dinaikkan); **paket Pro** bisa sampai 500 GB. Jadi video 57 MB tidak akan
berhasil pada paket Free. Untuk menerima berkas lebih besar:

1. Naikkan **Global file size limit** di Dashboard Supabase →
   Storage → Settings (butuh paket Pro).
2. Jalankan `supabase/migrations/0012_storage_unlimited.sql` agar bucket
   `tv-media` tidak menambah batasnya sendiri.
3. Tidak perlu ubah kode; panel admin sudah meneruskan berkas apa adanya dan
   hanya menampilkan pesan yang jelas bila server menolak.

**Verifikasi di TV (v0.3.0, build ulang).** Panel dibuka dengan ▲ menampilkan
baris **Suara Video** (`docs/screenshots/tv-panel-2.png`); menekan OK mengubah
subjudul menjadi "Nyala · OK untuk mematikan" tanpa menutup panel
(`docs/screenshots/tv-panel-3.png`). Preferensi bersifat runtime: kembali ke
**Mati** setiap aplikasi dimulai.

## 3. Penyelesaian Blocker HOME (Fase sebelumnya)

Kandidat HOME saat itu:
`launcherx` (priority 2) > `setupwraith/RecoveryActivity` (1) >
`id.rtsq.tv` (0) > `tv.settings/FallbackHome` (-1000). Firmware Aqua selalu
memilih `launcherx`, sehingga menyetel role HOME saja tidak cukup.

Langkah yang berhasil (rollback: `pm enable <pkg>`):
```
adb shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
adb shell pm disable-user --user 0 com.google.android.tungsten.setupwraith
```
Setelah keduanya nonaktif, HOME jatuh ke `id.rtsq.tv/.MainActivity`. Perubahan
ini **bertahan setelah reboot** (sudah diuji). `setupwraith` dinonaktifkan
karena ia otomatis mengambil alih sebagai HOME saat launcher hilang (menampilkan
`RecoveryActivity`).

Catatan: `com.haier.launcher.haiermatrix` **bukan** kandidat HOME (tidak perlu
disentuh).

## 4. Akar Masalah Tombol Dock ("OK tidak bereaksi")

Saat dock dibuka, menekan OK tidak menjalankan apa pun. Penyebabnya bukan
pemetaan tombol, melainkan **package visibility Android 11+**: manifest hanya
mendaftarkan `<queries>` untuk `PROCESS_TEXT`, sehingga
`getLaunchIntentForPackage("com.google.android.youtube.tv")` mengembalikan
**null** (bukti: `dumpsys package id.rtsq.tv` → `queries via package name:`
kosong). Karena itu pula `adb shell monkey -p ...` berhasil, tetapi tombol
dalam app gagal.

Perbaikan:
- `AndroidManifest.xml`: tambah `<package>` untuk
  `com.google.android.youtube.tv`, `com.google.android.youtube.tvmusic`,
  `com.android.tv.settings`.
- `MainActivity.kt`: `launchPackage()` tahan-gagal — bila
  `getLaunchIntentForPackage` null, ditelusuri activity `MAIN +
  LEANBACK_LAUNCHER` / `LAUNCHER` secara eksplisit; paket
  `com.android.tv.settings` memakai `Settings.ACTION_SETTINGS`.

> Penting untuk pengembangan berikutnya: setiap app baru yang ditambahkan ke
> dock **wajib** didaftarkan di `<queries>`, jika tidak tombolnya akan diam.

## 5. Daftar Perubahan File

### Sudah ada sejak handoff sebelumnya (layout 16:9 + dock)
- `lib/app/tv_shell.dart` — layout HeaderBar 140px, `Row[PrayerPanel 420,
  konten 16:9]`, TickerBar; penanganan tombol dock.
- `lib/features/header/header_bar.dart` — header ramping.
- `lib/features/prayer/prayer_panel.dart` — **baru**: jam besar + daftar
  sholat vertikal (SUBUH→ISYA) + countdown.
- `lib/features/prayer/prayer_strip.dart` — **dihapus**.
- `lib/features/slideshow/slideshow_panel.dart` — `AspectRatio 16/9`, media
  crop-to-fill.
- `lib/core/app_launcher.dart` — MethodChannel `id.rtsq.tv/apps`.

### Perubahan sesi ini
- `android/app/src/main/AndroidManifest.xml` — **`<queries>`** (lihat §4).
- `android/app/src/main/kotlin/id/rtsq/tv/MainActivity.kt` — `launchPackage()`
  + `componentIntent()`.
- `lib/features/launcher/apps_dock.dart` — entri **Pengaturan**
  (`com.android.tv.settings`); `DockApp` kini memakai enum `DockIconKind` dan
  widget `DockAppIcon`.
- `lib/features/launcher/brand_icons.dart` — **baru**: logo YouTube
  (persegi merah membulat + segitiga putih) dan YouTube Music (lingkaran merah
  + segitiga putih) digambar vektor (`CustomPainter`), tajam di semua resolusi
  tanpa aset biner.
- `lib/app/tv_bootstrap.dart` — `_KioskWrapper` membungkus `Scaffold`
  transparan agar SnackBar kegagalan tampil.
- `lib/app/tv_shell.dart` — tombol BACK di layar utama dikembalikan
  `ignored` agar menggelembung ke `_KioskWrapper` (jalur keluar darurat
  berfungsi kembali).
- `pubspec.yaml` — versi **0.3.0+3**.
- `test/launcher_dock_test.dart` — **baru**: uji dock (bawah membuka, OK
  meluncurkan YouTube / YouTube Music / Pengaturan via kanal tiruan).
- `lib/features/launcher/quick_settings.dart` — **baru**: panel pengaturan
  cepat (kartu ikon, sorotan, baris "Pengaturan Lengkap").
- `android/app/src/main/kotlin/id/rtsq/tv/MainActivity.kt` — kanal
  `id.rtsq.tv/panel`, `dispatchKeyEvent()` untuk tombol gerigi/settings,
  method `settings` pada kanal `id.rtsq.tv/apps`, `openSettingsAction()`.
- `lib/core/app_launcher.dart` — `openSettings(action)`.
- `lib/app/tv_shell.dart` — state panel (`_settingsOpen`, `_settingsIndex`),
  navigasi ▲/▼/OK/BACK, tombol ▲ membuka panel.
- `test/quick_settings_test.dart` — **baru**: uji buka panel via kanal native
  dan via tombol ▲, lalu OK membuka `android.settings.SETTINGS`.
- `test/quick_settings_golden_test.dart` — **baru**: golden panel
  `test/goldens/quick_settings_1920x1080.png`.
- `lib/data/device_store.dart` + `lib/data/snapshot_store.dart` — penulisan
  `.tmp` unik + cadangan tulis langsung. Memperbaiki `PathNotFoundException`
  saat `rename` yang membuat TV menampilkan chip **"Mode offline"** padahal
  jaringan normal.
- `admin/lib/features/preview/tv_preview.dart` — **ditulis ulang** agar sama
  dengan app: latar gradien, header 140, panel sholat vertikal 420, konten
  16:9, ticker; parameter `fixedNow` untuk golden.
- `admin/test/tv_preview_golden_test.dart` + golden
  `admin/test/goldens/tv_preview_1920x1080.png` — **baru**.
- `admin/lib/features/content/content_editor_page.dart` — keterangan Media
  video: tanpa batas 120 detik + catatan kontrol suara (bawaan mati).
- `admin/lib/features/preview/preview_page.dart` — keterangan zona disamakan
  (header 140 · sholat 420 kiri · konten 16:9 · ticker 100).

### Perubahan sesi ini (video & murottal)
- `lib/core/app_prefs.dart` — **baru**: `AppPrefs.videoSound` (bawaan `false`).
- `lib/features/slideshow/slideshow_panel.dart` — hapus batas 120 detik; timer
  memakai durasi penuh; volume mengikuti `AppPrefs.videoSound`; timer gagal
  muat 8 detik.
- `lib/app/tv_shell.dart` — durasi slide video jadi jaring pengaman 1 jam;
  `_activateSetting()` menangani baris **Suara Video**.
- `lib/features/launcher/quick_settings.dart` — enum `QuickSettingKind` +
  baris **Suara Video** (subjudul/ikon mengikuti keadaan).
- `lib/features/murottal/murottal_controller.dart` — `_onCompleted()` dan
  `nextAyah()` maju ke surah berikutnya pada mode "Lanjut otomatis".
- `lib/features/murottal/murottal_controller.dart` — basmalah diputar sekali
  sebelum ayat 1 setiap surah baru (audio Al-Fatihah ayat 1 dari qori yang
  sama), lalu lanjut ke ayat 1. Dilewati untuk Al-Fatihah dan At-Taubah.
- `lib/features/murottal/quran_data.dart` — helper `surahNeedsBasmalah()` dan
  `basmalahGlobalAyah`.
- `lib/features/murottal/murottal_panel.dart` — chip/header menampilkan
  "Bismillah" selama audio basmalah berbunyi.
- `lib/dev/murottal_check.dart` — **baru**: entrypoint uji manual panel murottal
  + audio asli untuk emulator (tidak dipakai build produksi).
- `docs/screenshots/murottal-bismillah.png`,
  `docs/screenshots/murottal-taubah.png` — bukti uji emulator.
- `test/murottal_test.dart` — uji lanjut otomatis ke surah berikutnya, basmalah
  sebelum surah baru, serta pengecualian Al-Fatihah/At-Taubah.
- `test/goldens/quick_settings_1920x1080.png` — golden diperbarui.
- `admin/lib/data/admin_repository.dart` — hapus blokir 60 MB; terjemahkan
  `StorageException` 413 menjadi pesan batas Supabase yang jelas.
- `supabase/migrations/0012_storage_unlimited.sql` — **baru**: bucket
  `tv-media` tanpa batas sendiri (ikut Global file size limit project).
- `supabase/apply_all.sql`, `supabase/chunks/09.sql` — bucket `tv-media`
  memakai `file_size_limit = null`.

## 6. Kondisi TV & Cara Menyambung ADB

- Model **AQUA MatrixTV CE** (AQT56EU/deto), Android 14 (API 34), Google TV.
- **ADB networking tetap di `192.168.100.23:5555`** — alamat ini **tahan
  reboot** (berbeda dari Wireless debugging yang port-nya berubah tiap reboot).
  Ini jalur sambung utama sekarang; Wireless debugging/Settings tidak perlu
  dibuka lagi.
  ```
  adb connect 192.168.100.23:5555
  ```
- APK terpasang: **v0.3.0 (versionCode 3)**.
  `rtsq_tv/build/app/outputs/flutter-apk/app-release.apk` (55,4 MB).

## 7. Operasi di TV (untuk sesi berikutnya)

- **Panel pengaturan cepat**: tekan **▲ (atas)** → pilih dengan ▲/▼ → OK →
  BACK/◀ untuk menutup. (Tombol GEAR tidak bisa dipakai, lihat §2A.)
- **Dock aplikasi**: tekan tombol **bawah** di remote → kiri/kanan pilih →
  OK jalankan; isi: YouTube, YouTube Music, **Pengaturan**.
- **Keluar darurat**: **tahan BACK 5 detik** → dialog PIN → masukkan `2468`
  → Pengaturan Android terbuka. (PIN ada di `tv_bootstrap.dart` `_kioskPin`.)
- Tombol lain: kiri/kanan = ganti slide; OK tahan 2 detik = panel murottal.
- **Pratinjau admin**: buka halaman Preview di web admin
  (`https://main.rtsq-tv-admin.pages.dev`); kanvas 1920×1080 sudah mengikuti
  tata letak TV (16:9, panel sholat vertikal, header ramping).
- **Deploy admin web**: Cloudflare Pages proyek ini memakai **direct upload**
  (auto-build dari Git tidak berfungsi, lihat `docs/Fase 3 - Laporan.md` §4).
  `git push` **tidak** otomatis men-deploy. Setiap kali admin berubah:
  ```
  cd "C:\RTSQ TV\admin"
  flutter build web --release
  cd build\web
  npx wrangler pages deploy . --project-name rtsq-tv-admin --branch main --commit-dirty=true
  ```

### Diagnostik tombol (bila ada tombol "diam")
```
adb shell getevent -t          # lihat kode Linux mentah tiap tombol
adb logcat -s RTSQ_KEY:D       # lihat keyCode Android yang sampai ke app
```
Bila `getevent` mencatat event tetapi `RTSQ_KEY` kosong, tombol tersebut
ditelan firmware dan **tidak bisa** dipakai aplikasi (seperti GEAR).

### Rollback bila perlu
```
# kembalikan home Google TV
adb shell pm enable com.google.android.apps.tv.launcherx
adb shell pm enable com.google.android.tungsten.setupwraith
adb shell cmd package set-home-activity com.google.android.apps.tv.launcherx/.home.HomeActivity
```
Semua perubahan bisa dibalik lewat ADB; koneksi 5555 selalu tersedia.

## 8. Catatan Pengerjaan

- Jangan sentuh `supabase/service_role` key; anon key saja (lihat
  `project-security-constraints` memory / `supabase/README.md`).
- Konten rasio lama (3:1) diisi ulang manual lewat web admin; app sekarang
  crop-to-fill 16:9.
- Golden test di `test/goldens/`; setiap ubah layout wajib
  `flutter test --update-goldens` lalu `flutter test`. Golden admin ada di
  `admin/test/goldens/` (`flutter test --update-goldens` di folder `admin`).
- App apa pun yang ditambahkan ke dock wajib didaftarkan di `<queries>`
  (lihat §4).
- Tombol yang ditelan firmware TV (GEAR, AUDIO, 3 tombol di atas GEAR) tidak
  bisa diperbaiki dari sisi aplikasi; satu-satunya jalan adalah mengganti
  remote atau memetakan ulang di service menu TV (di luar cakupan).
