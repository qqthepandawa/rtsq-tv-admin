import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/widgets.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.session});

  final AdminSession session;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final _repo = AdminRepository();
  final _email = TextEditingController();

  List<Profile> _profiles = const [];
  List<AdminInvite> _invites = const [];
  String _role = 'editor';
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.fetchProfiles(),
        _repo.fetchInvites(),
      ]);
      if (!mounted) return;
      setState(() {
        _profiles = results[0] as List<Profile>;
        _invites = results[1] as List<AdminInvite>;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Masukkan email yang valid.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.inviteAdmin(email, _role);
      _email.clear();
      if (!mounted) return;
      showSnack(
        context,
        'Undangan untuk $email disimpan. Minta orang tersebut mendaftar '
        'dengan email itu.',
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteInvite(AdminInvite invite) async {
    try {
      await _repo.deleteInvite(invite.email);
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  Future<void> _changeRole(Profile profile, String role) async {
    if (profile.id == widget.session.profile?.id) {
      showSnack(
        context,
        'Peran akun sendiri tidak dapat diubah dari sini.',
        error: true,
      );
      return;
    }
    try {
      await _repo.updateProfileRole(profile.id, role);
      if (!mounted) return;
      showSnack(context, 'Peran ${profile.email} menjadi $role.');
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  Future<void> _toggleActive(Profile profile, bool active) async {
    if (profile.id == widget.session.profile?.id) {
      showSnack(
        context,
        'Akun sendiri tidak dapat dinonaktifkan.',
        error: true,
      );
      return;
    }
    try {
      await _repo.setAdminActive(profile.id, active);
      if (!mounted) return;
      showSnack(
        context,
        active
            ? '${profile.email} diaktifkan kembali.'
            : '${profile.email} dinonaktifkan.',
      );
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.session.profile;

    return PageScaffold(
      title: 'Akun admin',
      subtitle:
          'Undang admin baru lewat email, ubah peran, atau nonaktifkan akun. '
          'Hanya admin utama yang dapat membuka halaman ini.',
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
          SectionCard(
            title: 'Undang admin',
            subtitle:
                'Undangan berlaku 7 hari. Orang yang diundang mendaftar di '
                'halaman masuk dengan email yang sama.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 300,
                  child: LabeledField(
                    label: 'Email',
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'guru@rtsq.id',
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: LabeledField(
                    label: 'Peran',
                    child: DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: 'editor',
                          child: Text('Editor'),
                        ),
                        DropdownMenuItem(
                          value: 'super',
                          child: Text('Admin utama'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _role = value ?? 'editor'),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _invite,
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Kirim undangan'),
                ),
              ],
            ),
          ),
          if (_invites.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionCard(
              title: 'Undangan menunggu (${_invites.length})',
              child: Column(
                children: [
                  for (final invite in _invites)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.mail_outline),
                      title: Text(invite.email, style: AdminText.label),
                      subtitle: Text(
                        '${invite.role == 'super' ? 'Admin utama' : 'Editor'} · '
                        '${invite.expired ? 'kedaluwarsa' : 'berlaku sampai ${Wib.date(invite.expiresAt)}'}',
                        style: AdminText.caption,
                      ),
                      trailing: IconButton(
                        tooltip: 'Batalkan undangan',
                        onPressed: () => _deleteInvite(invite),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SectionCard(
            title: 'Admin terdaftar (${_profiles.length})',
            child: _loading && _profiles.isEmpty
                ? const LoadingBlock()
                : Column(
                    children: [
                      for (final profile in _profiles)
                        _ProfileRow(
                          profile: profile,
                          isSelf: profile.id == me?.id,
                          onRole: (role) => _changeRole(profile, role),
                          onActive: (active) => _toggleActive(profile, active),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Catatan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• Admin pertama (super) dibuat sekali lewat SQL bootstrap '
                  'di supabase/README.md setelah mendaftar.',
                  style: AdminText.caption,
                ),
                const SizedBox(height: 6),
                Text(
                  '• Menonaktifkan akun tidak menghapus auth user; akun tidak '
                  'bisa membuka panel sampai diaktifkan lagi.',
                  style: AdminText.caption,
                ),
                const SizedBox(height: 6),
                Text(
                  '• Super admin terakhir tidak dapat dinonaktifkan (dijaga '
                  'oleh RPC set_admin_active).',
                  style: AdminText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.isSelf,
    required this.onRole,
    required this.onActive,
  });

  final Profile profile;
  final bool isSelf;
  final ValueChanged<String> onRole;
  final ValueChanged<bool> onActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.line),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: profile.role == 'super'
                ? AdminColors.goldSoft
                : AdminColors.tealSoft,
            child: Text(
              profile.name.isEmpty
                  ? '?'
                  : profile.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontFamily: AdminText.family,
                fontWeight: FontWeight.w800,
                color: profile.role == 'super'
                    ? AdminColors.gold
                    : AdminColors.teal,
              ),
            ),
          ),
          SizedBox(
            width: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name.isEmpty ? profile.email : profile.name,
                  style: AdminText.label.copyWith(color: AdminColors.ink),
                ),
                Text(profile.email, style: AdminText.caption),
              ],
            ),
          ),
          if (isSelf) const StatusPill(label: 'Anda', tone: PillTone.info),
          StatusPill(
            label: profile.role == 'super' ? 'Admin utama' : 'Editor',
            tone: profile.role == 'super' ? PillTone.warn : PillTone.neutral,
          ),
          StatusPill(
            label: profile.active ? 'Aktif' : 'Nonaktif',
            tone: profile.active ? PillTone.success : PillTone.danger,
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              initialValue: profile.role,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'editor', child: Text('Editor')),
                DropdownMenuItem(value: 'super', child: Text('Admin utama')),
              ],
              onChanged: isSelf
                  ? null
                  : (value) {
                      if (value != null) onRole(value);
                    },
            ),
          ),
          Switch(value: profile.active, onChanged: isSelf ? null : onActive),
        ],
      ),
    );
  }
}
