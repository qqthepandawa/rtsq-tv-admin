import '../core/format.dart';

class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.active,
    this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final bool active;
  final DateTime? createdAt;

  bool get isSuper => role == 'super';

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
    id: map['id'] as String? ?? '',
    email: map['email'] as String? ?? '',
    name: map['name'] as String? ?? '',
    role: map['role'] as String? ?? 'editor',
    active: map['active'] as bool? ?? false,
    createdAt: Wib.parse(map['created_at']),
  );
}

class AdminInvite {
  const AdminInvite({
    required this.email,
    required this.role,
    this.expiresAt,
    this.createdAt,
  });

  final String email;
  final String role;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool get expired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now().toUtc());

  factory AdminInvite.fromMap(Map<String, dynamic> map) => AdminInvite(
    email: map['email'] as String? ?? '',
    role: map['role'] as String? ?? 'editor',
    expiresAt: Wib.parse(map['expires_at']),
    createdAt: Wib.parse(map['created_at']),
  );
}

class Device {
  const Device({
    required this.id,
    required this.name,
    required this.status,
    this.model,
    this.androidVersion,
    this.appVersion,
    this.pairingCode,
    this.pairingExpiresAt,
    this.lastSeenAt,
    this.lastSyncAt,
    this.screenState = 'content',
    this.storageUsedBytes,
    this.storageFreeBytes,
    this.network,
    this.pairedAt,
    this.createdAt,
  });

  final String id;
  final String name;
  final String status;
  final String? model;
  final String? androidVersion;
  final String? appVersion;
  final String? pairingCode;
  final DateTime? pairingExpiresAt;
  final DateTime? lastSeenAt;
  final DateTime? lastSyncAt;
  final String screenState;
  final int? storageUsedBytes;
  final int? storageFreeBytes;
  final String? network;
  final DateTime? pairedAt;
  final DateTime? createdAt;

  bool get isPaired => status == 'paired';
  bool get isPending => status == 'pending';
  bool get isRevoked => status == 'revoked';

  /// Dianggap online bila heartbeat < 10 menit (Blueprint §6.7).
  bool get isOnline {
    if (!isPaired || lastSeenAt == null) return false;
    return DateTime.now().toUtc().difference(lastSeenAt!.toUtc()).inMinutes <
        10;
  }

  Device copyWith({String? name, String? status}) => Device(
    id: id,
    name: name ?? this.name,
    status: status ?? this.status,
    model: model,
    androidVersion: androidVersion,
    appVersion: appVersion,
    pairingCode: pairingCode,
    pairingExpiresAt: pairingExpiresAt,
    lastSeenAt: lastSeenAt,
    lastSyncAt: lastSyncAt,
    screenState: screenState,
    storageUsedBytes: storageUsedBytes,
    storageFreeBytes: storageFreeBytes,
    network: network,
    pairedAt: pairedAt,
    createdAt: createdAt,
  );

  factory Device.fromMap(Map<String, dynamic> map) => Device(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? 'TV RTSQ',
    status: map['status'] as String? ?? 'pending',
    model: map['model'] as String?,
    androidVersion: map['android_version'] as String?,
    appVersion: map['app_version'] as String?,
    pairingCode: map['pairing_code'] as String?,
    pairingExpiresAt: Wib.parse(map['pairing_expires_at']),
    lastSeenAt: Wib.parse(map['last_seen_at']),
    lastSyncAt: Wib.parse(map['last_sync_at']),
    screenState: map['screen_state'] as String? ?? 'content',
    storageUsedBytes: (map['storage_used_bytes'] as num?)?.toInt(),
    storageFreeBytes: (map['storage_free_bytes'] as num?)?.toInt(),
    network: map['network'] as String?,
    pairedAt: Wib.parse(map['paired_at']),
    createdAt: Wib.parse(map['created_at']),
  );
}

class MediaItem {
  const MediaItem({
    required this.path,
    required this.type,
    this.name = '',
    this.size = 0,
    this.checksum = '',
    this.width,
    this.height,
    this.thumbPath,
  });

