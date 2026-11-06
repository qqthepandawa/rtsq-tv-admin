import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/widgets.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.session});

  final AdminSession session;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final _repo = AdminRepository();
  List<Device> _devices = const [];
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
      final devices = await _repo.fetchDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pair() async {
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
                    'Kode 6 digit tampil di layar TV saat aplikasi dibuka '
                    'pertama kali.',
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
                      counterText: '',
                    ),
                    validator: (value) =>
                        (value ?? '').replaceAll(' ', '').length == 6
                        ? null
                        : 'Kode terdiri dari 6 angka.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nama TV (opsional)',
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

  Future<void> _rename(Device device) async {
    final name = TextEditingController(text: device.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ganti nama TV', style: AdminText.h2),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nama TV'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(name.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      await _repo.renameDevice(device.id, result);
      if (!mounted) return;
      showSnack(context, 'Nama TV diperbarui.');
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  Future<void> _revoke(Device device) async {
    final ok = await confirmDialog(
      context,
      title: 'Cabut akses TV?',
      message:
          'TV "${device.name}" tidak lagi dapat memuat konten. Layar akan '
          'kembali ke mode pairing.',
      confirmLabel: 'Cabut akses',
      danger: true,
    );
    if (!ok) return;
    try {
      await _repo.revokeDevice(device.id);
      if (!mounted) return;
      showSnack(context, 'Akses TV dicabut.');
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  Future<void> _delete(Device device) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus perangkat?',
      message:
          'Baris perangkat dihapus dari database. TV perlu mendaftar ulang '
          'dan memasukkan kode baru untuk terhubung.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    try {
      await _repo.deleteDevice(device.id);
      if (!mounted) return;
      showSnack(context, 'Perangkat dihapus.');
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  Future<void> _command(Device device, String type) async {
    try {
      await _repo.createCommand(device.id, type);
      if (!mounted) return;
      showSnack(
        context,
        'Perintah "$type" masuk antrean. Dijalankan pada heartbeat berikutnya '
        '(±60 detik).',
      );
      await _load(silent: true);
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _devices.where((device) => device.isPending).toList();
    final paired = _devices.where((device) => device.isPaired).toList();
    final revoked = _devices.where((device) => device.isRevoked).toList();

    return PageScaffold(
      title: 'Perangkat',
      subtitle:
          'Pasangkan, ganti nama, kirim perintah, atau cabut akses TV. '
          'Status online berdasarkan heartbeat < 3 menit.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Muat ulang'),
        ),
        ElevatedButton.icon(
          onPressed: _pair,
          icon: const Icon(Icons.add_link, size: 18),
          label: const Text('Pasangkan TV'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) InlineError(message: _error!),
          if (_loading && _devices.isEmpty)
            const LoadingBlock(message: 'Memuat perangkat…')
          else ...[
            if (pending.isNotEmpty)
              SectionCard(
                title: 'Menunggu persetujuan (${pending.length})',
                subtitle: 'Masukkan kode di bawah lewat tombol Pasangkan TV.',
                child: Column(
                  children: [
                    for (final device in pending)
                      _DeviceRow(
                        device: device,
                        onRename: () => _rename(device),
                        onRevoke: () => _revoke(device),
                        onDelete: () => _delete(device),
                        onCommand: (type) => _command(device, type),
                      ),
                  ],
                ),
              ),
            if (pending.isNotEmpty) const SizedBox(height: 14),
            SectionCard(
              title: 'TV terpasang (${paired.length})',
              child: paired.isEmpty
                  ? EmptyState(
                      title: 'Belum ada TV terpasang',
                      message:
                          'Buka aplikasi RTSQ TV di TV untuk melihat kode '
                          'pairing.',
                      icon: Icons.tv_off_outlined,
                      action: OutlinedButton(
                        onPressed: _pair,
                        child: const Text('Pasangkan TV'),
                      ),
                    )
                  : Column(
                      children: [
                        for (final device in paired)
                          _DeviceRow(
                            device: device,
                            onRename: () => _rename(device),
                            onRevoke: () => _revoke(device),
                            onDelete: () => _delete(device),
                            onCommand: (type) => _command(device, type),
                          ),
                      ],
                    ),
            ),
            if (revoked.isNotEmpty) ...[
              const SizedBox(height: 14),
              SectionCard(
                title: 'Akses dicabut (${revoked.length})',
                child: Column(
                  children: [
                    for (final device in revoked)
                      _DeviceRow(
                        device: device,
                        onRename: () => _rename(device),
                        onRevoke: () => _revoke(device),
                        onDelete: () => _delete(device),
                        onCommand: (type) => _command(device, type),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.onRename,
    required this.onRevoke,
    required this.onDelete,
    required this.onCommand,
  });

  final Device device;
  final VoidCallback onRename;
  final VoidCallback onRevoke;
  final VoidCallback onDelete;
  final ValueChanged<String> onCommand;

  @override
  Widget build(BuildContext context) {
    final online = device.isOnline;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: online ? AdminColors.successSoft : const Color(0xFFF1F4F3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              online ? Icons.tv : Icons.tv_off_outlined,
              color: online ? AdminColors.success : AdminColors.inkSoft,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      device.name,
                      style: AdminText.label.copyWith(fontSize: 14),
                    ),
                    if (device.isPaired)
                      StatusPill(
                        label: online ? 'Online' : 'Offline',
                        tone: online ? PillTone.success : PillTone.neutral,
                        icon: Icons.circle,
                      ),
                    if (device.isPending)
                      const StatusPill(
                        label: 'Menunggu',
                        tone: PillTone.warn,
                        icon: Icons.hourglass_top,
                      ),
                    if (device.isRevoked)
                      const StatusPill(
                        label: 'Dicabut',
                        tone: PillTone.danger,
                        icon: Icons.block,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    device.model ?? 'Android TV',
                    if (device.androidVersion != null) device.androidVersion!,
                    'app ${device.appVersion ?? '—'}',
                    'terakhir ${Wib.relative(device.lastSeenAt)}',
                  ].join(' · '),
                  style: AdminText.caption,
                ),
                if (device.isPending && device.pairingCode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Kode: ${_group(device.pairingCode!)} · '
                      'kedaluwarsa ${Wib.time(device.pairingExpiresAt)}',
                      style: AdminText.label.copyWith(
                        color: AdminColors.warn,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                if (device.isPaired) ...[
                  const SizedBox(height: 3),
                  Text(
                    'penyimpanan ${bytesLabel(device.storageUsedBytes)} terpakai'
                    '${device.network == null ? '' : ' · ${device.network}'}'
                    '${device.screenState == 'content' ? '' : ' · ${device.screenState}'}',
                    style: AdminText.caption.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Aksi',
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  onRename();
                case 'revoke':
                  onRevoke();
                case 'delete':
                  onDelete();
                default:
                  onCommand(value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text('Ganti nama')),
              if (device.isPaired) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'reload',
                  child: Text('Muat ulang konten'),
                ),
                const PopupMenuItem(
                  value: 'restart_app',
                  child: Text('Mulai ulang aplikasi'),
                ),
                const PopupMenuItem(
                  value: 'screenshot',
                  child: Text('Minta tangkapan layar'),
                ),
                const PopupMenuItem(
                  value: 'sync',
                  child: Text('Sinkronkan sekarang'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'revoke',
                  child: Text('Cabut akses'),
                ),
              ],
              const PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
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
