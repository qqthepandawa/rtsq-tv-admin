import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import 'prayer_preview.dart';

const _bg = Color(0xFF0E2620);
const _bgDeep = Color(0xFF081B16);
const _panel = Color(0xFF173C31);
const _panelAlt = Color(0xFF1F4A3D);
const _gold = Color(0xFFE3C878);
const _goldLine = Color(0x80E3C878);
const _teal = Color(0xFF31E0C2);
const _ink = Color(0xFFF3FBF7);
const _muted = Color(0xFFA9CDC1);
const _line = Color(0xFF2F5B4E);

/// Pratinjau kanvas TV **1920×1080** yang diskalakan seragam.
///
/// Tata letak sama dengan aplikasi TV: header ramping 140, lalu baris berisi
/// panel sholat **vertikal** (lebar 420) di kiri dan kotak konten **16:9** di
/// kanan, lalu ticker 100. Tipografi mengikuti Blueprint §5.3 (24–104 px).
class TvPreview extends StatefulWidget {
  const TvPreview({
    super.key,
    required this.content,
    required this.settings,
    required this.prayers,
    required this.tickerText,
    this.imageUrl,
    this.slideIndex = 0,
    this.slideCount = 1,
    this.animateTicker = true,
    this.fixedNow,
  });

  final ContentItem? content;
  final SettingsRow settings;
  final List<PreviewPrayer> prayers;
  final String tickerText;
  final String? imageUrl;
  final int slideIndex;
  final int slideCount;
  final bool animateTicker;

  /// Waktu tetap (UTC) untuk pratinjau deterministik di pengujian. Null berarti
  /// memakai jam berjalan.
  final DateTime? fixedNow;

  @override
  State<TvPreview> createState() => _TvPreviewState();
}

class _TvPreviewState extends State<TvPreview> {
  late DateTime _now = widget.fixedNow ?? DateTime.now().toUtc();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.animateTicker && widget.fixedNow == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now().toUtc());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wib = Wib.toWib(_now);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: _bg,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1920,
              height: 1080,
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: _ink,
                  decoration: TextDecoration.none,
                  fontSize: 24,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const _Backdrop(),
                    Column(
                      children: [
                        _Header(
                          settings: widget.settings,
                          wib: wib,
                          prayers: widget.prayers,
                        ),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(width: 48),
                              SizedBox(
                                width: 420,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: _PrayerPanel(
                                    prayers: widget.prayers,
                                    wib: wib,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 36),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    6,
                                    48,
                                    14,
                                  ),
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: _Slide(
                                        content: widget.content,
                                        imageUrl: widget.imageUrl,
                                        index: widget.slideIndex,
                                        count: widget.slideCount,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Ticker(
                          text: widget.tickerText.trim().isEmpty
                              ? 'RTSQ TV · Belum ada informasi terbaru'
                              : widget.tickerText,
                          animate: widget.animateTicker,
                        ),
                      ],
                    ),
                    // Garis aksen tipis di tepi atas layar, sama dengan app TV.
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0x00E3C878),
                                _gold,
                                Color(0x00E3C878),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.settings,
    required this.wib,
    required this.prayers,
  });

  final SettingsRow settings;
  final DateTime wib;
  final List<PreviewPrayer> prayers;

  @override
  Widget build(BuildContext context) {
    String? maghribText;
    for (final entry in prayers) {
      if (entry.label == 'MAGHRIB') {
        maghribText = entry.time;
        break;
      }
    }
    final maghrib = _parseTime(maghribText, wib) ?? wib;

    return SizedBox(
      height: 140,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 24, 48, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _YkcaBadge(),
            const SizedBox(width: 20),
            SizedBox(
              height: 84,
              child: Image.asset(
                'assets/brand/rtsq_white_trim.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(width: 24),
            Container(width: 1, height: 72, color: _line),
            const SizedBox(width: 24),
            Expanded(child: _IdentityBlock(settings: settings)),
            _DateBlock(wib: wib, hijri: formatHijriPreview(wib, maghrib)),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime wib) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${days[wib.weekday - 1]}, ${wib.day} '
        '${months[wib.month - 1]} ${wib.year}';
  }

  static String _location(SettingsRow settings) {
    final city = settings.city.trim();
    if (city.isEmpty) return 'Batam  •  Kepulauan Riau';
    return city.toLowerCase() == 'batam' ? 'Batam  •  Kepulauan Riau' : city;
  }

  static DateTime? _parseTime(String? value, DateTime day) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }
}