  final String path;
  final String type;
  final String name;
  final int size;
  final String checksum;
  final int? width;
  final int? height;
  final String? thumbPath;

  Map<String, dynamic> toMap() => {
    'path': path,
    'type': type,
    'name': name,
    'size': size,
    'checksum': checksum,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (thumbPath != null) 'thumb': thumbPath,
  };

  factory MediaItem.fromMap(Map<String, dynamic> map) => MediaItem(
    path: map['path'] as String? ?? '',
    type: map['type'] as String? ?? 'image/jpeg',
    name: map['name'] as String? ?? '',
    size: (map['size'] as num?)?.toInt() ?? 0,
    checksum: map['checksum'] as String? ?? '',
    width: (map['width'] as num?)?.toInt(),
    height: (map['height'] as num?)?.toInt(),
    thumbPath: map['thumb'] as String?,
  );
}

class ScheduleItem {
  const ScheduleItem({
    this.title = '',
    this.date = '',
    this.time = '',
    this.place = '',
  });

  final String title;
  final String date;
  final String time;
  final String place;

  Map<String, dynamic> toMap() => {
    'title': title,
    'date': date,
    'time': time,
    'place': place,
  };

  factory ScheduleItem.fromMap(Map<String, dynamic> map) => ScheduleItem(
    title: map['title'] as String? ?? '',
    date: map['date'] as String? ?? '',
    time: map['time'] as String? ?? '',
    place: map['place'] as String? ?? '',
  );
}

class ContentItem {
  const ContentItem({
    this.id,
    this.type = 'announcement',
    this.title = '',
    this.body = '',
    this.media = const [],
    this.studentName,
    this.marhalah,
    this.achievement,
    this.achievedAt,
    this.scheduleItems = const [],
    this.startAt,
    this.endAt,
    this.sortOrder = 0,
    this.durationSeconds,
    this.priority = 0,
    this.pinned = false,
    this.active = true,
    this.status = 'draft',
    this.consentConfirmed = false,
    this.showCaption = true,
    this.updatedAt,
    this.createdAt,
  });

  final String? id;
  final String type;
  final String title;
  final String body;
  final List<MediaItem> media;
  final String? studentName;
  final String? marhalah;
  final String? achievement;
  final String? achievedAt;
  final List<ScheduleItem> scheduleItems;
  final DateTime? startAt;
  final DateTime? endAt;
  final int sortOrder;
  final int? durationSeconds;
  final int priority;
  final bool pinned;
  final bool active;
  final String status;

  /// Persetujuan orang tua/wali untuk konten yang memuat nama santri
  /// (Blueprint §19, risiko privasi).
  final bool consentConfirmed;

  /// Izin menampilkan judul & keterangan bersama media di TV. Hanya berlaku
  /// untuk konten foto/video; tipe lain selalu menampilkan teksnya.
  final bool showCaption;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  bool get isPublished => status == 'published';

  bool get isMediaContent => type == 'photo' || type == 'video';

  /// Teks boleh tampil di TV bila konten bukan foto/video, atau bila admin
  /// sudah mengaktifkan [showCaption].
  bool get captionVisible => !isMediaContent || showCaption;

  /// Judul untuk daftar panel. Konten tanpa judul tetap bisa dibedakan
  /// lewat [primaryMediaName] dan thumbnail.
  String get displayTitle {
    final clean = title.trim();
    if (clean.isNotEmpty) return clean;
    return switch (type) {
      'photo' => 'Foto tanpa judul',
      'video' => 'Video tanpa judul',
      'achievement' => 'Prestasi tanpa judul',
      'schedule' => 'Jadwal tanpa judul',
      _ => 'Pengumuman tanpa judul',
    };
  }

  /// Media pertama yang mewakili konten (untuk thumbnail dan identifikasi).
  MediaItem? get primaryMedia {
    if (media.isEmpty) return null;
    if (isMediaContent) {
      final wanted = type == 'video' ? 'video' : 'image';
      for (final item in media) {
        if (item.type.startsWith(wanted)) return item;
      }
    }
    return media.first;
  }

