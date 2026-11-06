import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/session.dart';
import '../../app/widgets.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import '../preview/prayer_preview.dart';
import '../preview/tv_preview.dart';

class ContentEditorPage extends StatefulWidget {
  const ContentEditorPage({super.key, required this.session, this.contentId});

  final AdminSession session;
  final String? contentId;

  bool get isNew => contentId == null;

  @override
  State<ContentEditorPage> createState() => _ContentEditorPageState();
}

class _ContentEditorPageState extends State<ContentEditorPage> {
  final _repo = AdminRepository();
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _body = TextEditingController();
  final _student = TextEditingController();
  final _marhalah = TextEditingController();
  final _achievement = TextEditingController();
  final _duration = TextEditingController();

  String _type = 'announcement';
  String? _achievedAt;
  DateTime? _startAt;
  DateTime? _endAt;
  List<ScheduleItem> _schedule = [];
  List<MediaItem> _media = [];
  Map<String, String> _mediaUrls = {};
  int _priority = 0;
  int _sortOrder = 0;
  bool _pinned = false;
  bool _active = true;
  bool _published = false;

  SettingsRow _settings = const SettingsRow();
  List<PreviewPrayer> _prayers = const [];
  List<TickerItem> _ticker = const [];
  String? _existingId;

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _existingId = widget.contentId;
    _bootstrap();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _student.dispose();
    _marhalah.dispose();
    _achievement.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final results = await Future.wait([
        _repo.fetchSettings(),
        _repo.fetchTicker(),
        if (_existingId != null) _repo.fetchContent(_existingId!),
      ]);
      final settings = results[0] as SettingsRow;
      final prayers = await PrayerPreviewService.load(
        settings,
        Wib.toWib(Wib.now()),
      );

      ContentItem? item;
      if (_existingId != null && results.length > 2) {
        item = results[2] as ContentItem?;
      }
      if (item != null) {
        _apply(item);
      }

