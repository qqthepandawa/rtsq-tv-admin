import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import 'models.dart';

/// Kesalahan yang aman ditampilkan ke pengguna.
class AdminException implements Exception {
  const AdminException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminRepository {
  AdminRepository({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  SupabaseClient get client => _injected ?? Supabase.instance.client;

  GoTrueClient get auth => client.auth;

  User? get user => auth.currentUser;

  // ---------------------------------------------------------------- auth

  Future<Profile?> fetchProfile() async {
    final uid = user?.id;
    if (uid == null) return null;
    final row = await client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(row);
  }

  Future<void> signIn(String email, String password) async {
    try {
      await auth.signInWithPassword(email: email.trim(), password: password);
    } on AuthException catch (error) {
      throw AdminException(_authMessage(error));
    }
  }

  Future<bool> signUp(String email, String password) async {
    try {
      final response = await auth.signUp(
        email: email.trim(),
        password: password,
      );
      return response.session != null;
    } on AuthException catch (error) {
      throw AdminException(_authMessage(error));
    }
  }

  Future<void> signOut() => auth.signOut();

  Future<void> resetPassword(String email) async {
    try {
      await auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: '${SupabaseConfig.adminBaseUrl}/login',
      );
    } on AuthException catch (error) {
      throw AdminException(_authMessage(error));
    }
  }

  /// Klaim undangan yang cocok dengan email akun yang sedang masuk.
  Future<Profile> acceptInvite({String? name}) async {
    try {
      final result = await client.rpc(
        'accept_invite',
        params: {'p_name': name},
      );
      final map = result is List
          ? (result.isNotEmpty ? result.first as Map : null)
          : result as Map?;
      if (map == null) {
        throw const AdminException('Profil admin tidak terbentuk.');
      }
      return Profile.fromMap(map.cast<String, dynamic>());
    } on PostgrestException catch (error) {
      throw AdminException(
        error.message.contains('undangan')
            ? 'Email ini belum diundang sebagai admin RTSQ.'
            : error.message,
      );
    }
  }

  // ------------------------------------------------------------ profiles

  Future<List<Profile>> fetchProfiles() async {
    final rows = await client
        .from('profiles')
        .select()
        .order('created_at', ascending: true);
    return [for (final row in rows) Profile.fromMap(row)];
  }

  Future<List<AdminInvite>> fetchInvites() async {
    final rows = await client
        .from('admin_invites')
        .select()
        .order('created_at', ascending: false);
    return [for (final row in rows) AdminInvite.fromMap(row)];
  }

  Future<void> inviteAdmin(String email, String role) async {
    try {
      await client.from('admin_invites').upsert({
        'email': email.trim().toLowerCase(),
        'role': role,
        'invited_by': user?.id,
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(days: 7))
            .toIso8601String(),
      }, onConflict: 'email');
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  Future<void> deleteInvite(String email) =>
      client.from('admin_invites').delete().eq('email', email);

  Future<void> updateProfileRole(String id, String role) async {
    try {
      await client.from('profiles').update({'role': role}).eq('id', id);
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  Future<void> setAdminActive(String id, bool active) async {
    try {
      await client.rpc(
        'set_admin_active',
        params: {'p_uid': id, 'p_active': active},
      );
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  // ---------------------------------------------------------------- devices

  Future<List<Device>> fetchDevices() async {
    final rows = await client
        .from('devices')
        .select()
        .order('created_at', ascending: false);
    return [for (final row in rows) Device.fromMap(row)];
  }

  Future<void> pairDevice(String code, {String? name}) async {
    try {
      await client.rpc(
        'pair_device',
        params: {
          'p_code': code.trim(),
          'p_name': (name ?? '').trim().isEmpty ? null : name!.trim(),
        },
      );
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  Future<void> renameDevice(String id, String name) async {
    try {
      await client.from('devices').update({'name': name.trim()}).eq('id', id);
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  Future<void> revokeDevice(String id) async {
    try {
      await client
          .from('devices')
          .update({
            'status': 'revoked',
            'pairing_code': null,
            'pairing_expires_at': null,
          })
          .eq('id', id);
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  Future<void> deleteDevice(String id) =>
      client.from('devices').delete().eq('id', id);

  Future<void> createCommand(
    String deviceId,
    String type, {
    Map<String, dynamic> payload = const {},
  }) async {
    try {
      await client.from('commands').insert({
        'device_id': deviceId,
        'type': type,
        'payload': payload,
      });
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  /// Beberapa perintah terakhir untuk satu perangkat.
  Future<List<Map<String, dynamic>>> fetchCommands(String deviceId) async {
    final rows = await client
        .from('commands')
        .select()
        .eq('device_id', deviceId)
        .order('created_at', ascending: false)
        .limit(10);
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }

  // ---------------------------------------------------------------- contents

  Future<List<ContentItem>> fetchContents() async {
    final rows = await client
        .from('contents')
        .select()
        .order('pinned', ascending: false)
        .order('priority', ascending: false)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return [for (final row in rows) ContentItem.fromMap(row)];
  }

  Future<ContentItem?> fetchContent(String id) async {
    final row = await client
        .from('contents')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ContentItem.fromMap(row);
  }

  Future<ContentItem> saveContent(ContentItem item) async {
    try {
      return await _writeContent(item, includeConsent: true);
    } on PostgrestException catch (error) {
      // Beberapa proyek belum menjalankan migrasi 0010 sehingga kolom
      // consent_confirmed belum ada. Simpan tanpa kolom itu agar penyuntingan
      // tetap berjalan; validasi persetujuan tetap dilakukan di editor.
      if (error.message.contains('consent_confirmed')) {
        try {
          return await _writeContent(item, includeConsent: false);
        } on PostgrestException catch (retry) {
          throw AdminException(_dbMessage(retry));
        }
      }
      throw AdminException(_dbMessage(error));
    }
  }

  Future<ContentItem> _writeContent(
    ContentItem item, {
    required bool includeConsent,
  }) async {
    final payload = item.toMap(includeConsent: includeConsent);
    if (item.id == null) {
      final row = await client
          .from('contents')
          .insert(payload)
          .select()
          .single();
      return ContentItem.fromMap(row);
    }
    final row = await client
        .from('contents')
        .update(payload)
        .eq('id', item.id!)
        .select()
        .single();
    return ContentItem.fromMap(row);
  }

  Future<void> deleteContent(String id) =>
      client.from('contents').delete().eq('id', id);

  Future<void> setContentStatus(String id, String status) async {
    try {
      await client.from('contents').update({'status': status}).eq('id', id);
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  Future<void> setContentActive(String id, bool active) async {
    try {
      await client.from('contents').update({'active': active}).eq('id', id);
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  Future<void> updateContentSort(String id, int sortOrder) async {
    try {
      await client
          .from('contents')
          .update({'sort_order': sortOrder})
          .eq('id', id);
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  Future<void> updateContentPin(String id, bool pinned) async {
    try {
      await client.from('contents').update({'pinned': pinned}).eq('id', id);
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  // ---------------------------------------------------------------- ticker

  Future<List<TickerItem>> fetchTicker() async {
    final rows = await client
        .from('ticker')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return [for (final row in rows) TickerItem.fromMap(row)];
  }

  Future<void> saveTicker(TickerItem item) async {
    try {
      if (item.id == null) {
        await client.from('ticker').insert(item.toMap());
      } else {
        await client.from('ticker').update(item.toMap()).eq('id', item.id!);
      }
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  Future<void> deleteTicker(String id) =>
      client.from('ticker').delete().eq('id', id);

  // -------------------------------------------------------------- settings

  Future<SettingsRow> fetchSettings() async {
    final row = await client
        .from('settings')
        .select()
        .eq('id', 1)
        .maybeSingle();
    return SettingsRow.fromMap(row ?? const {});
  }

  Future<void> saveSettings(SettingsRow settings) async {
    try {
      await client.from('settings').update(settings.toMap()).eq('id', 1);
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  // ------------------------------------------------------------ log & audit

  Future<List<LogEntry>> fetchLogs({String? level, int limit = 100}) async {
    var query = client
        .from('logs')
        .select(
          'id, device_id, level, message, context, created_at, '
          'devices(name)',
        );
    if (level != null && level != 'all') {
      query = query.eq('level', level);
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return [for (final row in rows) LogEntry.fromMap(row)];
  }

  Future<List<AuditEntry>> fetchAudit({int limit = 100}) async {
    final rows = await client
        .from('audit_log')
        .select(
          'id, actor, action, entity, entity_id, diff, created_at, '
          'profiles(email)',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final row in rows) AuditEntry.fromMap(row)];
  }

  Future<void> purgeLogs() async {
    try {
      await client.rpc('purge_old_logs');
    } on PostgrestException catch (error) {
      throw AdminException(_dbMessage(error));
    }
  }

  // ---------------------------------------------------------------- media

  Future<MediaItem?> pickAndUpload({
    bool videoOnly = false,
    bool imageOnly = false,
  }) async {
    final picked = await FilePicker.pickFile(
      type: videoOnly
          ? FileType.video
          : imageOnly
          ? FileType.image
          : FileType.media,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();

    final isVideo = _looksLikeVideo(picked.name, picked.extension);
    if (isVideo) {
      // Tidak ada batas ukuran di sisi aplikasi. Batas sebenarnya ditentukan
      // Supabase Storage (Global file size limit + file_size_limit bucket).
      // Bila melebihi, server mengembalikan 413 dan diterjemahkan di
      // _uploadRaw menjadi pesan yang mudah dipahami.
      return _uploadRaw(
        bytes,
        picked.name,
        contentType: 'video/mp4',
        type: 'video',
      );
    }

    if (bytes.length > 25 * 1024 * 1024) {
      throw const AdminException('Gambar melebihi 25 MB.');
    }
    return _uploadImage(bytes, picked.name);
  }

  Future<MediaItem> _uploadImage(Uint8List bytes, String name) async {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      throw const AdminException('Berkas gambar tidak dapat dibaca.');
    }

    // Batasi sisi terpanjang ke 1920 px (Blueprint §9.4).
    if (decoded.width > 1920 || decoded.height > 1920) {
      decoded = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: 1920)
          : img.copyResize(decoded, height: 1920);
    }

    // Batas berkas akhir 4 MB setelah kompresi (Blueprint §6.4).
    const maxOutputBytes = 4 * 1024 * 1024;
    var output = decoded;
    var jpg = img.encodeJpg(output, quality: 85);
    if (jpg.length > maxOutputBytes) {
      jpg = img.encodeJpg(output, quality: 70);
    }
    if (jpg.length > maxOutputBytes) {
      output = img.copyResize(
        output,
        width: (output.width * 0.75).round(),
        height: (output.height * 0.75).round(),
      );
      jpg = img.encodeJpg(output, quality: 75);
    }
    if (jpg.length > maxOutputBytes) {
      throw const AdminException(
        'Gambar melebihi 4 MB setelah kompresi. Gunakan gambar yang lebih '
        'kecil atau sederhana.',
      );
    }

    final thumb = img.encodeJpg(
      img.copyResize(
        output,
        width: output.width >= output.height ? 640 : null,
        height: output.height > output.width ? 640 : null,
      ),
      quality: 80,
    );

    final hash = sha256.convert(jpg).toString();
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final path = 'contents/$stamp-$hash.jpg';
    final thumbPath = 'contents/$stamp-$hash-thumb.jpg';

    await client.storage
        .from(SupabaseConfig.storageBucket)
        .uploadBinary(
          path,
          Uint8List.fromList(jpg),
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    await client.storage
        .from(SupabaseConfig.storageBucket)
        .uploadBinary(
          thumbPath,
          Uint8List.fromList(thumb),
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    return MediaItem(
      path: path,
      type: 'image/jpeg',
      name: name,
      size: jpg.length,
      checksum: hash,
      width: output.width,
      height: output.height,
      thumbPath: thumbPath,
    );
  }

  Future<MediaItem> _uploadRaw(
    Uint8List bytes,
    String name, {
    required String contentType,
    required String type,
  }) async {
    final hash = sha256.convert(bytes).toString();
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final ext = (name.contains('.') ? name.split('.').last : 'mp4')
        .toLowerCase();
    final path = 'contents/$stamp-$hash.$ext';
    try {
      await client.storage
          .from(SupabaseConfig.storageBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
    } on StorageException catch (error) {
      final tooLarge =
          error.statusCode == '413' ||
          error.message.toLowerCase().contains('exceeded the maximum allowed');
      if (tooLarge) {
        throw const AdminException(
          'Berkas melebihi batas Supabase Storage. Paket Free dibatasi 50 MB '
          'per berkas. Naikkan "Global file size limit" di Dashboard Supabase '
          '(butuh paket Pro), atau kompres video agar di bawah batas tersebut.',
        );
      }
      rethrow;
    }
    return MediaItem(
      path: path,
      type: type,
      name: name,
      size: bytes.length,
      checksum: hash,
    );
  }

  Future<String?> signedUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await client.storage
          .from(SupabaseConfig.storageBucket)
          .createSignedUrl(path, 60 * 60 * 6);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteMedia(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await client.storage.from(SupabaseConfig.storageBucket).remove([path]);
    } catch (_) {
      // Media yatim tidak menghalangi penyuntingan konten.
    }
  }

  static bool _looksLikeVideo(String name, String? extension) {
    final ext = (extension ?? name.split('.').last).toLowerCase();
    return ['mp4', 'mov', 'm4v', 'webm'].contains(ext);
  }

  static String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Email atau sandi salah.';
    }
    if (message.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Buka tautan di kotak masuk.';
    }
    if (message.contains('user already registered')) {
      return 'Email ini sudah terdaftar. Silakan masuk.';
    }
    if (message.contains('password')) {
      return 'Sandi minimal 6 karakter.';
    }
    return error.message;
  }

  static String _dbMessage(PostgrestException error) {
    if (error.code == '42501') {
      return 'Anda tidak punya hak untuk tindakan ini.';
    }
    if (error.code == '23505') {
      return 'Data sudah ada.';
    }
    if (error.message.contains('show_caption')) {
      return 'Database belum mendukung pengaturan teks TV. '
          'Jalankan migrasi 0012_show_caption.sql di Supabase.';
    }
    if (error.message.contains('Kode pairing')) {
      return error.message;
    }
    if (error.message.contains('super')) {
      return error.message;
    }
    return error.message;
  }

  /// Ringkasan untuk dasbor.
  Future<Map<String, int>> fetchCounts() async {
    final contents = await client.from('contents').select('status, active');
    var published = 0;
    var draft = 0;
    for (final row in contents) {
      if (row['status'] == 'published' && row['active'] == true) {
        published++;
      } else {
        draft++;
      }
    }
    final ticker = await client.from('ticker').select('id').eq('active', true);
    final devices = await client.from('devices').select('id');
    return {
      'published': published,
      'draft': draft,
      'ticker': ticker.length,
      'devices': devices.length,
    };
  }

  /// Debug ringan: pastikan sesi masih hidup.
  Map<String, dynamic> get sessionInfo => {
    'email': user?.email,
    'anonymous': user?.isAnonymous ?? false,
    'expiresAt': auth.currentSession?.expiresAt,
  };
}

/// Helper kecil untuk menampilkan error secara seragam.
String errorText(Object error) {
  if (error is AdminException) return error.message;
  if (error is AuthException) return error.message;
  if (error is PostgrestException) return error.message;
  return 'Terjadi kesalahan: $error';
}

String prettyJson(Object? value) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(value ?? const {});
}