  /// Nama berkas media utama, dipakai agar konten tanpa judul tidak
  /// tertukar saat dihapus.
  String? get primaryMediaName {
    final item = primaryMedia;
    if (item == null) return null;
    final name = item.name.trim();
    if (name.isNotEmpty) return name;
    final path = item.path.trim();
    if (path.isEmpty) return null;
    final slash = path.lastIndexOf('/');
    return slash >= 0 ? path.substring(slash + 1) : path;
  }

  String get typeLabel => switch (type) {
    'announcement' => 'Pengumuman',
    'achievement' => 'Prestasi',
    'photo' => 'Foto',
    'video' => 'Video',
    'schedule' => 'Jadwal',
    _ => type,
  };

  ContentItem copyWith({int? sortOrder, bool? pinned}) => ContentItem(
    id: id,
    type: type,
    title: title,
    body: body,
    media: media,
    studentName: studentName,
    marhalah: marhalah,
    achievement: achievement,
    achievedAt: achievedAt,
    scheduleItems: scheduleItems,
    startAt: startAt,
    endAt: endAt,
    sortOrder: sortOrder ?? this.sortOrder,
    durationSeconds: durationSeconds,
    priority: priority,
    pinned: pinned ?? this.pinned,
    active: active,
    status: status,
    consentConfirmed: consentConfirmed,
    showCaption: showCaption,
    updatedAt: updatedAt,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap({
    bool includeId = false,
    bool includeConsent = true,
  }) => {
    if (includeId && id != null) 'id': id,
    'type': type,
    'title': title.trim(),
    'body': body.trim().isEmpty ? null : body.trim(),
    'media': media.map((item) => item.toMap()).toList(),
    'student_name': _nullIfEmpty(studentName),
    'marhalah': _nullIfEmpty(marhalah),
    'achievement': _nullIfEmpty(achievement),
    'achieved_at': _nullIfEmpty(achievedAt),
    'schedule_items': scheduleItems.map((item) => item.toMap()).toList(),
    'start_at': startAt?.toUtc().toIso8601String(),
    'end_at': endAt?.toUtc().toIso8601String(),
    'sort_order': sortOrder,
    'duration_seconds': durationSeconds,
    'priority': priority,
    'pinned': pinned,
    'active': active,
    'status': status,
    if (includeConsent) 'consent_confirmed': consentConfirmed,
    'show_caption': showCaption,
  };

  factory ContentItem.fromMap(Map<String, dynamic> map) => ContentItem(
    id: map['id'] as String?,
    type: map['type'] as String? ?? 'announcement',
    title: map['title'] as String? ?? '',
    body: map['body'] as String? ?? '',
    media: _listOfMaps(map['media']).map(MediaItem.fromMap).toList(),
    studentName: map['student_name'] as String?,
    marhalah: map['marhalah'] as String?,
    achievement: map['achievement'] as String?,
    achievedAt: map['achieved_at']?.toString(),
    scheduleItems: _listOfMaps(
      map['schedule_items'],
    ).map(ScheduleItem.fromMap).toList(),
    startAt: Wib.parse(map['start_at']),
    endAt: Wib.parse(map['end_at']),
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    durationSeconds: (map['duration_seconds'] as num?)?.toInt(),
    priority: (map['priority'] as num?)?.toInt() ?? 0,
    pinned: map['pinned'] as bool? ?? false,
    active: map['active'] as bool? ?? true,
    status: map['status'] as String? ?? 'draft',
    consentConfirmed: map['consent_confirmed'] as bool? ?? false,
    showCaption: map['show_caption'] as bool? ?? true,
    updatedAt: Wib.parse(map['updated_at']),
    createdAt: Wib.parse(map['created_at']),
  );
}

class TickerItem {
  const TickerItem({
    this.id,
    this.text = '',
    this.startAt,
    this.endAt,
    this.sortOrder = 0,
    this.active = true,
  });

  final String? id;
  final String text;
  final DateTime? startAt;
  final DateTime? endAt;
  final int sortOrder;
  final bool active;

