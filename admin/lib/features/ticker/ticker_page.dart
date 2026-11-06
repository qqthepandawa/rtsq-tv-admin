import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/session.dart';
import '../../app/widgets.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';

class TickerPage extends StatefulWidget {
  const TickerPage({super.key, required this.session});

  final AdminSession session;

  @override
  State<TickerPage> createState() => _TickerPageState();
}

class _TickerPageState extends State<TickerPage> {
  final _repo = AdminRepository();
  List<TickerItem> _items = const [];
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
      final items = await _repo.fetchTicker();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([TickerItem? item]) async {
    final text = TextEditingController(text: item?.text ?? '');
    final order = TextEditingController(
      text: (item?.sortOrder ?? (_items.length * 10)).toString(),
    );
    var active = item?.active ?? true;
    DateTime? startAt = item?.startAt;
    DateTime? endAt = item?.endAt;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            item == null ? 'Ticker baru' : 'Ubah ticker',
            style: AdminText.h2,
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (error != null) InlineError(message: error!),
                  TextField(
                    controller: text,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Teks berjalan',
                      hintText:
                          'Contoh: Libur Idul Adha 1448 H — kegiatan dimulai '
                          'pukul 07.00 WIB.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: order,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Urutan',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Aktif'),
                          value: active,
                          onChanged: (value) =>
                              setDialogState(() => active = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Jadwal tayang (opsional)', style: AdminText.label),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _WindowButton(
                          label: 'Mulai',
                          value: startAt,
                          onPick: () async {
                            final picked = await _pickDateTime(
                              context,
                              startAt,
                            );
                            if (picked != null) {
                              setDialogState(() => startAt = picked);
                            }
                          },
                          onClear: () => setDialogState(() => startAt = null),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WindowButton(
                          label: 'Selesai',
                          value: endAt,
                          onPick: () async {
                            final picked = await _pickDateTime(context, endAt);
                            if (picked != null) {
                              setDialogState(() => endAt = picked);
                            }
                          },
                          onClear: () => setDialogState(() => endAt = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Kosongkan jadwal agar teks selalu tampil.',
                    style: AdminText.caption,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (text.text.trim().isEmpty) {
                  setDialogState(() => error = 'Teks tidak boleh kosong.');
                  return;
                }
                if (startAt != null &&
                    endAt != null &&
                    !endAt!.isAfter(startAt!)) {
                  setDialogState(
                    () => error = 'Waktu selesai harus setelah waktu mulai.',
                  );
                  return;
                }
                try {
                  await _repo.saveTicker(
                    TickerItem(
                      id: item?.id,
                      text: text.text,
                      startAt: startAt,
                      endAt: endAt,
                      sortOrder: int.tryParse(order.text) ?? 0,
                      active: active,
                    ),
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  if (mounted) {
                    showSnack(this.context, 'Ticker disimpan.');
                    await _load();
                  }
                } catch (e) {
                  setDialogState(() => error = errorText(e));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime? current,
  ) async {
    final initial = current == null ? Wib.toWib(Wib.now()) : Wib.toWib(current);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return Wib.fromWib(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Future<void> _delete(TickerItem item) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus ticker?',
      message: '"${item.text}" akan dihapus dari TV.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    try {
      await _repo.deleteTicker(item.id!);
      if (!mounted) return;
      showSnack(context, 'Ticker dihapus.');
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  Future<void> _toggle(TickerItem item) async {
    try {
      await _repo.saveTicker(
        TickerItem(
          id: item.id,
          text: item.text,
          startAt: item.startAt,
          endAt: item.endAt,
          sortOrder: item.sortOrder,
          active: !item.active,
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = Wib.now();
    final preview = _items
        .where((item) => item.active)
        .map((item) => item.text.trim())
        .where((text) => text.isNotEmpty)
        .join('  •  ');

    return PageScaffold(
      title: 'Ticker',
      subtitle:
          'Teks berjalan di bawah layar. Urutan kecil tampil lebih dahulu.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Muat ulang'),
        ),
        ElevatedButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ticker baru'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) InlineError(message: _error!),
          SectionCard(
            title: 'Pratinjau baris',
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AdminColors.panel,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC9AE5C),
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(8),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'INFO',
                        style: TextStyle(
                          fontFamily: AdminText.family,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Color(0xFF07110E),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        preview.isEmpty ? 'Belum ada ticker aktif.' : preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AdminText.family,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_loading && _items.isEmpty)
            const LoadingBlock(message: 'Memuat ticker…')
          else if (_items.isEmpty)
            SectionCard(
              child: EmptyState(
                title: 'Belum ada ticker',
                message:
                    'Tambahkan satu kalimat informasi. Teks akan berjalan '
                    'di bagian bawah layar TV.',
                icon: Icons.text_fields_outlined,
                action: ElevatedButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ticker baru'),
                ),
              ),
            )
          else
            SectionCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (final item in _items)
                    ListTile(
                      leading: Switch(
                        value: item.active,
                        onChanged: (_) => _toggle(item),
                      ),
                      title: Text(
                        item.text,
                        style: AdminText.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: item.active
                              ? AdminColors.ink
                              : AdminColors.inkSoft,
                        ),
                      ),
                      subtitle: Text(
                        [
                          'urutan ${item.sortOrder}',
                          if (item.startAt != null)
                            'mulai ${Wib.dateTime(item.startAt)}',
                          if (item.endAt != null)
                            'sampai ${Wib.dateTime(item.endAt)}',
                          if (item.startAt != null &&
                              now.isBefore(item.startAt!))
                            'belum tampil',
                          if (item.endAt != null && now.isAfter(item.endAt!))
                            'sudah lewat',
                        ].join(' · '),
                        style: AdminText.caption,
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Ubah',
                            onPressed: () => _edit(item),
                            icon: const Icon(Icons.edit_outlined, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Hapus',
                            onPressed: () => _delete(item),
                            icon: const Icon(Icons.delete_outline, size: 20),
                          ),
                        ],
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

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AdminColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AdminText.caption.copyWith(fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    value == null ? 'Kapan saja' : Wib.dateTime(value),
                    style: AdminText.label,
                  ),
                ],
              ),
            ),
            if (value != null)
              InkWell(
                onTap: onClear,
                child: const Icon(
                  Icons.close,
                  size: 15,
                  color: AdminColors.inkSoft,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
