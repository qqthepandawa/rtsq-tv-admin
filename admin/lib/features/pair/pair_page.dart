import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/session.dart';
import '../../app/widgets.dart';
import '../../core/theme.dart';
import '../../data/admin_repository.dart';
import '../auth/login_page.dart';

class PairPage extends StatefulWidget {
  const PairPage({super.key, required this.session, this.code});

  final AdminSession session;
  final String? code;

  @override
  State<PairPage> createState() => _PairPageState();
}

class _PairPageState extends State<PairPage> {
  final _repo = AdminRepository();
  final _manual = TextEditingController();

  bool _busy = false;
  bool _done = false;
  String? _error;

  String get _code => (widget.code ?? _manual.text).replaceAll(' ', '').trim();

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final code = _code;
    if (code.length != 6) {
      setState(() => _error = 'Kode pairing terdiri dari 6 angka.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.pairDevice(code);
      if (!mounted) return;
      setState(() {
        _done = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        final signedIn = widget.session.canUsePanel;

        return Scaffold(
          backgroundColor: AdminColors.bg,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: !signedIn
                    ? Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Image.asset(
                              'assets/brand/rtsq_trim.png',
                              height: 42,
                            ),
                          ),
                          if (widget.code != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AdminColors.panel,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Kode TV: ${widget.code}',
                                style: const TextStyle(
                                  fontFamily: AdminText.family,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                          LoginCard(
                            session: widget.session,
                            title: 'Masuk untuk memasangkan TV',
                            subtitle:
                                'Persetujuan perangkat memerlukan akun admin '
                                'RTSQ.',
                            onSignedIn: () => setState(() {}),
                          ),
                        ],
                      )
                    : _done
                    ? _SuccessCard(onOpenDevices: () => context.go('/devices'))
                    : _ConfirmCard(
                        code: _code,
                        manual: _manual,
                        error: _error,
                        busy: _busy,
                        hasCodeFromLink: widget.code != null,
                        onChanged: () => setState(() {}),
                        onConfirm: _confirm,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    required this.code,
    required this.manual,
    required this.error,
    required this.busy,
    required this.hasCodeFromLink,
    required this.onChanged,
    required this.onConfirm,
  });

  final String code;
  final TextEditingController manual;
  final String? error;
  final bool busy;
  final bool hasCodeFromLink;
  final VoidCallback onChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final display = code.length == 6
        ? '${code.substring(0, 3)} ${code.substring(3)}'
        : '— — —';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('assets/brand/rtsq_trim.png', height: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pasangkan TV',
                    style: AdminText.title.copyWith(fontSize: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pastikan kode di layar TV sama dengan kode di bawah. Setelah '
              'disetujui, TV langsung memuat konten.',
              style: AdminText.caption,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              InlineError(message: error!),
            ],
            const SizedBox(height: 18),
            if (!hasCodeFromLink) ...[
              LabeledField(
                label: 'Kode dari layar TV',
                child: TextField(
                  controller: manual,
                  autofocus: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AdminText.family,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                  ),
                  decoration: const InputDecoration(counterText: ''),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AdminColors.panel,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                display,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AdminText.family,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: busy ? null : onConfirm,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.link),
                label: Text(busy ? 'Memasangkan…' : 'Setujui & pasangkan'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Hanya lakukan ini bila Anda mengenali perangkat di lokasi '
                'RTSQ.',
                textAlign: TextAlign.center,
                style: AdminText.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.onOpenDevices});

  final VoidCallback onOpenDevices;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AdminColors.successSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 34,
                color: AdminColors.success,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'TV berhasil dipasangkan',
              style: AdminText.title.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Layar TV akan beralih ke konten dalam beberapa detik. '
              'Tambahkan pengumuman untuk melihatnya di TV.',
              textAlign: TextAlign.center,
              style: AdminText.body,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onOpenDevices,
                  child: const Text('Lihat perangkat'),
                ),
                ElevatedButton(
                  onPressed: () => context.go('/content/new'),
                  child: const Text('Tambah konten'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
