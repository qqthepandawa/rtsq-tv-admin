import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:http/http.dart' as http;

import '../../core/format.dart';
import '../../data/models.dart';

class PreviewPrayer {
  const PreviewPrayer({
    required this.label,
    required this.time,
    required this.isPrayer,
  });

  final String label;
  final String time;
  final bool isPrayer;
}

/// Jadwal sholat untuk pratinjau admin.
///
/// Kota Batam memakai data myquran/Kemenag (sama seperti TV). Kota lain
/// memakai perhitungan `adhan` dengan parameter Kemenag (Subuh 20°, Isya 18°,
/// ihtiyati 2 menit — parameter metode resmi, tetap).
class PrayerPreviewService {
  PrayerPreviewService._();

  static final Map<String, List<PreviewPrayer>> _cache = {};

  static Future<List<PreviewPrayer>> load(
    SettingsRow settings,
    DateTime wibNow,
  ) async {
    final isBatam = settings.city.toLowerCase().contains('batam');
    if (isBatam) {
      final fromApi = await _myQuran(wibNow);
      if (fromApi != null) return fromApi;
    }
    return _adhan(settings, wibNow);
  }

  static Future<List<PreviewPrayer>?> _myQuran(DateTime wibNow) async {
    final key = '${wibNow.year}-${wibNow.month}';
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final url =
          'https://api.myquran.com/v2/sholat/jadwal/0506/${wibNow.year}/'
          '${wibNow.month.toString().padLeft(2, '0')}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != true) return null;
      final data = body['data'] as Map<String, dynamic>;
      final list = data['jadwal'] as List?;
      if (list == null) return null;
      final dateKey =
          '${wibNow.year}-${wibNow.month.toString().padLeft(2, '0')}-'
          '${wibNow.day.toString().padLeft(2, '0')}';
      Map<String, dynamic>? today;
      for (final item in list) {
        if (item is Map && item['date'] == dateKey) {
          today = Map<String, dynamic>.from(item);
          break;
        }
      }
      if (today == null) return null;
      final entries = [
        PreviewPrayer(
          label: 'SUBUH',
          time: today['subuh'] as String,
          isPrayer: true,
        ),
        PreviewPrayer(
          label: 'SYURUQ',
          time: today['terbit'] as String,
          isPrayer: false,
        ),
        PreviewPrayer(label: 'DHUHA', time: _dhuhaTime(today), isPrayer: false),
        PreviewPrayer(
          label: 'DZUHUR',
          time: today['dzuhur'] as String,
          isPrayer: true,
        ),
        PreviewPrayer(
          label: 'ASHAR',
          time: today['ashar'] as String,
          isPrayer: true,
        ),
        PreviewPrayer(
          label: 'MAGHRIB',
          time: today['maghrib'] as String,
          isPrayer: true,
        ),
        PreviewPrayer(
          label: 'ISYA',
          time: today['isya'] as String,
          isPrayer: true,
        ),
      ];
      _cache[key] = entries;
      return entries;
    } catch (_) {
      return null;
    }
  }

  static List<PreviewPrayer> _adhan(SettingsRow settings, DateTime wibNow) {
    final params = CalculationParameters(
      fajrAngle: 20.0,
      ishaAngle: 18.0,
      ishaInterval: 0,
      adjustments: PrayerAdjustments(
        fajr: 2,
        dhuhr: 2,
        asr: 2,
        maghrib: 2,
        isha: 2,
      ),
    );
    final times = PrayerTimes(
      Coordinates(settings.latitude, settings.longitude),
      DateComponents.from(wibNow),
      params,
      utcOffset: const Duration(hours: 7),
    );
    final dhuha = times.sunrise.add(const Duration(minutes: 27));
    return [
      PreviewPrayer(label: 'SUBUH', time: _hhmm(times.fajr), isPrayer: true),
      PreviewPrayer(
        label: 'SYURUQ',
        time: _hhmm(times.sunrise),
        isPrayer: false,
      ),
      PreviewPrayer(label: 'DHUHA', time: _hhmm(dhuha), isPrayer: false),
      PreviewPrayer(label: 'DZUHUR', time: _hhmm(times.dhuhr), isPrayer: true),
      PreviewPrayer(label: 'ASHAR', time: _hhmm(times.asr), isPrayer: true),
      PreviewPrayer(
        label: 'MAGHRIB',
        time: _hhmm(times.maghrib),
        isPrayer: true,
      ),
      PreviewPrayer(label: 'ISYA', time: _hhmm(times.isha), isPrayer: true),
    ];
  }

  /// Waktu Dhuha dari myquran; data lama tanpa kolom `dhuha` memakai
  /// perkiraan syuruq + 27 menit (sama seperti aplikasi TV).
  static String _dhuhaTime(Map<String, dynamic> jadwal) {
    final value = (jadwal['dhuha'] as String? ?? '').trim();
    if (value.isNotEmpty) return value;
    final parts = (jadwal['terbit'] as String? ?? '06:00').split(':');
    final base = Duration(
      hours: int.tryParse(parts.first) ?? 6,
      minutes: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final dhuha = base + const Duration(minutes: 27);
    final hh = (dhuha.inHours % 24).toString().padLeft(2, '0');
    final mm = dhuha.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static String _hhmm(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

const _hijriMonths = <String>[
  'Muharram',
  'Safar',
  'Rabiul Awal',
  'Rabiul Akhir',
  'Jumadil Awal',
  'Jumadil Akhir',
  'Rajab',
  'Sya\'ban',
  'Ramadhan',
  'Syawal',
  'Dzulqa\'dah',
  'Dzulhijjah',
];

String formatHijriPreview(DateTime wibNow, DateTime maghrib) {
  final afterMaghrib = wibNow.isAfter(maghrib);
  final effective = DateTime(
    wibNow.year,
    wibNow.month,
    wibNow.day,
  ).add(Duration(days: afterMaghrib ? 1 : 0));
  final hijri = HijriCalendar.fromDate(effective);
  final month = _hijriMonths[hijri.hMonth - 1];
  return '${hijri.hDay} $month ${hijri.hYear} H';
}

/// Jam dinding WIB dari instant UTC.
String previewClock(DateTime instant) => Wib.clock(instant);
