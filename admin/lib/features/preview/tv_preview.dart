import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import 'prayer_preview.dart';

const _bg = Color(0xFF07110E);
const _bgTop = Color(0xFF0B1714);
const _panel = Color(0xFF12211D);
const _panelAlt = Color(0xFF162A24);
const _gold = Color(0xFFC9AE5C);
const _teal = Color(0xFF12B3A0);
const _ink = Color(0xFFF7F3E8);
const _muted = Color(0xFF9FB0A8);
const _line = Color(0xFF24382F);

/// Pratinjau kanvas TV 16:9 (1280×720) yang diskalakan.
///
/// Tata letak mengikuti zona TV: header 120, konten 400, sholat 128,
/// ticker 72. Semua teks memakai Plus Jakarta Sans dan waktu WIB.
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
  });

  final ContentItem? content;
  final SettingsRow settings;
  final List<PreviewPrayer> prayers;
  final String tickerText;
  final String? imageUrl;
  final int slideIndex;
  final int slideCount;
  final bool animateTicker;

  @override
  State<TvPreview> createState() => _TvPreviewState();
}

class _TvPreviewState extends State<TvPreview> {
  DateTime _now = DateTime.now().toUtc();
  bool _timerReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.animateTicker) {
      _timerReady = true;
      _startTimer();
    }
  }

  void _startTimer() {
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_timerReady) return;
      setState(() => _now = DateTime.now().toUtc());
      _startTimer();
    });
  }

  @override
  void dispose() {
    _timerReady = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wib = Wib.toWib(_now);
    final content = widget.content;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: _bg,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 1280,
              height: 720,
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: _ink,
                  decoration: TextDecoration.none,
                ),
                child: Column(
                  children: [
                    _Header(
                      settings: widget.settings,
                      wib: wib,
                      prayers: widget.prayers,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 4, 32, 10),
                        child: _Slide(
                          content: content,
                          imageUrl: widget.imageUrl,
                          index: widget.slideIndex,
                          count: widget.slideCount,
                        ),
                      ),
                    ),
                    _PrayerStrip(prayers: widget.prayers, wib: wib),
                    _Ticker(
                      text: widget.tickerText.trim().isEmpty
                          ? 'Teks berjalan belum diisi.'
                          : widget.tickerText,
                      animate: widget.animateTicker,
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

    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bgTop, _bg],
        ),
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Image.asset('assets/brand/rtsq_white_trim.png', height: 52),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.orgName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    settings.address,
                    settings.city,
                  ].where((part) => part.trim().isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _clock(wib),
                style: const TextStyle(
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: _gold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_dayName(wib)} · ${Wib.fullDate(wib).split(', ').last}',
                style: const TextStyle(
                  fontSize: 12,
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formatHijriPreview(wib, maghrib),
                style: const TextStyle(
                  fontSize: 12,
                  color: _teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _clock(DateTime wib) =>
      '${wib.hour.toString().padLeft(2, '0')}:'
      '${wib.minute.toString().padLeft(2, '0')}';

  static String _dayName(DateTime wib) => const [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ][wib.weekday - 1];

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
    if (item == null) {
      return Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: const Center(
          child: Text(
            'Belum ada konten tayang.\nTambahkan pengumuman pertama.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, color: _muted, height: 1.6),
          ),
        ),
      );
    }

    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final isPhoto = item.type == 'photo' || item.type == 'video';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_panel, Color(0xFF0C1915)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            Positioned.fill(
              child: Image.network(
                imageUrl!,
                fit: isPhoto ? BoxFit.cover : BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if (hasImage && isPhoto)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC07110E), Color(0xE607110E)],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 24, 30, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: hasImage && !isPhoto ? 55 : 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          item.typeLabel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                            color: _gold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.title.trim().isEmpty
                            ? '(Tanpa judul)'
                            : item.title.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 34,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (item.body.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          item.body.trim(),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.45,
                            color: _muted,
                          ),
                        ),
                      ],
                      if (item.metaText.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          item.metaText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _teal,
                          ),
                        ),
                      ],
                      if (item.scheduleItems.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (final event in item.scheduleItems.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.event_outlined,
                                  size: 15,
                                  color: _gold,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    [
                                          event.title,
                                          event.date,
                                          event.time,
                                          event.place,
                                        ]
                                        .where((p) => p.trim().isNotEmpty)
                                        .join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (hasImage && !isPhoto) ...[
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 45,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${(index + 1).toString().padLeft(2, '0')} / '
                '${count.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerStrip extends StatelessWidget {
  const _PrayerStrip({required this.prayers, required this.wib});

  final List<PreviewPrayer> prayers;
  final DateTime wib;

  @override
  Widget build(BuildContext context) {
    if (prayers.isEmpty) return const SizedBox(height: 128);

    final nowMinutes = wib.hour * 60 + wib.minute;
    var nextIndex = -1;
    for (var i = 0; i < prayers.length; i++) {
      final entry = prayers[i];
      if (!entry.isPrayer) continue;
      final parts = entry.time.split(':');
      final minutes =
          (int.tryParse(parts.first) ?? 0) * 60 +
          (int.tryParse(parts.last) ?? 0);
      if (minutes > nowMinutes) {
        nextIndex = i;
        break;
      }
    }

    return Container(
      height: 128,
      padding: const EdgeInsets.fromLTRB(32, 10, 32, 12),
      child: Row(
        children: [
          for (var i = 0; i < prayers.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == prayers.length - 1 ? 0 : 8,
                ),
                child: _PrayerCard(
                  entry: prayers[i],
                  highlight: i == nextIndex,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.entry, required this.highlight});

  final PreviewPrayer entry;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: highlight ? _panelAlt : _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? _gold.withValues(alpha: 0.7) : _line,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            entry.label,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: highlight ? _gold : _muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.time,
            style: TextStyle(
              fontSize: 24,
              height: 1,
              fontWeight: FontWeight.w800,
              color: highlight
                  ? _ink
                  : entry.isPrayer
                  ? _ink
                  : _muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
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
    duration: const Duration(seconds: 35),
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
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Container(
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_gold, Color(0xFFB29541)]),
            ),
            child: const Center(
              child: Text(
                'INFO',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Color(0xFF07110E),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final painter = TextPainter(
                  text: TextSpan(
                    text: widget.text,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                )..layout();
                final width = painter.width;
                return ClipRect(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final offset =
                          constraints.maxWidth -
                          _controller.value * (constraints.maxWidth + width);
                      return Stack(
                        children: [
                          Positioned(
                            left: offset,
                            top: 0,
                            bottom: 0,
                            child: Center(child: child),
                          ),
                        ],
                      );
                    },
                    child: Text(
                      widget.text,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