/// Logo Yayasan Keluarga Cinta Al-Qur'an di kiri header.
class _YkcaBadge extends StatelessWidget {
  const _YkcaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 84,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _goldLine, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Image.asset(
        'assets/brand/ykca_trim.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Nama lembaga, kota, dan yayasan di tengah header.
class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({required this.settings});

  final SettingsRow settings;

  @override
  Widget build(BuildContext context) {
    final name = settings.orgName.trim().isEmpty
        ? "RUMAH TAHFIZH SMART QUR'AN"
        : settings.orgName.trim().toUpperCase();
    final address = settings.address.trim();
    final place = address.isNotEmpty ? address : _Header._location(settings);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          place,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 24, height: 1.1, color: _muted),
        ),
        const Text(
          "Yayasan Keluarga Cinta Al-Qur'an",
          style: TextStyle(
            fontSize: 24,
            height: 1.1,
            color: Color(0xCCA9CDC1),
          ),
        ),
      ],
    );
  }
}

/// Tanggal Masehi dan Hijriah di kanan header.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.wib, required this.hijri});

  final DateTime wib;
  final String hijri;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _Header._date(wib),
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          hijri,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: _gold,
          ),
        ),
      ],
    );
  }
}

/// Latar gradien dan dua lingkaran cahaya lembut, sama seperti app TV.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF16382E), _bg, _bgDeep],
            ),
          ),
        ),
        Positioned(
          top: -260,
          left: -180,
          child: _Glow(
            size: 900,
            color: _gold.withValues(alpha: 0.055),
          ),
        ),
        Positioned(
          bottom: -320,
          right: -200,
          child: _Glow(
            size: 1000,
            color: _teal.withValues(alpha: 0.045),
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.content,
    required this.imageUrl,
    required this.index,
    required this.count,
  });

  final ContentItem? content;
  final String? imageUrl;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final item = content;
    final immersive =
        item != null &&
        item.isMediaContent &&
        (!item.showCaption ||
            (item.title.trim().isEmpty &&
                item.body.trim().isEmpty &&
                item.metaText.isEmpty));

    return Container(
      decoration: BoxDecoration(
        gradient: immersive
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_panel, _panelAlt],
              ),
        color: immersive ? const Color(0xFF050908) : null,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item == null)
            const Center(
              child: Text(
                'Belum ada konten tayang.\nTambahkan pengumuman pertama.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 34, color: _muted, height: 1.6),
              ),
            )
          else if (item.type == 'schedule')
            _ScheduleSlide(item: item)
          else
            _ContentSlide(item: item, imageUrl: imageUrl),
          if (count > 1 && !immersive)
            Positioned(
              top: 20,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _bgDeep.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _line),
                ),
                child: Text(
                  '${(index + 1).toString().padLeft(2, '0')} / '
                  '${count.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: _muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContentSlide extends StatelessWidget {
  const _ContentSlide({required this.item, required this.imageUrl});

  final ContentItem item;
  final String? imageUrl;

  /// Lebar panel media dihitung dari tinggi kotak 16:9 yang tersedia,
  /// sama seperti aplikasi TV. Poster tinggi memakai panel sempit, gambar
  /// lanskap memakai panel lebar.
  double _mediaWidth(double canvasHeight) {
    if (item.type == 'video') return canvasHeight * 16 / 9 * 0.66;
    if (imageUrl == null) return canvasHeight * 16 / 9 * 0.45;
    int? width;
    int? height;
    for (final media in item.media) {
      if (!media.type.startsWith('image')) continue;
      width = media.width;
      height = media.height;
      if (width != null && height != null) break;
    }
    if (width == null || height == null || height <= 0) {
      return canvasHeight * 16 / 9 * 0.45;
    }
    return (canvasHeight * (width / height))
        .clamp(360.0, canvasHeight * 16 / 9 * 0.72);
  }

  bool get _hasCaption =>
      item.captionVisible &&
      (item.title.trim().isNotEmpty ||
          item.body.trim().isNotEmpty ||
          item.metaText.isNotEmpty);

  bool get _immersive => item.isMediaContent && !_hasCaption;

  @override
  Widget build(BuildContext context) {
    final media = _MediaPanel(
      item: item,
      imageUrl: imageUrl,
      immersive: _immersive,
    );
    if (_immersive) return media;
    if (!_hasCaption) {
      return Padding(padding: const EdgeInsets.all(18), child: media);
    }
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _mediaWidth(constraints.maxHeight),
            child: media,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 44, 52, 40),
              child: _TextBlock(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim();
    final body = item.body.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Kicker(label: _kicker, color: _accent),
        const SizedBox(height: 24),
        if (title.isNotEmpty)
          Flexible(
            child: Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 56,
                height: 1.12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (title.isNotEmpty && body.isNotEmpty) const SizedBox(height: 20),
        if (body.isNotEmpty)
          Text(
            body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 34,
              height: 1.45,
              color: Color(0xFFDCEEE4),
            ),
          ),
        const Spacer(),
        if (item.metaText.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item.metaText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: _gold,
              ),
            ),
          ),
      ],
    );
  }

  String get _kicker => switch (item.type) {
    'achievement' => 'PRESTASI SANTRI',
    'photo' => 'DOKUMENTASI RTSQ',
    'video' => 'VIDEO RTSQ',
    _ => 'PENGUMUMAN',
  };

  Color get _accent =>
      item.type == 'photo' || item.type == 'video' ? _teal : _gold;
}