      if (!mounted) return;
      setState(() {
        _settings = settings;
        _prayers = prayers;
        _ticker = results[1] as List<TickerItem>;
        _loading = false;
      });
      await _resolveUrls();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorText(error);
        _loading = false;
      });
    }
  }

  void _apply(ContentItem item) {
    _type = item.type;
    _title.text = item.title;
    _body.text = item.body;
    _student.text = item.studentName ?? '';
    _marhalah.text = item.marhalah ?? '';
    _achievement.text = item.achievement ?? '';
    _duration.text = item.durationSeconds?.toString() ?? '';
    _achievedAt = item.achievedAt;
    _startAt = item.startAt;
    _endAt = item.endAt;
    _schedule = [...item.scheduleItems];
    _media = [...item.media];
    _priority = item.priority;
    _sortOrder = item.sortOrder;
    _pinned = item.pinned;
    _active = item.active;
    _published = item.isPublished;
  }

  Future<void> _resolveUrls() async {
    final urls = <String, String>{};
    for (final item in _media) {
      if (!item.type.startsWith('image')) continue;
      final url = await _repo.signedUrl(item.thumbPath ?? item.path);
      if (url != null) urls[item.path] = url;
    }
    if (mounted) setState(() => _mediaUrls = urls);
  }

  ContentItem _buildItem() {
    return ContentItem(
      id: _existingId,
      type: _type,
      title: _title.text,
      body: _body.text,
      media: _media,
      studentName: _student.text,
      marhalah: _marhalah.text,
      achievement: _achievement.text,
      achievedAt: _achievedAt,
      scheduleItems: _schedule,
      startAt: _startAt,
      endAt: _endAt,
      sortOrder: _sortOrder,
      durationSeconds: int.tryParse(_duration.text.trim()),
      priority: _priority,
      pinned: _pinned,
      active: _active,
      status: _published ? 'published' : 'draft',
    );
  }

  String get _tickerText => _ticker
      .where((item) => item.active)
      .map((item) => item.text.trim())
      .where((text) => text.isNotEmpty)
      .join('  •  ');

  String? get _previewImageUrl {
    for (final item in _media) {
      if (!item.type.startsWith('image')) continue;
      final url = _mediaUrls[item.path];
      if (url != null) return url;
    }
    return null;
  }

  Future<void> _save({bool publish = false}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startAt != null && _endAt != null && !_endAt!.isAfter(_startAt!)) {
      setState(() => _error = 'Waktu selesai harus setelah waktu mulai.');
      return;
    }
    if (publish) _published = true;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _repo.saveContent(_buildItem());
      if (!mounted) return;
      setState(() => _existingId = saved.id);
      showSnack(
        context,
        publish || saved.isPublished
            ? 'Konten tayang. TV memuatnya dalam ±60 detik.'
            : 'Draf disimpan.',
      );
      context.go('/content');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final id = _existingId;
    if (id == null) {
      context.go('/content');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Hapus konten?',
      message: 'Konten akan dihapus permanen dari panel dan TV.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    try {
      await _repo.deleteContent(id);
      if (mounted) context.go('/content');
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  Future<void> _addMedia({required bool video}) async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final media = await _repo.pickAndUpload(videoOnly: video);
      if (media == null) return;
      setState(() => _media = [..._media, media]);
      await _resolveUrls();
    } catch (error) {
      if (mounted) setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDate({required bool achieved}) async {
    final initial = achieved
        ? (DateTime.tryParse(_achievedAt ?? '') ?? DateTime.now())
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (achieved) {
        _achievedAt = Wib.isoDate(picked);
      }
    });
  }

  Future<void> _pickWindow({required bool start}) async {
    final current = start ? _startAt : _endAt;
    final initial = current != null ? Wib.toWib(current) : Wib.toWib(Wib.now());
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final wall = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _startAt = Wib.fromWib(wall);
      } else {
        _endAt = Wib.fromWib(wall);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PageScaffold(
        title: 'Konten',
        child: LoadingBlock(message: 'Menyiapkan editor…'),
      );
    }

    final wide = MediaQuery.sizeOf(context).width >= 1100;

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) InlineError(message: _error!),
        SectionCard(
          title: 'Jenis & isi',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledField(
                  label: 'Jenis konten',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in const [
                        ('announcement', 'Pengumuman', Icons.campaign_outlined),
                        (
                          'achievement',
                          'Prestasi',
                          Icons.emoji_events_outlined,
                        ),
                        ('photo', 'Foto', Icons.photo_outlined),
                        ('video', 'Video', Icons.videocam_outlined),
                        ('schedule', 'Jadwal', Icons.event_note_outlined),
                      ])
                        _TypeChip(
                          label: entry.$2,
                          icon: entry.$3,
                          selected: _type == entry.$1,
                          onTap: () => setState(() => _type = entry.$1),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Judul',
                  child: TextFormField(
                    controller: _title,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Pendaftaran Santri Baru 2026',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Judul wajib diisi.'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                LabeledField(
                  label: 'Isi / keterangan',
                  hint:
                      'Tampil di bawah judul. Gunakan kalimat singkat agar '
                      'mudah dibaca dari jauh.',
                  child: TextFormField(
                    controller: _body,
                    minLines: 3,
                    maxLines: 6,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Tuliskan informasi singkat…',
                    ),
                  ),
                ),
                if (_type == 'achievement') ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'Nama santri',
                          child: TextFormField(
                            controller: _student,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Nama lengkap',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'Marhalah',
                          child: TextFormField(
                            controller: _marhalah,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Contoh: Marhalah 2',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'Predikat',
                          child: TextFormField(
                            controller: _achievement,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Jayyid Jiddan / 7 Juz',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'Tanggal prestasi',
                          child: _DateButton(
                            value: _achievedAt,
                            onPick: () => _pickDate(achieved: true),
                            onClear: () => setState(() => _achievedAt = null),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_type == 'schedule') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Agenda', style: AdminText.label),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => setState(
                          () =>
                              _schedule = [..._schedule, const ScheduleItem()],
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Tambah agenda'),
                      ),
                    ],
                  ),
                  if (_schedule.isEmpty)
                    Text(
                      'Belum ada agenda. Tambahkan minimal satu.',
                      style: AdminText.caption,
                    ),
                  for (var i = 0; i < _schedule.length; i++)
                    _ScheduleRow(
                      key: ValueKey('schedule-$i'),
                      item: _schedule[i],
                      onChanged: (value) {
                        final next = [..._schedule];
                        next[i] = value;
                        setState(() => _schedule = next);
                      },
                      onRemove: () => setState(() {
                        final next = [..._schedule]..removeAt(i);
                        _schedule = next;
                      }),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Media',
          subtitle: _type == 'video'
              ? 'Video MP4 maksimal 60 MB. TV memutar ulang otomatis.'
              : 'Gambar dikompres ke maksimal 1920 px, JPEG kualitas 85.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_media.isEmpty)
                Text(
                  _type == 'video' ? 'Belum ada video.' : 'Belum ada gambar.',
                  style: AdminText.caption,
                ),
              for (final item in _media)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminColors.line),
                  ),
                  child: Row(
                    children: [
                      if (item.type.startsWith('image') &&
                          _mediaUrls[item.path] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            _mediaUrls[item.path]!,
                            width: 56,
                            height: 38,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const SizedBox(width: 56, height: 38),
                          ),
                        )
                      else
                        Container(
                          width: 56,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AdminColors.panel,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            item.type.startsWith('video')
                                ? Icons.videocam
                                : Icons.image,
                            size: 18,
                            color: Colors.white70,
                          ),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name.isEmpty ? item.path : item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AdminText.label,
                            ),
                            Text(
                              '${bytesLabel(item.size)} · '
                              '${item.checksum.isEmpty ? 'tanpa checksum' : 'sha256 ${item.checksum.substring(0, 10)}…'}',
                              style: AdminText.caption.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hapus dari konten',
                        onPressed: () => setState(() {
                          _media = [
                            for (final entry in _media)
                              if (entry.path != item.path) entry,
                          ];
                        }),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => _addMedia(video: _type == 'video'),
                    icon: _uploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _type == 'video'
                                ? Icons.videocam_outlined
                                : Icons.add_photo_alternate_outlined,
                            size: 18,
                          ),
                    label: Text(
                      _uploading
                          ? 'Mengunggah…'
                          : _type == 'video'
                          ? 'Pilih video'
                          : 'Pilih gambar',
                    ),
                  ),
                  if (_type != 'video')
                    OutlinedButton.icon(
                      onPressed: _uploading
                          ? null
                          : () => _addMedia(video: true),
                      icon: const Icon(Icons.videocam_outlined, size: 18),
                      label: const Text('Lampirkan video'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Penjadwalan & prioritas',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'Mulai tayang (opsional)',
                      child: _DateButton(
                        value: _startAt == null ? null : Wib.dateTime(_startAt),
                        onPick: () => _pickWindow(start: true),
                        onClear: () => setState(() => _startAt = null),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LabeledField(
                      label: 'Berhenti tayang (opsional)',
                      child: _DateButton(
                        value: _endAt == null ? null : Wib.dateTime(_endAt),
                        onPick: () => _pickWindow(start: false),
                        onClear: () => setState(() => _endAt = null),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: LabeledField(
                      label: 'Prioritas ($_priority)',
                      hint: 'Angka lebih besar tampil lebih dulu.',
                      child: Slider(
                        value: _priority.toDouble().clamp(0, 10),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: '$_priority',
                        onChanged: (value) =>
                            setState(() => _priority = value.round()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: LabeledField(
                      label: 'Durasi slide (detik)',
                      child: TextFormField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Ikuti pengaturan',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sematkan di urutan teratas'),
                subtitle: const Text(
                  'Konten bersemat selalu didahulukan dari prioritas.',
                ),
                value: _pinned,
                onChanged: (value) => setState(() => _pinned = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                subtitle: const Text(
                  'Nonaktifkan untuk menyembunyikan tanpa menghapus.',
                ),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tayang di TV'),
                subtitle: const Text('Matikan untuk menyimpan sebagai draf.'),
                value: _published,
                onChanged: (value) => setState(() => _published = value),
              ),
            ],
          ),
        ),
      ],
    );

    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: 'Pratinjau 16:9',
          subtitle: 'Perkiraan tampilan di TV. Waktu memakai WIB.',
          child: TvPreview(
            content: _buildItem(),
            settings: _settings,
            prayers: _prayers,
            tickerText: _tickerText,
            imageUrl: _previewImageUrl,
            slideCount: 1,
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Ringkasan',
          child: Column(
            children: [
              _SummaryRow(label: 'Jenis', value: _buildItem().typeLabel),
              _SummaryRow(
                label: 'Status',
                value: _published ? 'Tayang' : 'Draf',
              ),
              _SummaryRow(label: 'Media', value: '${_media.length} berkas'),
              _SummaryRow(label: 'Agenda', value: '${_schedule.length} item'),
            ],
          ),
        ),
      ],
    );

    return PageScaffold(
      title: widget.isNew ? 'Konten baru' : 'Ubah konten',
      subtitle:
          'Perubahan langsung tersedia untuk TV setelah disimpan dan '
          'berstatus tayang.',
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => context.go('/content'),
          child: const Text('Batal'),
        ),
        if (!widget.isNew)
          OutlinedButton.icon(
            onPressed: _saving ? null : _delete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Hapus'),
          ),
        OutlinedButton(
          onPressed: _saving ? null : () => _save(),
          child: const Text('Simpan'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : () => _save(publish: true),
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.publish, size: 18),
          label: Text(_saving ? 'Menyimpan…' : 'Simpan & tayangkan'),
        ),
      ],
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: form),
                const SizedBox(width: 16),
                SizedBox(width: 420, child: preview),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [preview, const SizedBox(height: 16), form],
            ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AdminColors.tealSoft : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AdminColors.teal : AdminColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AdminColors.teal : AdminColors.inkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AdminText.label.copyWith(
                color: selected ? AdminColors.teal : AdminColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AdminColors.line),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AdminColors.inkSoft,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value ?? 'Pilih tanggal',
                style: AdminText.body.copyWith(
                  color: value == null ? AdminColors.inkSoft : AdminColors.ink,
                ),
              ),
            ),
            if (value != null)
              InkWell(
                onTap: onClear,
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AdminColors.inkSoft,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatefulWidget {
  const _ScheduleRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final ScheduleItem item;
  final ValueChanged<ScheduleItem> onChanged;
  final VoidCallback onRemove;

  @override
  State<_ScheduleRow> createState() => _ScheduleRowState();
}

class _ScheduleRowState extends State<_ScheduleRow> {
  late final _title = TextEditingController(text: widget.item.title);
  late final _date = TextEditingController(text: widget.item.date);
  late final _time = TextEditingController(text: widget.item.time);
  late final _place = TextEditingController(text: widget.item.place);

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _time.dispose();
    _place.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(
    ScheduleItem(
      title: _title.text,
      date: _date.text,
      time: _time.text,
      place: _place.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _title,
                  onChanged: (_) => _emit(),
                  decoration: const InputDecoration(
                    labelText: 'Nama kegiatan',
                    hintText: 'Kajian Tahsin',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Hapus agenda',
                onPressed: widget.onRemove,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _date,
                  onChanged: (_) => _emit(),
                  decoration: const InputDecoration(
                    labelText: 'Tanggal',
                    hintText: '2026-11-09',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _time,
                  onChanged: (_) => _emit(),
                  decoration: const InputDecoration(
                    labelText: 'Waktu',
                    hintText: '08.30 WIB',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _place,
                  onChanged: (_) => _emit(),
                  decoration: const InputDecoration(
                    labelText: 'Tempat',
                    hintText: 'Aula RTSQ',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AdminText.caption)),
          Text(value, style: AdminText.label),
        ],
      ),
    );
  }
}
