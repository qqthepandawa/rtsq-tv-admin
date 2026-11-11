import 'dart:async';

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

  List<Device> _devices = const [];
  Device? _liveDevice;
  String? _liveImageUrl;
  String? _liveError;
  bool _liveLoading = false;
  bool _liveAuto = false;
  DateTime? _liveAt;
  Timer? _liveTimer;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.fetchContents(),
        _repo.fetchSettings(),
        _repo.fetchTicker(),
        _repo.fetchDevices(),
      ]);
      final settings = results[1] as SettingsRow;
      final devices = [
        for (final device in results[3] as List<Device>)
          if (device.isPaired) device,
      ];
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
        _devices = devices;
        if (_liveDevice == null ||
            !devices.any((device) => device.id == _liveDevice!.id)) {
          _liveDevice = devices.isEmpty ? null : devices.first;
        }
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
      url = await _repo.signedUrl(media.path);
      if (url != null) break;
    }
    if (mounted) setState(() => _imageUrl = url);
  }

  void _setLiveAuto(bool value) {
    _liveTimer?.cancel();
    _liveTimer = null;
    setState(() => _liveAuto = value);
    if (!value) return;
    _liveTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _captureLive(),
    );
    _captureLive();
  }

  Future<void> _captureLive() async {
    final device = _liveDevice;
    if (device == null || _liveLoading) return;
    setState(() {
      _liveLoading = true;
      _liveError = null;
    });
    try {
      final before = await _repo.fetchCommands(device.id);
      final known = {
        for (final row in before)
          if (row['id'] is String) row['id'] as String,
      };
      await _repo.createCommand(device.id, 'screenshot');

      Map<String, dynamic>? done;
      for (var attempt = 0; attempt < 30 && done == null; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        final rows = await _repo.fetchCommands(device.id);
        for (final row in rows) {
          final id = row['id'] as String?;
          if (id == null || known.contains(id)) continue;
          if (row['type'] != 'screenshot') continue;
          if (row['status'] == 'failed') {
            throw AdminException('TV gagal mengambil tangkapan layar.');
          }
          if (row['status'] == 'done') {
            done = row;
            break;
          }
        }
      }
      if (done == null) {
        throw AdminException(
          'TV belum merespons. Pastikan TV menyala dan terhubung.',
        );
      }
      final result = done['result'];
      final path = result is Map ? result['path'] as String? : null;
      if (path == null || path.trim().isEmpty) {
        throw AdminException('TV tidak mengirim berkas tangkapan layar.');
      }
      final url = await _repo.signedUrl(path.trim());
      if (url == null) {
        throw AdminException('Tangkapan layar tidak dapat dibuka.');
      }
      if (!mounted) return;
      setState(() {
        _liveImageUrl = url;
        _liveAt = Wib.now();
      });
    } catch (error) {
      if (mounted) setState(() => _liveError = errorText(error));
    } finally {
      if (mounted) setState(() => _liveLoading = false);
    }
  }

  String get _tickerText => _ticker
      .where((item) => item.active)
      .map((item) => item.text.trim())
      .where((text) => text.isNotEmpty)
      .join('  •  ');

  Widget _buildLiveCard() {
    final device = _liveDevice;
    return SectionCard(
      title: 'Layar TV langsung',
      subtitle:
          'Tangkapan layar asli dari TV terpasang. Perintah dijalankan dalam '
          'hitungan detik bila TV online.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(device?.id),
                  initialValue: device?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'TV'),
                  items: [
                    for (final item in _devices)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          '${item.name} · '
                          '${item.isOnline ? 'online' : 'offline'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _devices.isEmpty
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _liveDevice = _devices.firstWhere(
                              (item) => item.id == value,
                            );
                            _liveImageUrl = null;
                            _liveError = null;
                          });
                        },
                ),
              ),
              ElevatedButton.icon(
                onPressed: device == null || _liveLoading ? null : _captureLive,
                icon: _liveLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(_liveLoading ? 'Mengambil…' : 'Ambil layar'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _liveAuto,
                    onChanged: device == null ? null : _setLiveAuto,
                  ),
                  const SizedBox(width: 6),
                  const Text('Otomatis 15 detik'),
                ],
              ),
            ],
          ),
          if (_devices.isEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Belum ada TV terpasang. Pasangkan TV terlebih dahulu di menu '
              'Perangkat.',
            ),
          ],
          if (_liveError != null) ...[
            const SizedBox(height: 10),
            InlineError(message: _liveError!),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: _liveImageUrl == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            device == null
                                ? 'Pilih TV untuk melihat layarnya.'
                                : 'Tekan "Ambil layar" untuk menampilkan '
                                      'tangkapan layar dari TV.',
                            textAlign: TextAlign.center,
                            style: AdminText.caption.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      )
                    : Image.network(
                        _liveImageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text(
                            'Gambar gagal dimuat.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (_liveAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Layar diambil pukul ${Wib.clock(_liveAt!)} WIB',
              style: AdminText.caption,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = _selected == null ? 0 : _contents.indexOf(_selected!);

    return PageScaffold(
      title: 'Pratinjau TV',
      subtitle:
          'Kanvas 1920×1080 dengan zona, tipografi, jadwal sholat, Hijriah, '
          'dan ticker yang sama seperti di TV.',
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
            _buildLiveCard(),
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
                        'Zona: header 140 · sholat 420 (kiri) · konten 16:9 · ticker 100',
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
                        'Kota lain memakai perhitungan adhan dengan parameter '
                        'Kemenag (tetap).',
                  ),
                  _Note(
                    text:
                        'Pratinjau statis mengikuti data terbaru dari database. '
                        'Kartu layar langsung menampilkan tangkapan asli TV.',
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
