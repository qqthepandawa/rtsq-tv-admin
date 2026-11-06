import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/admin_repository.dart';
import '../data/models.dart';

/// Status sesi admin: user Supabase + baris `profiles`.
class AdminSession extends ChangeNotifier {
  AdminSession(this.repo) {
    _subscription = repo.auth.onAuthStateChange.listen((_) {
      unawaited(refresh());
    });
  }

  final AdminRepository repo;
  StreamSubscription<AuthState>? _subscription;

  Profile? profile;
  bool loading = true;
  String? accessIssue;

  String? _inviteTriedFor;
  String? _pendingName;
  Future<void>? _refreshInFlight;

  bool get isSignedIn => repo.user != null;
  bool get isReady => !loading;
  bool get canUsePanel => isSignedIn && profile?.active == true;
  bool get isSuper => profile?.isSuper ?? false;

  Future<void> start() => refresh();

  /// Coba lagi setelah admin utama menambahkan undangan untuk email ini.
  Future<void> retryInvite() async {
    _inviteTriedFor = null;
    await refresh();
  }

  /// Serialkan penyegaran sesi. Stream auth dan aksi pengguna bisa memicu
  /// refresh bersamaan; tanpa ini hasil yang lebih lambat bisa menimpa profil.
  Future<void> refresh() => _refreshInFlight ??= _refresh().whenComplete(
    () => _refreshInFlight = null,
  );

  Future<void> _refresh() async {
    loading = true;
    notifyListeners();
    try {
      if (!isSignedIn) {
        profile = null;
        accessIssue = null;
        return;
      }

      Profile? found;
      try {
        found = await repo.fetchProfile();
      } catch (error) {
        accessIssue = errorText(error);
        return;
      }

      final uid = repo.user?.id;
      if (found == null && uid != null && _inviteTriedFor != uid) {
        _inviteTriedFor = uid;
        try {
          found = await repo.acceptInvite(
            name: _pendingName ?? _displayName(repo.user?.email),
          );
        } catch (error) {
          accessIssue = error is AdminException
              ? error.message
              : 'Akun ini belum terdaftar sebagai admin RTSQ.';
        }
      }

      profile = found;
      if (found != null && !found.active) {
        accessIssue = 'Akun ini dinonaktifkan. Hubungi admin utama.';
      } else if (found != null) {
        accessIssue = null;
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    await repo.signIn(email, password);
    _inviteTriedFor = null;
    _pendingName = null;
    await refresh();
  }

  Future<bool> signUp(String email, String password, {String? name}) async {
    final hasSession = await repo.signUp(email, password);
    if (!hasSession) return false;
    _pendingName = (name ?? '').trim().isEmpty ? null : name!.trim();
    _inviteTriedFor = null;
    await refresh();
    return true;
  }

  Future<void> signOut() async {
    await repo.signOut();
    profile = null;
    accessIssue = null;
    _pendingName = null;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  static String _displayName(String? email) {
    if (email == null || email.isEmpty) return 'Admin RTSQ';
    final local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    return local
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
