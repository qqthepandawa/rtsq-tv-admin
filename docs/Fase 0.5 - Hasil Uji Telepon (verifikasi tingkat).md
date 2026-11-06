# Hasil Uji — Fase 0.5 (verifikasi pada PC/Windows)

> Status aktual: **tidak ada perangkat Android TV yang terhubung secara aktif
> di mesin ini.** Persyaratan uji perangkat nyata (AQUA MatrixTV CE) tertunda.
> Segala sesi berikutnya menunggu konfirmasi Bapak bahwa TV tersedia.

## Apa yang sudah diverifikasi

### Release APK (`--release`)

| Cek | Hasil |
|---|---|
| Build | ✅ **46.1 MB** (`app-release.apk`, build P0 5 Nov 2026) |
| `applicationId` | ✅ `id.rtsq.tv` |
| `minSdk` | ✅ 24 |
| `targetSdk` | ✅ 34 |
| Label aplikasi | ✅ `RTSQ TV` |
| Launchable activity | ✅ `id.rtsq.tv/.MainActivity` |
| Leanback launcher | ✅ ada (`category.LEANBACK_LAUNCHER`) |
| HOME / kiosk intent | ✅ ada (`category.HOME`) |
| Banner TV | ✅ `@drawable/tv_banner` |
| Landscape | ✅ `screenOrientation=landscape` |
| Transparent logo padding | ✅ sudah di-trim (`_trim.png`) |

### Desktop preview (`flutter run -d windows`)

Terbukti layar menyusut ke 1920×1080 dan scale menyesuaikan. Tidak
over pada monitor yang ada.

## Apa yang belum diverifikasi di TV nyata

| Item | Status |
|---|---|
| Overscan aman | ⏳ tunggu Bapak |
| Ticker berjalan mulus | ⏳ tunggu Bapak |
| Sholat aktif/berikutnya tepat | ⏳ tunggu Bapak |
| Layar 10 menit tidak mati | ⏳ tunggu Bapak |
| Kiosk mode HOME | ⏳ tunggu Bapak |
| `adb logcat` saat app jalan | ⏳ tunggu Bapak |

## Cara test di TV AQUA

Lihat `docs/Fase 0.5 - Panduan Uji TV.md`. Ringkasan:

1. Aktifkan developer mode di TV, aktifkan USB debugging.
2. `adb connect <TV-IP>:5555`, `adb install -r app-release.apk`.
3. Periksa 5 poin di panduan tersebut.
4. Catat hasilnya.

## Bukti kuantitatif

```text
APK size    : 46.1 MB (build P0, 5 Nov 2026)
package     : id.rtsq.tv
label       : RTSQ TV
minSdk     : 24
targetSdk  : 34
leanback   : yes
launchable : yes
home       : yes
banner     : yes
orientation: landscape
```

## Laporan tersedia

- `docs/Fase 0 - Laporan.md` — hasil visual + standar uji.
- `docs/Fase 0.5 - Panduan Uji TV.md` — prosedur lengkap.
- `docs/Fase 0.5 - Hasil Uji.md` — ini file.

## Tindakan berikut (apa yang perlu Bapak lakukan)

1. **Pilih perangkat test** — TV AQUA dan/atau komputer Windows yang mempunya monitor.
2. **Uji panduannya** — 5 po cukup, catat kalau tertentu bermasalah.
3. **Konfirmasi bila Fase 0.5 mau lanjut** — setelah pengecekan, kami lewatkan
   ke implementasi waktu/jadwal sholat (Fase 1).
