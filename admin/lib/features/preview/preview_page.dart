import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import 'prayer_preview.dart';
import 'tv_preview.dart';

class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  final _repo = AdminRepository();

  List<ContentItem> _contents = const [];
  List<TickerItem> _ticker = const [];
  SettingsRow _settings = const SettingsRow();
  List<PreviewPrayer> _prayers = const [];
  ContentItem? _selected;
  String? _imageUrl;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.fetchContents(),
        _repo.fetchSettings(),
        _repo.fetchTicker(),
      ]);
      final settings = results[1] as SettingsRow;
      final prayers = await PrayerPreviewService.load(
        settings,
        Wib.toWib(Wib.now()),
      );
      final contents = results[0] as List<ContentItem>;
      ContentItem? selected;
      for (final item in contents) {
        if (item.isPublished) {
          selected = item;
          break;
        }
      }
      selected ??= contents.isEmpty ? null : contents.first;
      if (!mounted) return;
      setState(() {
        _contents = contents;
        _settings = settings;
        _ticker = results[2] as List<TickerItem>;
        _prayers = prayers;
        _selected = selected;
        _error = null;
      });
      await _resolveImage();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolveImage() async {
    final item = _selected;
    if (item == null) {
      if (mounted) setState(() => _imageUrl = null);
      return;
    }
    String? url;
    for (final media in item.media) {
      if (!media.type.startsWith('image')) continue;
      url = await _repo.signedUrl(media.thumbPath ?? media.path);
      if (url != null) break;
    }
    if (mounted) setState(() => _imageUrl = url);
  }

  String get _tickerText => _ticker
      .where((item) => item.active)
      .map((item) => item.text.trim())
      .where((text) => text.isNotEmpty)
      .join('  •  ');

  @override
  Widget build(BuildContext context) {
    final index = _selected == null ? 0 : _contents.indexOf(_selected!);

    return PageScaffold(
      title: 'Pratinjau TV',
      subtitle:
          'Kanvas 16:9 dengan jadwal sholat, Hijriah, dan ticker yang sama '
          'seperti di TV. Perubahan konten di panel langsung terlihat di sini.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Muat ulang'),
        ),
        ElevatedButton.icon(
          onPressed: () => context.go('/content/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Konten baru'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) InlineError(message: _error!),
          if (_loading && _contents.isEmpty)
            const LoadingBlock(message: 'Menyiapkan pratinjau…')
          else ...[
            SectionCard(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selected?.id,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Konten yang ditampilkan',
                      ),
                      items: [
                        for (final item in _contents)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.title} · ${item.typeLabel}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() {
                          _selected = _contents.firstWhere(
                            (item) => item.id == value,
                          );
                        });
                        await _resolveImage();
                      },
                    ),
                  ),
                  StatusPill(
                    label: '${_contents.length} slide tayang & draf',
                    tone: PillTone.info,
                    icon: Icons.layers_outlined,
                  ),
                  StatusPill(
                    label: 'Waktu WIB',
                    tone: PillTone.neutral,
                    icon: Icons.schedule,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  TvPreview(
                    content: _selected,
                    settings: _settings,
                    prayers: _prayers,
                    tickerText: _tickerText,
                    imageUrl: _imageUrl,
                    slideIndex: index < 0 ? 0 : index,
                    slideCount: _contents.isEmpty ? 1 : _contents.length,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const StatusPill(
                        label: '1920 × 1080',
                        tone: PillTone.neutral,
                        icon: Icons.aspect_ratio,
                      ),
                      const SizedBox(width: 8),
                      const StatusPill(
                        label: 'Skala seragam',
                        tone: PillTone.neutral,
                        icon: Icons.fit_screen,
                      ),
                      const Spacer(),
                      Text(
                        'Zona: header 120 · konten 400 · sholat 128 · ticker 72',
                        style: AdminText.caption.copyWith(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Catatan pratinjau',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Note(
                    text:
                        'Jadwal sholat Batam memakai data myquran/Kemenag. '
                        'Kota lain memakai perhitungan adhan dengan ihtiyati '
                        'dari Pengaturan.',
                  ),
                  _Note(
                    text:
                        'TV asli menampilkan hitung mundur dan highlight '
                        'sholat berikutnya; pratinjau ini fokus pada tata '
                        'letak konten, media, dan ticker.',
                  ),
                  _Note(
                    text:
                        'Teks ticker diambil dari ticker aktif tanpa '
                        'memperhitungkan jadwal mulai/selesai.',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AdminColors.teal,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AdminText.caption)),
        ],
      ),
    );
  }
}
