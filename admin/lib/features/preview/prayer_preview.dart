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
/// memakai perhitungan `adhan` dengan parameter Kemenag dan ihtiyati dari
/// pengaturan.
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
          label: 'IMSAK',
          time: today['imsak'] as String,
          isPrayer: false,
        ),
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
        fajr: _ihtiyati(settings, 'subuh'),
        dhuhr: _ihtiyati(settings, 'dzuhur'),
        asr: _ihtiyati(settings, 'ashar'),
        maghrib: _ihtiyati(settings, 'maghrib'),
        isha: _ihtiyati(settings, 'isya'),
      ),
    );
    final times = PrayerTimes(
      Coordinates(settings.latitude, settings.longitude),
      DateComponents.from(wibNow),
      params,
      utcOffset: const Duration(hours: 7),
    );
    final imsak = times.fajr.subtract(const Duration(minutes: 10));
    return [
      PreviewPrayer(label: 'IMSAK', time: _hhmm(imsak), isPrayer: false),
      PreviewPrayer(label: 'SUBUH', time: _hhmm(times.fajr), isPrayer: true),
      PreviewPrayer(
        label: 'SYURUQ',
        time: _hhmm(times.sunrise),
        isPrayer: false,
      ),
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

  static int _ihtiyati(SettingsRow settings, String key) =>
      (settings.ihtiyati[key] as num?)?.toInt() ?? 0;

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
