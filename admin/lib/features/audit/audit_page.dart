import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';

class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  final _repo = AdminRepository();
  List<AuditEntry> _entries = const [];
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
      final entries = await _repo.fetchAudit(limit: 200);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Audit',
      subtitle:
          'Jejak perubahan konten, ticker, pengaturan, perangkat, dan akun. '
          'Ditulis otomatis oleh trigger database.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Muat ulang'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) InlineError(message: _error!),
          if (_loading && _entries.isEmpty)
            const LoadingBlock(message: 'Memuat audit…')
          else if (_entries.isEmpty)
            const SectionCard(
              child: EmptyState(
                title: 'Belum ada catatan audit',
                message:
                    'Catatan muncul setelah ada perubahan dari panel admin.',
                icon: Icons.history_outlined,
              ),
            )
          else
            SectionCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (final entry in _entries)
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      leading: StatusPill(
                        label: entry.action.toUpperCase(),
                        tone: switch (entry.action) {
                          'delete' => PillTone.danger,
                          'update' => PillTone.warn,
                          'insert' || 'pair' => PillTone.success,
                          _ => PillTone.neutral,
                        },
                      ),
                      title: Text(
                        '${entry.entity}'
                        '${entry.entityId == null ? '' : ' · ${entry.entityId!.substring(0, entry.entityId!.length > 8 ? 8 : entry.entityId!.length)}…'}',
                        style: AdminText.label.copyWith(color: AdminColors.ink),
                      ),
                      subtitle: Text(
                        '${Wib.dateTime(entry.createdAt)} · '
                        '${entry.actorEmail ?? 'sistem'}',
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
                            prettyJson(entry.diff),
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
}
