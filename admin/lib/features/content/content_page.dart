import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/session.dart';
import '../../app/widgets.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import '../preview/prayer_preview.dart';
import '../preview/tv_preview.dart';

class ContentPage extends StatefulWidget {
  const ContentPage({super.key, required this.session});

  final AdminSession session;

  @override
  State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  final _repo = AdminRepository();
  final _search = TextEditingController();

  List<ContentItem> _contents = const [];
  List<TickerItem> _ticker = const [];
  SettingsRow _settings = const SettingsRow();
  List<PreviewPrayer> _prayers = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
      if (!mounted) return;
      setState(() {
        _contents = results[0] as List<ContentItem>;
        _settings = settings;
        _ticker = results[2] as List<TickerItem>;
        _prayers = prayers;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ContentItem> get _visible {
    final query = _search.text.trim().toLowerCase();
    return _contents.where((item) {
      if (_filter == 'published' && !item.isPublished) return false;
      if (_filter == 'draft' && item.isPublished) return false;
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.body.toLowerCase().contains(query);
    }).toList();
  }

  String get _tickerText {
    final now = Wib.now();
    return _ticker
        .where((item) {
          if (!item.active) return false;
          if (item.startAt != null && now.isBefore(item.startAt!)) return false;
          if (item.endAt != null && now.isAfter(item.endAt!)) return false;
          return true;
        })
        .map((item) => item.text.trim())
        .where((text) => text.isNotEmpty)
        .join('  •  ');
  }

  Future<void> _preview(ContentItem item) async {
    String? imageUrl;
    for (final media in item.media) {
      if (!media.type.startsWith('image')) continue;
      imageUrl = await _repo.signedUrl(media.thumbPath ?? media.path);
      if (imageUrl != null) break;
    }
    if (!mounted) return;
    final slideIndex = _contents.indexOf(item);
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Pratinjau TV', style: AdminText.h2)),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TvPreview(
                  content: item,
                  settings: _settings,
                  prayers: _prayers,
                  tickerText: _tickerText,
                  imageUrl: imageUrl,
                  slideIndex: slideIndex < 0 ? 0 : slideIndex,
                  slideCount: _contents.isEmpty ? 1 : _contents.length,
                  animateTicker: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _togglePublish(ContentItem item) async {
    try {
      await _repo.setContentStatus(
        item.id!,
        item.isPublished ? 'draft' : 'published',
      );
      if (!mounted) return;
      showSnack(
        context,
        item.isPublished
            ? 'Konten dipindah ke draf. TV menghapusnya pada sync berikutnya.'
            : 'Konten tayang. TV memuatnya dalam ±60 detik.',
      );
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  Future<void> _togglePin(ContentItem item) async {
    try {
      await _repo.updateContentPin(item.id!, !item.pinned);
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  Future<void> _move(ContentItem item, int delta) async {
    final list = [..._contents];
    final index = list.indexWhere((entry) => entry.id == item.id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= list.length) return;
    final other = list[target];
    try {
      await _repo.updateContentSort(item.id!, target * 10);
      await _repo.updateContentSort(other.id!, index * 10);
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  Future<void> _delete(ContentItem item) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus konten?',
      message:
          '"${item.title}" akan dihapus permanen dari panel dan TV. '
          'Media yang sudah diunggah tidak ikut terhapus otomatis.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    try {
      await _repo.deleteContent(item.id!);
      if (!mounted) return;
      showSnack(context, 'Konten dihapus.');
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return PageScaffold(
      title: 'Konten',
      subtitle:
          'Konten berstatus "Tayang" dan aktif langsung dikirim ke TV. '
          'Urutan menentukan giliran slide.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Muat ulang'),
        ),
        ElevatedButton.icon(
          onPressed: () => context.go('/content/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah konten'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) InlineError(message: _error!),
          SectionCard(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Cari judul atau isi…',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
                _FilterChip(
                  label: 'Semua (${_contents.length})',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                _FilterChip(
                  label:
                      'Tayang (${_contents.where((c) => c.isPublished).length})',
                  selected: _filter == 'published',
                  onTap: () => setState(() => _filter = 'published'),
                ),
                _FilterChip(
                  label:
                      'Draf (${_contents.where((c) => !c.isPublished).length})',
                  selected: _filter == 'draft',
                  onTap: () => setState(() => _filter = 'draft'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_loading && _contents.isEmpty)
            const LoadingBlock(message: 'Memuat konten…')
          else if (visible.isEmpty)
            SectionCard(
              child: EmptyState(
                title: _contents.isEmpty
                    ? 'Belum ada konten'
                    : 'Tidak ada konten yang cocok',
                message: _contents.isEmpty
                    ? 'Mulai dengan pengumuman singkat. TV akan menampilkannya '
                          'sebagai slide.'
                    : 'Ubah kata kunci atau filter.',
                icon: Icons.article_outlined,
                action: _contents.isEmpty
                    ? ElevatedButton.icon(
                        onPressed: () => context.go('/content/new'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah konten'),
                      )
                    : null,
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < visible.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ContentTile(
                      item: visible[i],
                      position: _contents.indexOf(visible[i]) + 1,
                      onEdit: () => context.go('/content/${visible[i].id}'),
                      onPreview: () => _preview(visible[i]),
                      onPublish: () => _togglePublish(visible[i]),
                      onPin: () => _togglePin(visible[i]),
                      onDelete: () => _delete(visible[i]),
                      onUp: i > 0 ? () => _move(visible[i], -1) : null,
                      onDown: i < visible.length - 1
                          ? () => _move(visible[i], 1)
                          : null,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AdminColors.tealSoft : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AdminColors.teal : AdminColors.line,
          ),
        ),
        child: Text(
          label,
          style: AdminText.caption.copyWith(
            color: selected ? AdminColors.teal : AdminColors.inkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ContentTile extends StatelessWidget {
  const _ContentTile({
    required this.item,
    required this.position,
    required this.onEdit,
    required this.onPreview,
    required this.onPublish,
    required this.onPin,
    required this.onDelete,
    this.onUp,
    this.onDown,
  });

  final ContentItem item;
  final int position;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onPublish;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                position.toString().padLeft(2, '0'),
                style: AdminText.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusPill(label: item.typeLabel, tone: PillTone.info),
                      StatusPill(
                        label: item.isPublished ? 'Tayang' : 'Draf',
                        tone: item.isPublished
                            ? PillTone.success
                            : PillTone.neutral,
                        icon: item.isPublished
                            ? Icons.check_circle_outline
                            : Icons.edit_note,
                      ),
                      if (item.pinned)
                        const StatusPill(
                          label: 'Disematkan',
                          tone: PillTone.warn,
                          icon: Icons.push_pin_outlined,
                        ),
                      if (!item.active)
                        const StatusPill(
                          label: 'Nonaktif',
                          tone: PillTone.danger,
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  InkWell(
                    onTap: onEdit,
                    child: Text(
                      item.title.trim().isEmpty
                          ? '(Tanpa judul)'
                          : item.title.trim(),
                      style: AdminText.h2.copyWith(fontSize: 17),
                    ),
                  ),
                  if (item.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.body.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.caption.copyWith(fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    [
                      'prioritas ${item.priority}',
                      if (item.startAt != null || item.endAt != null)
                        '${Wib.dateTime(item.startAt)} → '
                            '${Wib.dateTime(item.endAt)}',
                      'diubah ${Wib.relative(item.updatedAt)}',
                    ].join(' · '),
                    style: AdminText.caption.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Aksi',
              onSelected: (value) {
                switch (value) {
                  case 'up':
                    onUp?.call();
                  case 'down':
                    onDown?.call();
                  case 'preview':
                    onPreview();
                  case 'publish':
                    onPublish();
                  case 'pin':
                    onPin();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'preview',
                  child: Text('Pratinjau 16:9'),
                ),
                PopupMenuItem(
                  value: 'publish',
                  child: Text(
                    item.isPublished ? 'Pindah ke draf' : 'Tayangkan',
                  ),
                ),
                PopupMenuItem(
                  value: 'pin',
                  child: Text(item.pinned ? 'Lepas sematan' : 'Sematkan'),
                ),
                PopupMenuItem(
                  value: 'up',
                  enabled: onUp != null,
                  child: const Text('Naikkan urutan'),
                ),
                PopupMenuItem(
                  value: 'down',
                  enabled: onDown != null,
                  child: const Text('Turunkan urutan'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
            IconButton(
              tooltip: 'Ubah',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
