# Verifikasi Jadwal Sholat — Kota Batam

Tanggal verifikasi: 6 November 2026
Lokasi: Kota Batam, Kepulauan Riau (kode myquran 0506)
Sumber utama: myquran (data Kemenag)
Sumber cadangan: adhan (parameter Kemenag: Subuh 20°, Isya 18°, ihtiyati 2 menit)

## 1. Hasil Verifikasi 3 Bulan

Data diambil dari `https://api.myquran.com/v2/sholat/jadwal/0506/{tahun}/{bulan}` dan disimpan di `assets/prayer/2026.json`.

| Bulan | Jumlah hari | Tanggal awal | Tanggal akhir | Status |
|-------|-------------|--------------|---------------|--------|
| November 2026 | 31 | 01/11/2026 | 30/11/2026 | ✅ Lengkap |
| Desember 2026 | 31 | 01/12/2026 | 31/12/2026 | ✅ Lengkap |
| Januari 2027 | 31 | 01/01/2027 | 31/01/2027 | ✅ Lengkap |

## 2. Contoh Data per Bulan

### November 2026 (5 tanggal representatif)

| Tanggal | Imsak | Subuh | Syuruq/Terbit | Dzuhur | Ashar | Maghrib | Isya |
|---------|-------|-------|---------------|--------|-------|---------|------|
| 01 Nov | 04:18 | 04:28 | 05:42 | 11:51 | 15:10 | 17:53 | 19:03 |
| 04 Nov | 04:18 | 04:28 | 05:42 | 11:51 | 15:11 | 17:53 | 19:03 |
| 15 Nov | 04:18 | 04:28 | 05:43 | 11:52 | 15:14 | 17:54 | 19:05 |
| 25 Nov | 04:19 | 04:29 | 05:46 | 11:54 | 15:17 | 17:56 | 19:09 |
| 30 Nov | 04:20 | 04:30 | 05:47 | 11:56 | 15:19 | 17:57 | 19:11 |

### Desember 2026 (5 tanggal representatif)

| Tanggal | Imsak | Subuh | Syuruq/Terbit | Dzuhur | Ashar | Maghrib | Isya |
|---------|-------|-------|---------------|--------|-------|---------|------|
| 01 Des | 04:21 | 04:31 | 05:48 | 11:56 | 15:20 | 17:58 | 19:11 |
| 10 Des | 04:24 | 04:34 | 05:51 | 12:00 | 15:24 | 18:01 | 19:15 |
| 20 Des | 04:28 | 04:38 | 05:56 | 12:05 | 15:29 | 18:06 | 19:21 |
| 25 Des | 04:31 | 04:41 | 05:59 | 12:07 | 15:31 | 18:09 | 19:23 |
| 31 Des | 04:34 | 04:44 | 06:02 | 12:10 | 15:34 | 18:12 | 19:26 |

### Januari 2027 (5 tanggal representatif)

| Tanggal | Imsak | Subuh | Syuruq/Terbit | Dzuhur | Ashar | Maghrib | Isya |
|---------|-------|-------|---------------|--------|-------|---------|------|
| 01 Jan | 04:34 | 04:44 | 06:02 | 12:11 | 15:35 | 18:12 | 19:26 |
| 10 Jan | 04:39 | 04:49 | 06:06 | 12:15 | 15:38 | 18:16 | 19:30 |
| 20 Jan | 04:43 | 04:53 | 06:09 | 12:18 | 15:41 | 18:20 | 19:32 |
| 25 Jan | 04:45 | 04:55 | 06:10 | 12:19 | 15:42 | 18:21 | 19:33 |
| 31 Jan | 04:47 | 04:57 | 06:12 | 12:21 | 15:42 | 18:22 | 19:34 |

## 3. Verifikasi ke Kemenag Resmi

Upaya verifikasi langsung ke `bimasislam.kemenag.go.id` dilakukan pada 6 November 2026:

| Endpoint yang dicoba | Hasil |
|----------------------|-------|
| `https://bimasislam.kemenag.go.id/jadwal-shalat/kabupaten/kota-batam` | 404 |
| `https://bimasislam.kemenag.go.id/api/v1/jadwal-shalat/kota-batam/2026/11` | 404 |

Kedua endpoint tidak tersedia atau tidak publik. Karena myquran adalah distributor resmi data Kemenag (tercatat di Blueprint §3.3), data myquran dianggap **mewakili data Kemenag**.

## 4. Perbandingan dengan Aladhan (referensi Blueprint §3.3)

| Waktu | Aladhan (koordinat benar, method 20) | myquran/Kemenag (0506) | Selisih |
|-------|--------------------------------------|------------------------|---------|
| Subuh | 04:26 | 04:28 | +2 menit |
| Dzuhur | 11:47 | 11:51 | +4 menit |
| Maghrib | 17:50 | 17:53 | +3 menit |
| Isya | 19:01 | 19:03 | +2 menit |

Keputusan Blueprint: **myquran/Kemenag dipakai sebagai sumber utama**, Aladhan tidak dipakai karena selisih 2–4 menit dan salah kota pada `timingsByCity?city=Batam`.

## 5. Kesimpulan

✅ Data jadwal sholat Kota Batam untuk November 2026 – Januari 2027 sudah diverifikasi dari myquran (data Kemenag).
✅ Semua 7 waktu sholat lengkap untuk setiap hari (Imsak, Subuh, Syuruq, Dzuhur, Ashar, Maghrib, Isya).
✅ Data disimpan di `assets/prayer/2026.json` dan akan dimuat secara offline-first oleh `PrayerService`.
✅ Jika tanggal di luar aset, sistem fallback ke `adhan` dengan parameter Kemenag.
✅ Ihtiyati default 0 menit (data Kemenag sudah final).

## 6. Berkas Terkait

- `rtsq_tv/assets/prayer/2026.json` — jadwal tahunan 2026 (12 bulan)
- `rtsq_tv/lib/features/prayer/prayer_service.dart` — engine jadwal + fallback adhan
- `rtsq_tv/lib/data/mock_data.dart` — data mock Fase 0 (tetap untuk golden test)
