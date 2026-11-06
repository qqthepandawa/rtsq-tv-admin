import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/widgets.dart';
import '../../core/theme.dart';
import '../../data/admin_repository.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.session});

  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final form = Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: LoginCard(session: session),
              ),
            ),
          );

          if (!wide) {
            return SingleChildScrollView(
              child: Column(children: [const _BrandPanel(compact: true), form]),
            );
          }

          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(
                flex: 4,
                child: ColoredBox(color: AdminColors.bg, child: form),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Kartu masuk/daftar yang juga dipakai halaman `/pair`.
class LoginCard extends StatefulWidget {
  const LoginCard({
    super.key,
    required this.session,
    this.title,
    this.subtitle,
    this.onSignedIn,
  });

  final AdminSession session;
  final String? title;
  final String? subtitle;
  final VoidCallback? onSignedIn;

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_register) {
        final active = await widget.session.signUp(
          _email.text,
          _password.text,
          name: _name.text,
        );
        if (!active) {
          setState(() {
            _notice =
                'Akun dibuat. Buka tautan konfirmasi di email, lalu masuk.';
            _register = false;
          });
          return;
        }
      } else {
        await widget.session.signIn(_email.text, _password.text);
      }
      if (!mounted) return;
      final issue = widget.session.accessIssue;
      if (issue != null) {
        setState(() => _error = issue);
        return;
      }
      widget.onSignedIn?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Isi email dulu untuk mengirim tautan reset.');
      return;
    }
    try {
      await widget.session.repo.resetPassword(email);
      if (!mounted) return;
      setState(() => _notice = 'Tautan reset sandi dikirim ke $email.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title ?? (_register ? 'Daftar admin' : 'Masuk panel'),
                style: AdminText.title.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle ??
                    (_register
                        ? 'Gunakan email yang sudah diundang admin utama.'
                        : 'Kelola konten RTSQ TV dari HP atau komputer.'),
                style: AdminText.caption,
              ),
              const SizedBox(height: 20),
              if (_error != null) InlineError(message: _error!),
              if (_notice != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminColors.successSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _notice!,
                    style: AdminText.body.copyWith(color: AdminColors.success),
                  ),
                ),
              if (_register)
                LabeledField(
                  label: 'Nama',
                  child: TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Nama lengkap'),
                  ),
                ),
              if (_register) const SizedBox(height: 14),
              LabeledField(
                label: 'Email',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(hintText: 'nama@rtsq.id'),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (!text.contains('@') || !text.contains('.')) {
                      return 'Email belum valid.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: 'Sandi',
                child: TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _busy ? null : _submit(),
                  decoration: InputDecoration(
                    hintText: 'Minimal 6 karakter',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Tampilkan sandi' : 'Sembunyikan',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').length < 6) {
                      return 'Sandi minimal 6 karakter.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_register ? Icons.person_add_alt : Icons.login),
                  label: Text(_register ? 'Daftar' : 'Masuk'),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _register = !_register;
                              _error = null;
                              _notice = null;
                            }),
                      child: Text(
                        _register
                            ? 'Sudah punya akun? Masuk'
                            : 'Belum punya akun? Daftar',
                      ),
                    ),
                  ),
                  if (!_register)
                    TextButton(
                      onPressed: _busy ? null : _resetPassword,
                      child: const Text('Lupa sandi?'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.goldSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AdminColors.gold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Admin pertama dibuat lewat SQL bootstrap di '
                        'supabase/README.md. Admin berikutnya diundang dari '
                        'menu Akun.',
                        style: AdminText.caption.copyWith(
                          color: AdminColors.warn,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.compact = false});

  /// Versi ringkas untuk layar sempit: logo + judul saja, tanpa deskripsi.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: compact ? null : double.infinity,
      padding: EdgeInsets.all(compact ? 24 : 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E1B17), Color(0xFF07110E)],
        ),
      ),
      child: Column(
        mainAxisAlignment: compact
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/brand/rtsq_white_trim.png',
            height: compact ? 44 : 68,
          ),
          SizedBox(height: compact ? 14 : 28),
          Text(
            'Panel Admin\nRTSQ TV',
            style: TextStyle(
              fontFamily: AdminText.family,
              fontSize: compact ? 24 : 34,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: const Text(
                'Ubah pengumuman, prestasi, jadwal, dan teks berjalan. '
                'Perubahan langsung tampil di TV tanpa menyentuh perangkat.',
                style: TextStyle(
                  fontFamily: AdminText.family,
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFFB9C7C1),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _BrandChip('Tanpa biaya bulanan'),
                _BrandChip('Multi-admin'),
                _BrandChip('Pratinjau 16:9'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  const _BrandChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AdminText.family,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFFDCE7E2),
        ),
      ),
    );
  }
}