  Map<String, dynamic> toMap({bool includeId = false}) => {
    if (includeId && id != null) 'id': id,
    'text': text.trim(),
    'start_at': startAt?.toUtc().toIso8601String(),
    'end_at': endAt?.toUtc().toIso8601String(),
    'sort_order': sortOrder,
    'active': active,
  };

  factory TickerItem.fromMap(Map<String, dynamic> map) => TickerItem(
    id: map['id'] as String?,
    text: map['text'] as String? ?? '',
    startAt: Wib.parse(map['start_at']),
    endAt: Wib.parse(map['end_at']),
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    active: map['active'] as bool? ?? true,
  );
}

class SettingsRow {
  const SettingsRow({
    this.orgName = "Rumah Tahfizh Smart Qur'an",
    this.address = '',
    this.city = 'Batam',
    this.latitude = 1.13,
    this.longitude = 104.05,
    this.timezone = 'Asia/Jakarta',
    this.hijriOffset = const {},
    this.slideDurationSeconds = 10,
    this.tickerSpeed = 60,
    this.emergency,
    this.version = 1,
    this.updatedAt,
  });

  final String orgName;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final String timezone;
  final Map<String, dynamic> hijriOffset;
  final int slideDurationSeconds;
  final int tickerSpeed;
  final Map<String, dynamic>? emergency;
  final int version;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
    'org_name': orgName.trim(),
    'address': address.trim(),
    'city': city.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'hijri_offset': hijriOffset,
    'slide_duration_seconds': slideDurationSeconds,
    'ticker_speed': tickerSpeed,
    'emergency': emergency,
  };

  factory SettingsRow.fromMap(Map<String, dynamic> map) => SettingsRow(
    orgName: map['org_name'] as String? ?? "Rumah Tahfizh Smart Qur'an",
    address: map['address'] as String? ?? '',
    city: map['city'] as String? ?? 'Batam',
    latitude: (map['latitude'] as num?)?.toDouble() ?? 1.13,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 104.05,
    timezone: map['timezone'] as String? ?? 'Asia/Jakarta',
    hijriOffset: _map(map['hijri_offset']),
    slideDurationSeconds:
        (map['slide_duration_seconds'] as num?)?.toInt() ?? 10,
    tickerSpeed: (map['ticker_speed'] as num?)?.toInt() ?? 60,
    emergency: map['emergency'] is Map ? _map(map['emergency']) : null,
    version: (map['version'] as num?)?.toInt() ?? 1,
    updatedAt: Wib.parse(map['updated_at']),
  );
}

class LogEntry {
  const LogEntry({
    required this.id,
    required this.level,
    required this.message,
    this.context = const {},
    this.createdAt,
    this.deviceName,
  });

  final int id;
  final String level;
  final String message;
  final Map<String, dynamic> context;
  final DateTime? createdAt;
  final String? deviceName;

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    final device = map['devices'];
    return LogEntry(
      id: (map['id'] as num?)?.toInt() ?? 0,
      level: map['level'] as String? ?? 'info',
      message: map['message'] as String? ?? '',
      context: _map(map['context']),
      createdAt: Wib.parse(map['created_at']),
      deviceName: device is Map ? device['name'] as String? : null,
    );
  }
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.entity,
    this.entityId,
    this.diff = const {},
    this.createdAt,
    this.actorEmail,
  });

  final int id;
  final String action;
  final String entity;
  final String? entityId;
  final Map<String, dynamic> diff;
  final DateTime? createdAt;
  final String? actorEmail;

  factory AuditEntry.fromMap(Map<String, dynamic> map) {
    final actor = map['profiles'];
    return AuditEntry(
      id: (map['id'] as num?)?.toInt() ?? 0,
      action: map['action'] as String? ?? '',
      entity: map['entity'] as String? ?? '',
      entityId: map['entity_id'] as String?,
      diff: _map(map['diff']),
      createdAt: Wib.parse(map['created_at']),
      actorEmail: actor is Map ? actor['email'] as String? : null,
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return const {};
}

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) item.map((k, v) => MapEntry(k.toString(), v)),
  ];
}

String? _nullIfEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
