# Uji Perangkat — AQUA MatrixTV CE (Android TV 14)

Status: **emulator Google TV lulus; perangkat fisik belum diuji.**

Dokumen ini mencatat hasil uji di emulator dan menjadi checklist saat TV AQUA
asli sudah terhubung lewat ADB.

## 1. Perangkat target

| Item | Nilai |
|---|---|
| Merek / model | AQUA MatrixTV CE |
| Sistem | Android TV 14 |
| Build | `UKNV.260302.001` |
| applicationId | `id.rtsq.tv` |
| minSdk / targetSdk | 24 / 34 |
| Orientasi | Landscape (dikunci aplikasi + manifest) |
| Launcher | Leanback + HOME intent |

## 2. Emulator yang dipakai

| Item | Nilai |
|---|---|
| AVD | `google_tv_34` (dibuat manual) |
| System image | `system-images;android-34;google-tv;x86` |
| Resolusi | 1920×1080 |
| Density | 320 dpi |
| RAM | 2048 MB |
| Data partition | 4096 MB |
| Host | Windows, emulator 36.6.11.0 |

Pembuatan AVD lewat `avdmanager` gagal karena `devices.xml` tidak ditemukan,
jadi AVD dibuat manual:

```text
C:\Users\<user>\.android\avd\google_tv_34.avd\config.ini
C:\Users\<user>\.android\avd\google_tv_34.ini
```

Kunci `config.ini` yang penting:

```ini
tag.id=google-tv
abi.type=x86
hw.cpu.arch=x86
hw.screen.width=1920
hw.screen.height=1080
hw.lcd.density=320
hw.initialOrientation=landscape
image.sysdir.1=C:\Users\<user>\AppData\Local\Android\Sdk\system-images\android-34\google-tv\x86\
```

## 3. Hasil uji emulator (5–6 November 2026)

| Uji | Hasil | Bukti |
|---|---|---|
| Boot Google TV | ✅ | `adb devices` → `emulator-5554 device` |
| APK release terpasang | ✅ | `adb install -r app-release.apk` → `Success` |
| Aplikasi masuk leanback launcher | ✅ | logcat `katniss_interactor_PackageCache` memuat `id.rtsq.tv` |
| Aplikasi tampil sebagai HOME | ✅ | `dumpsys activity` → `id.rtsq.tv/.MainActivity` |
| Layar penuh (immersive) | ✅ | `dumpsys` menandai window `(fullscreen)` |
| Jam, tanggal, Hijriah | ✅ | UI dump memuat jam WIB + tanggal |
| 7 kartu sholat | ✅ | UI dump memuat IMSAK…ISYA |
| Ticker berjalan | ✅ | UI dump memuat chip `INFO` + teks |
| Layar pairing + QR (Fase 2a) | ✅ | Kode 6 digit + QR dari Supabase, `docs/preview/fase2a-pairing.png` |
| `flutter test` | ✅ | 9 tes lulus (3 golden) |
| Ukuran APK | 46,2 MB | `build/app/outputs/flutter-apk/app-release.apk` |

Catatan: `adb shell screencap` pada emulator ini kadang menghasilkan gambar
portrait 1080×1920 walau UI sebenarnya landscape. Itu keterbatasan capture
emulator, bukan bug aplikasi — `dumpsys activity` dan `uiautomator dump`
memastikan window sudah landscape penuh.

## 4. Checklist saat TV fisik tersedia

Jalankan `tools/provision_tv.ps1` setelah TV terhubung.

### 4.1 Aktifkan ADB di TV

1. **Settings → System → About → Build** → tekan 7× sampai mode developer aktif.
2. **Settings → System → Developer options → USB debugging / Network debugging** → aktifkan.
3. Catat IP TV (Settings → Network).
4. Dari PC: `adb connect <ip-tv>:5555`.

### 4.2 Data yang harus dicatat

```powershell
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.sdk
adb shell wm size
adb shell wm density
adb shell dumpsys meminfo | Select-String "Total RAM"
adb shell df -h /data
adb shell settings get system screen_off_timeout
adb shell pm list packages | Select-String "launcher"
```

Isi ke tabel berikut setelah uji nyata:

| Item | Nilai |
|---|---|
| Model | _belum diisi_ |
| Android / SDK | _belum diisi_ |
| Resolusi aktif | _belum diisi_ |
| Density | _belum diisi_ |
| RAM total | _belum diisi_ |
| Ruang `/data` | _belum diisi_ |
| Launcher bawaan | _belum diisi_ |

### 4.3 Uji 2 jam

| Uji | Kriteria lulus |
|---|---|
| Instalasi APK | `Success`, aplikasi muncul di launcher |
| Layar penuh | Tidak ada status bar / navigasi |
| Jam & tanggal | Benar WIB, Hijriah berganti saat Maghrib |
| Jadwal sholat | Cocok dengan Kemenag Batam |
| Hitung mundur | Berjalan tiap detik |
| Ticker | Bergerak mulus, tidak patah |
| Slideshow | Berganti tiap 10 detik, tanpa overflow |
| Wake lock | Layar tidak mati selama 2 jam |
| RAM | Tidak naik terus (stabil) |
| Suhu / throttling | Tidak ada penurunan FPS drastis |
| Mati-listrik | Setelah listrik kembali, aplikasi menyala sendiri (uji Fase 4) |

### 4.4 Uji 7 hari (Fase 4)

- Tidak ada layar hitam.
- Tidak perlu restart manual.
- Setelah TV di-restart, aplikasi kembali ke layar penuh.
- Log tidak menumpuk (retensi 30 hari).

## 5. Risiko yang masih terbuka

1. **Rotasi emulator** — capture portrait; perlu verifikasi orientasi di TV asli.
2. **RAM 2 GB** — emulator hanya 2 GB; TV asli bisa lebih besar/kecil. Catat
   `dumpsys meminfo` untuk menentukan batas cache media.
3. **Launcher kiosk** — belum mengunci launcher; masih bisa keluar dengan
   tombol Home. Ini bagian Fase 4 (PIN keluar).
4. **ADB jaringan** — TV harus berada di jaringan yang sama dengan PC.

## 6. Berkas terkait

- `tools/provision_tv.ps1` — skrip provisioning + pengumpulan data.
- `docs/preview/emulator-screen.png` — tangkapan emulator.
- `docs/preview/ui.xml` — dump hierarki UI emulator.
- `rtsq_tv/build/app/outputs/flutter-apk/app-release.apk` — APK uji.
