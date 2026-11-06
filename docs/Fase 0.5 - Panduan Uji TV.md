# Panduan Uji TV — Fase 0.5

Target: **AQUA MatrixTV CE**, Android TV 14 (`UKNV.260302.001`).
Tujuan: memasang APK, memeriksa tampilan di layar nyata, lalu mencoba mode
kiosk (app sebagai beranda). Semua langkah di bawah **0 biaya**.

## 1. Siapkan TV

Di TV, buka **Setelan → Tentang (About)**, lalu klik **Build** 7 kali sampai
muncul "You are now a developer".

Aktifkan:

- **Developer options → USB debugging**
- **Developer options → Network debugging** (ADB lewat Wi-Fi)

Catat **IP TV** dari **Setelan → Jaringan** (mis. `192.168.1.24`).

> TV dan laptop harus berada di jaringan yang sama.

## 2. Hubungkan ADB

Di laptop:

```powershell
adb connect 192.168.1.24:5555
adb devices
```

Saat pertama kali, TV menampilkan dialog "Allow USB debugging" — pilih
**Always allow** lalu **OK**.

Bila `adb` belum ada di PATH:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" connect 192.168.1.24:5555
```

## 3. Pasang APK

```powershell
cd "C:\RTSQ TV\rtsq_tv"
flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

Jalankan:

```powershell
adb shell am start -n id.rtsq.tv/.MainActivity
```

## 4. Periksa tampilan

Yang dicek di layar TV:

- [ ] Tidak ada bagian terpotong di tepi layar (overscan).
- [ ] Jam dan tanggal terbaca dari jarak 3–4 meter.
- [ ] Ticker berjalan mulus, tidak patah-patah.
- [ ] Kartu sholat aktif (emas) dan berikutnya (teal) tepat.
- [ ] Slide berganti tiap 10 detik tanpa kedip.
- [ ] Layar tidak mati setelah 10 menit.

Log aplikasi:

```powershell
adb logcat -s flutter
```

## 5. Coba mode kiosk (opsional)

Cek beranda bawaan lebih dulu:

```powershell
adb shell cmd package resolve-activity -c android.intent.category.HOME
```

Jadikan RTSQ TV sebagai beranda:

```powershell
adb shell cmd package set-home-activity id.rtsq.tv/.MainActivity
```

**Kembalikan ke launcher bawaan** (ganti nama paket sesuai hasil perintah di
atas, umumnya `com.google.android.tvlauncher`):

```powershell
adb shell cmd package set-home-activity com.google.android.tvlauncher/.MainActivity
```

Jangan menonaktifkan launcher bawaan sebelum yakin. Bila TV terkunci, gunakan
**kartu pemulihan** di Blueprint §15.2 atau reset pabrik.

## 6. Jagalah layar tetap menyala

```powershell
adb shell settings put global stay_on_while_plugged_in 3
adb shell settings put system screen_off_timeout 2147483647
```

## 7. Yang perlu dicatat

Isi tabel ini setelah uji, untuk lampiran laporan:

| Item | Hasil |
|---|---|
| Resolusi & density (`adb shell wm size`, `wm density`) | |
| Versi Android / patch | |
| APK terpasang | |
| Overscan aman | ya / tidak |
| Ticker mulus | ya / tidak |
| Suhu / kestabilan 1 jam | |
| Catatan lain | |
