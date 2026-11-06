import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/widgets.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key, required this.session});

  final AdminSession session;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final _repo = AdminRepository();
  List<LogEntry> _logs = const [];
  bool _loading = true;
  String? _error;
  String _level = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final logs = await _repo.fetchLogs(
        level: _level == 'all' ? null : _level,
      );
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _purge() async {
    final ok = await confirmDialog(
      context,
      title: 'Bersihkan log lama?',
      message:
          'Log lebih tua dari 30 hari dan undangan kedaluwarsa akan dihapus.',
      confirmLabel: 'Bersihkan',
    );
    if (!ok) return;
    try {
      await _repo.purgeLogs();
      if (!mounted) return;
      showSnack(context, 'Log lama dibersihkan.');
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Log perangkat',
      subtitle: 'Laporan dari TV (info, peringatan, error). Retensi 30 hari.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Muat ulang'),
        ),
        if (widget.session.isSuper)
          OutlinedButton.icon(
            onPressed: _purge,
            icon: const Icon(Icons.cleaning_services_outlined, size: 18),
            label: const Text('Bersihkan log lama'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) InlineError(message: _error!),
          SectionCard(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const [
                  ('all', 'Semua'),
                  ('info', 'Info'),
                  ('warn', 'Peringatan'),
                  ('error', 'Error'),
                ])
                  ChoiceChip(
                    label: Text(entry.$2),
                    selected: _level == entry.$1,
                    onSelected: (_) {
                      setState(() => _level = entry.$1);
                      _load();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_loading && _logs.isEmpty)
            const LoadingBlock(message: 'Memuat log…')
          else if (_logs.isEmpty)
            SectionCard(
              child: EmptyState(
                title: 'Belum ada log',
                message:
                    'TV akan mengirim log setelah fitur pelaporan aktif '
                    '(Fase 2b).',
                icon: Icons.receipt_long_outlined,
              ),
            )
          else
            SectionCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (final log in _logs)
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      leading: _levelPill(log.level),
                      title: Text(
                        log.message,
                        style: AdminText.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${Wib.dateTime(log.createdAt)} · '
                        '${log.deviceName ?? 'perangkat'}',
                        style: AdminText.caption,
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AdminColors.bg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            prettyJson(log.context),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _levelPill(String level) {
    return switch (level) {
      'error' => const StatusPill(label: 'ERROR', tone: PillTone.danger),
      'warn' => const StatusPill(label: 'WARN', tone: PillTone.warn),
      _ => const StatusPill(label: 'INFO', tone: PillTone.info),
    };
  }
}
