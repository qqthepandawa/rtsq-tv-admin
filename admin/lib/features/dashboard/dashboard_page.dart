import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/session.dart';
import '../../app/widgets.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.session});

  final AdminSession session;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _repo = AdminRepository();

  List<Device> _devices = const [];
  Map<String, int> _counts = const {};
  SettingsRow? _settings;
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.fetchDevices(),
        _repo.fetchCounts(),
        _repo.fetchSettings(),
      ]);
      if (!mounted) return;
      setState(() {
        _devices = results[0] as List<Device>;
        _counts = results[1] as Map<String, int>;
        _settings = results[2] as SettingsRow;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPairDialog() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var busy = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Pasangkan TV', style: AdminText.h2),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Masukkan 6 digit yang tampil di layar TV, atau buka '
                    'tautan QR dari TV.',
                    style: AdminText.caption,
                  ),
                  const SizedBox(height: 14),
                  if (error != null) InlineError(message: error!),
                  TextFormField(
                    controller: code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Kode pairing',
                      hintText: '123456',
                      counterText: '',
                    ),
                    validator: (value) {
                      if ((value ?? '').replaceAll(' ', '').length != 6) {
                        return 'Kode terdiri dari 6 angka.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nama TV (opsional)',
                      hintText: 'TV Lobby RTSQ',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await _repo.pairDevice(code.text, name: name.text);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        if (mounted) {
                          showSnack(this.context, 'TV berhasil dipasangkan.');
                          await _load();
                        }
                      } catch (e) {
                        setDialogState(() {
                          busy = false;
                          error = errorText(e);
                        });
                      }
                    },
              child: Text(busy ? 'Memproses…' : 'Pasangkan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendCommand(Device device, String type) async {
    try {
      await _repo.createCommand(device.id, type);
      if (mounted) {
        showSnack(
          context,
          'Perintah "$type" dikirim. TV menjalankan saat heartbeat berikutnya.',
        );
      }
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _devices.where((d) => d.isPending).toList();
    final paired = _devices.where((d) => d.isPaired).toList();
    final online = paired.where((d) => d.isOnline).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: PageScaffold(
        title: 'Dasbor',
        subtitle:
            'Selamat datang, ${widget.session.profile?.name ?? 'Admin'}. '
            'Perubahan konten langsung dikirim ke TV pada sinkronisasi berikutnya.',
        actions: [
          if (widget.session.isSuper)
            OutlinedButton.icon(
              onPressed: _openPairDialog,
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('Pasangkan TV'),
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
            if (_loading && _devices.isEmpty)
              const LoadingBlock()
            else ...[
              ResponsiveGrid(
                children: [
                  StatCard(
                    label: 'TV online',
                    value: '$online / ${paired.length}',
                    helper: 'Heartbeat < 3 menit',
                    icon: Icons.connected_tv,
                    tone: online > 0 ? StatTone.teal : StatTone.danger,
                  ),
                  StatCard(
                    label: 'Konten tayang',
                    value: '${_counts['published'] ?? 0}',
                    helper: '${_counts['draft'] ?? 0} draf/arsip',
                    icon: Icons.article,
                    tone: StatTone.gold,
                  ),
                  StatCard(
                    label: 'Ticker aktif',
                    value: '${_counts['ticker'] ?? 0}',
                    helper: 'Teks berjalan',
                    icon: Icons.text_fields,
                    tone: StatTone.dark,
                  ),
                  StatCard(
                    label: 'Durasi slide',
                    value: '${_settings?.slideDurationSeconds ?? 10} dtk',
                    helper: 'Dapat diubah di Pengaturan',
                    icon: Icons.timer_outlined,
                    tone: StatTone.teal,
                  ),
                ],
              ),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionCard(
                  title: 'Menunggu persetujuan',
                  subtitle:
                      'Cocokkan kode di bawah dengan yang tampil di layar TV.',
                  actions: [
                    if (widget.session.isSuper)
                      TextButton(
                        onPressed: _openPairDialog,
                        child: const Text('Pasangkan'),
                      ),
                  ],
                  child: Column(
                    children: [
                      for (final device in pending)
                        _PendingTile(device: device),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SectionCard(
                title: 'Perangkat TV',
                subtitle:
                    'Status diperbarui otomatis setiap 30 detik. '
                    'Perintah dikirim lewat antrean heartbeat.',
                actions: [
                  IconButton(
                    tooltip: 'Muat ulang',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
                child: paired.isEmpty
                    ? EmptyState(
                        title: 'Belum ada TV terpasang',
                        message:
                            'Buka aplikasi di TV, lalu masukkan kode pairing '
                            'yang tampil di layar.',
                        icon: Icons.tv_off_outlined,
                        action: widget.session.isSuper
                            ? OutlinedButton(
                                onPressed: _openPairDialog,
                                child: const Text('Pasangkan TV'),
                              )
                            : null,
                      )
                    : Column(
                        children: [
                          for (final device in paired)
                            _DeviceTile(
                              device: device,
                              canManage: widget.session.isSuper,
                              onCommand: (type) => _sendCommand(device, type),
                            ),
                        ],
                      ),
              ),
              if (pending.isEmpty && paired.isEmpty) ...[
                const SizedBox(height: 18),
                SectionCard(
                  title: 'Langkah pertama',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Step(
                        number: '1',
                        text:
                            'Buka aplikasi RTSQ TV di TV. Layar pairing '
                            'menampilkan kode 6 digit.',
                      ),
                      _Step(
                        number: '2',
                        text:
                            'Tekan "Pasangkan TV", masukkan kode, lalu '
                            'setujui.',
                      ),
                      _Step(
                        number: '3',
                        text:
                            'Tambahkan pengumuman pertama. TV akan memuat '
                            'dalam ±60 detik.',
                      ),
                    ],
                  ),
                ),
              ],
              if (_settings != null) ...[
                const SizedBox(height: 18),
                SectionCard(
                  title: 'Identitas layar',
                  child: Wrap(
                    spacing: 32,
                    runSpacing: 12,
                    children: [
                      _Meta(label: 'Nama lembaga', value: _settings!.orgName),
                      _Meta(label: 'Kota', value: _settings!.city),
                      _Meta(
                        label: 'Koordinat',
                        value:
                            '${_settings!.latitude.toStringAsFixed(4)}, '
                            '${_settings!.longitude.toStringAsFixed(4)}',
                      ),
                      _Meta(
                        label: 'Versi pengaturan',
                        value: 'v${_settings!.version}',
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.warnSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: AdminText.label.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.model ?? 'Android TV'} · '
                  'kedaluwarsa ${Wib.time(device.pairingExpiresAt)}',
                  style: AdminText.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _group(device.pairingCode ?? '------'),
              style: const TextStyle(
                fontFamily: AdminText.family,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AdminColors.warn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _group(String code) {
    if (code.length != 6) return code;
    return '${code.substring(0, 3)} ${code.substring(3)}';
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.canManage,
    required this.onCommand,
  });

  final Device device;
  final bool canManage;
  final ValueChanged<String> onCommand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: device.isOnline
                  ? AdminColors.successSoft
                  : const Color(0xFFF1F4F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              device.isOnline ? Icons.tv : Icons.tv_off_outlined,
              color: device.isOnline
                  ? AdminColors.success
                  : AdminColors.inkSoft,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      device.name,
                      style: AdminText.label.copyWith(fontSize: 14),
                    ),
                    StatusPill(
                      label: device.isOnline ? 'Online' : 'Offline',
                      tone: device.isOnline
                          ? PillTone.success
                          : PillTone.neutral,
                      icon: Icons.circle,
                    ),
                    StatusPill(label: device.screenState, tone: PillTone.info),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${device.model ?? 'Android TV'} · '
                  'app ${device.appVersion ?? '—'} · '
                  'terakhir ${Wib.relative(device.lastSeenAt)}',
                  style: AdminText.caption,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Perintah',
            onSelected: onCommand,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reload',
                child: Text('Muat ulang konten'),
              ),
              if (canManage) ...[
                const PopupMenuItem(
                  value: 'restart_app',
                  child: Text('Mulai ulang app'),
                ),
                const PopupMenuItem(
                  value: 'screenshot',
                  child: Text('Minta tangkapan layar'),
                ),
                const PopupMenuItem(
                  value: 'sync',
                  child: Text('Sinkronkan sekarang'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AdminColors.tealSoft,
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: AdminText.family,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AdminColors.teal,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AdminText.body)),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminText.caption),
        const SizedBox(height: 2),
        Text(value, style: AdminText.label.copyWith(color: AdminColors.ink)),
      ],
    );
  }
}
