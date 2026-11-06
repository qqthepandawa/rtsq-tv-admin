import 'package:intl/intl.dart';

/// Semua tampilan waktu memakai WIB (UTC+7) eksplisit, tidak bergantung pada
/// zona waktu perangkat admin.
class Wib {
  Wib._();

  static DateTime? parse(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    final text = value.toString();
    if (text.trim().isEmpty) return null;
    return DateTime.tryParse(text)?.toUtc();
  }

  static DateTime now() => DateTime.now().toUtc();

  static DateTime toWib(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 7));

  static DateTime fromWib(DateTime wallClock) => DateTime.utc(
    wallClock.year,
    wallClock.month,
    wallClock.day,
    wallClock.hour,
    wallClock.minute,
  ).subtract(const Duration(hours: 7));

  static String date(DateTime? instant) {
    if (instant == null) return '—';
    return DateFormat('d MMM yyyy', 'id_ID').format(toWib(instant));
  }

  static String dateTime(DateTime? instant) {
    if (instant == null) return '—';
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(toWib(instant));
  }

  static String time(DateTime? instant) {
    if (instant == null) return '—';
    return DateFormat('HH:mm', 'id_ID').format(toWib(instant));
  }

  static String clock(DateTime instant) =>
      DateFormat('HH:mm:ss', 'id_ID').format(toWib(instant));

  static String fullDate(DateTime instant) =>
      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(toWib(instant));

  static String relative(DateTime? instant) {
    if (instant == null) return 'belum pernah';
    final diff = now().difference(instant.toUtc());
    if (diff.isNegative) return 'baru saja';
    if (diff.inSeconds < 60) return '${diff.inSeconds} detik lalu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 30) return '${diff.inDays} hari lalu';
    return date(instant);
  }

  /// ISO date (yyyy-MM-dd) untuk kolom `date`.
  static String isoDate(DateTime wallClock) =>
      DateFormat('yyyy-MM-dd').format(wallClock);

  /// Nilai untuk input `datetime-local` (waktu WIB, tanpa zona).
  static String inputValue(DateTime? instant) {
    if (instant == null) return '';
    return DateFormat("yyyy-MM-dd'T'HH:mm").format(toWib(instant));
  }

  /// Parse nilai `datetime-local` sebagai waktu WIB.
  static DateTime? fromInput(String value) {
    if (value.trim().isEmpty) return null;
    final wall = DateTime.tryParse(value);
    if (wall == null) return null;
    return fromWib(wall);
  }
}

String bytesLabel(int? bytes) {
  if (bytes == null || bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}