class _MediaPanel extends StatelessWidget {
  const _MediaPanel({
    required this.item,
    required this.imageUrl,
    this.immersive = false,
  });

  final ContentItem item;
  final String? imageUrl;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final image = Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A1512),
          borderRadius: immersive ? null : BorderRadius.circular(18),
          border: immersive ? null : Border.all(color: _line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
      if (immersive) return ColoredBox(color: Colors.black, child: image);
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
        child: image,
      );
    }

    final accent = item.type == 'photo' || item.type == 'video' ? _teal : _gold;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.type == 'achievement'
              ? const [_panelAlt, _panel]
              : const [Color(0xFF332F22), Color(0xFF171A11)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 16,
            right: 20,
            child: Opacity(
              opacity: 0.22,
              child: Image.asset(
                'assets/brand/rtsq_white_trim.png',
                height: 66,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.05),
                border: Border.all(
                  color: accent.withValues(alpha: 0.28),
                  width: 1.4,
                ),
              ),
              child: Icon(
                item.type == 'achievement'
                    ? Icons.emoji_events_outlined
                    : item.type == 'photo'
                    ? Icons.photo_library_rounded
                    : item.type == 'video'
                    ? Icons.videocam_rounded
                    : Icons.campaign_rounded,
                size: 102,
                color: accent.withValues(alpha: 0.62),
              ),
            ),
          ),
          if (item.type != 'photo' && item.type != 'video')
            Positioned(
              left: 28,
              bottom: 24,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'RTSQ • BATAM',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: Color(0xB3F3FBF7),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleSlide extends StatelessWidget {
  const _ScheduleSlide({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 40, 48, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Kicker(label: 'JADWAL & AGENDA', color: _gold),
          const SizedBox(height: 18),
          if (item.title.trim().isNotEmpty)
            Text(
              item.title.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 56,
                height: 1.12,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (item.title.trim().isNotEmpty && item.body.trim().isNotEmpty)
            const SizedBox(height: 6),
          if (item.body.trim().isNotEmpty)
            Text(
              item.body.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 34,
                height: 1.45,
                color: Color(0xFFDCEEE4),
              ),
            ),
          const SizedBox(height: 30),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < item.scheduleItems.length; i++) ...[
                  if (i > 0) const SizedBox(width: 18),
                  Expanded(child: _EventCard(item: item.scheduleItems[i])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final when = [
      item.date,
      item.time,
    ].where((part) => part.trim().isNotEmpty).join(' • ');

    return Container(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title.trim().isEmpty ? 'Kegiatan' : item.title.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 32,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (when.isNotEmpty)
            Text(
              when,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: _gold,
              ),
            ),
          if (item.place.trim().isNotEmpty)
            Text(
              item.place,
              style: const TextStyle(fontSize: 24, color: _muted),
            ),
        ],
      ),
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Panel sisi kiri layar: jam besar, jadwal sholat vertikal (Subuh → Isya),
/// dan hitung mundur menuju sholat berikutnya — sama seperti app TV.
class _PrayerPanel extends StatelessWidget {
  const _PrayerPanel({required this.prayers, required this.wib});

  final List<PreviewPrayer> prayers;
  final DateTime wib;

  @override
  Widget build(BuildContext context) {
    if (prayers.isEmpty) return const SizedBox.shrink();

    final nowMinutes = wib.hour * 60 + wib.minute;
    int? activeIndex;
    // Periode berjalan mengikuti entri terakhir yang sudah masuk, termasuk
    // Syuruq dan Dhuha, agar penanda emas tidak tertinggal di sholat wajib.
    for (var i = 0; i < prayers.length; i++) {
      if (_minutes(prayers[i].time) <= nowMinutes) activeIndex = i;
    }
    var nextIndex = -1;
    for (var i = 0; i < prayers.length; i++) {
      if (!prayers[i].isPrayer) continue;
      if (_minutes(prayers[i].time) > nowMinutes) {
        nextIndex = i;
        break;
      }
    }
    if (nextIndex < 0) {
      nextIndex = prayers.indexWhere((entry) => entry.label == 'SUBUH');
    }

    var countdown = Duration.zero;
    if (nextIndex >= 0) {
      final parts = prayers[nextIndex].time.split(':');
      var nextAt = DateTime(
        wib.year,
        wib.month,
        wib.day,
        int.tryParse(parts.first) ?? 0,
        parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      );
      if (!nextAt.isAfter(wib)) {
        nextAt = nextAt.add(const Duration(days: 1));
      }
      countdown = nextAt.difference(wib);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ClockBlock(wib: wib),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _panel.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
            ),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
            child: Column(
              children: [
                for (var i = 0; i < prayers.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: 1,
                      color: _line.withValues(alpha: 0.6),
                    ),
                  Expanded(
                    child: _PrayerRow(
                      entry: prayers[i],
                      isFriday: wib.weekday == DateTime.friday,
                      isActive: activeIndex == i,
                      isNext: nextIndex == i,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _NextPrayerFooter(countdown: countdown),
      ],
    );
  }

  static int _minutes(String time) {
    final parts = time.split(':');
    return (int.tryParse(parts.first) ?? 0) * 60 +
        (int.tryParse(parts.last) ?? 0);
  }
}

/// Kartu jam besar di atas panel sholat.
class _ClockBlock extends StatelessWidget {
  const _ClockBlock({required this.wib});

  final DateTime wib;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_panel, _panelAlt],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _goldLine),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.10),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _clock(wib),
            style: const TextStyle(
              fontSize: 88,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'WAKTU INDONESIA BARAT',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  static String _clock(DateTime wib) =>
      '${wib.hour.toString().padLeft(2, '0')}:'
      '${wib.minute.toString().padLeft(2, '0')}';
}

/// Satu baris sholat: titik penanda, nama, dan waktu.
class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.entry,
    required this.isFriday,
    required this.isActive,
    required this.isNext,
  });

  final PreviewPrayer entry;
  final bool isFriday;
  final bool isActive;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final label = isFriday && entry.label == 'DZUHUR' ? 'JUMAT' : entry.label;
    final labelColor = isActive
        ? _gold
        : isNext
        ? _teal
        : _muted;
    final timeColor = isActive ? _gold : _ink;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? _gold
                : isNext
                ? _teal
                : Colors.transparent,
            border: isActive || isNext
                ? null
                : Border.all(color: _line, width: 1.4),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            fontSize: 26,
            height: 1,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: labelColor,
          ),
        ),
        const Spacer(),
        Text(
          entry.time,
          style: TextStyle(
            fontSize: 38,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: timeColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Baris hitung mundur sholat berikutnya di bawah panel.
class _NextPrayerFooter extends StatelessWidget {
  const _NextPrayerFooter({required this.countdown});

  final Duration countdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x2E31E0C2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _teal.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text(
            'BERIKUTNYA',
            style: TextStyle(
              fontSize: 24,
              height: 1,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: _teal,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          Text(
            _countdown(countdown),
            style: const TextStyle(
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w600,
              color: _gold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static String _countdown(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final seconds = total.inSeconds.remainder(60);
    String two(int value) => value.toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }
}

class _Ticker extends StatefulWidget {
  const _Ticker({required this.text, required this.animate});

  final String text;
  final bool animate;

  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _panel,
          border: Border(
            top: BorderSide(color: _goldLine),
            bottom: BorderSide(color: _line),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 118,
              height: double.infinity,
              color: _gold,
              alignment: Alignment.center,
              child: const Text(
                'INFO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                  color: _bgDeep,
                ),
              ),
            ),
            Expanded(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final painter = TextPainter(
                      text: TextSpan(
                        text: widget.text,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 34,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          color: _ink,
                        ),
                      ),
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                    )..layout();
                    final width = painter.width;
                    final duration = Duration(
                      milliseconds: ((constraints.maxWidth + width) / 60 * 1000)
                          .round(),
                    );
                    if (_controller.duration != duration) {
                      _controller.duration = duration;
                    }
                    if (!widget.animate) {
                      return Center(
                        child: Text(
                          widget.text,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final x =
                            constraints.maxWidth -
                            _controller.value * (constraints.maxWidth + width);
                        return Transform.translate(
                          offset: Offset(x, 0),
                          child: child,
                        );
                      },
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.text,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension ContentPreviewText on ContentItem {
  String get metaText {
    final parts = <String>[
      if ((studentName ?? '').trim().isNotEmpty) studentName!.trim(),
      if ((marhalah ?? '').trim().isNotEmpty) marhalah!.trim(),
      if ((achievement ?? '').trim().isNotEmpty) achievement!.trim(),
    ];
    return parts.join(' • ');
  }
}
