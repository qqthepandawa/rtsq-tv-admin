import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rtsq_admin/app/session.dart';
import 'package:rtsq_admin/core/format.dart';
import 'package:rtsq_admin/core/theme.dart';
import 'package:rtsq_admin/data/admin_repository.dart';
import 'package:rtsq_admin/data/models.dart';
import 'package:rtsq_admin/features/auth/login_page.dart';
import 'package:rtsq_admin/features/preview/prayer_preview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('Wib', () {
    test('mengubah instant UTC ke jam dinding WIB', () {
      final instant = DateTime.utc(2026, 11, 6, 3, 30);
      expect(Wib.time(instant), '10:30');
      expect(Wib.date(instant), '6 Nov 2026');
    });

    test('round trip input waktu WIB', () {
      final instant = Wib.fromWib(DateTime(2026, 11, 6, 14, 5));
      expect(instant, DateTime.utc(2026, 11, 6, 7, 5));
      expect(Wib.toWib(instant), DateTime.utc(2026, 11, 6, 14, 5));
    });
  });

  group('Model konten', () {
    test('memetakan kolom Supabase dan mengosongkan teks opsional', () {
      final item = ContentItem.fromMap({
        'id': 'c1',
        'type': 'achievement',
        'title': 'Tasmi 7 Juz',
        'body': 'Selamat.',
        'media': [
          {'path': 'contents/a.jpg', 'type': 'image/jpeg', 'size': 10},
        ],
        'student_name': 'Alfita',
        'achieved_at': '2026-11-03',
        'pinned': true,
        'status': 'published',
      });

      expect(item.typeLabel, 'Prestasi');
      expect(item.media, hasLength(1));
      expect(item.media.first.path, 'contents/a.jpg');
      expect(item.isPublished, isTrue);
      expect(item.pinned, isTrue);

      final map = item.toMap();
      expect(map['student_name'], 'Alfita');
      expect(map['media'], hasLength(1));
    });

    test('status perangkat online memakai batas 3 menit', () {
      final device = Device.fromMap({
        'id': 'd1',
        'name': 'TV Lobby',
        'status': 'paired',
        'last_seen_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(seconds: 30))
            .toIso8601String(),
      });
      expect(device.isOnline, isTrue);

      final stale = Device.fromMap({
        'id': 'd2',
        'name': 'TV Lama',
        'status': 'paired',
        'last_seen_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 10))
            .toIso8601String(),
      });
      expect(stale.isOnline, isFalse);
    });
  });

  group('Pengaturan', () {
    test('nilai default aman saat baris kosong', () {
      final settings = SettingsRow.fromMap(const {});
      expect(settings.city, 'Batam');
      expect(settings.slideDurationSeconds, 10);
      expect(settings.iqamahMinutes['maghrib'], 7);
      expect(settings.prayerModeEnabled['subuh'], isTrue);
    });

    test('round trip mempertahankan ihtiyati dan darurat', () {
      final settings = SettingsRow(
        orgName: 'RTSQ Batam',
        ihtiyati: const {'subuh': 2},
        emergency: const {'active': true, 'title': 'Listrik padam'},
      );
      final restored = SettingsRow.fromMap(settings.toMap());
      expect(restored.orgName, 'RTSQ Batam');
      expect(restored.ihtiyati['subuh'], 2);
      expect(restored.emergency?['title'], 'Listrik padam');
    });
  });

  test('format Hijriah memakai nama bulan Indonesia', () {
    final wib = DateTime(2026, 11, 6, 10);
    final maghrib = DateTime(2026, 11, 6, 18);
    final text = formatHijriPreview(wib, maghrib);
    expect(text, contains('H'));
    expect(text, isNot(contains('null')));
  });

  testWidgets('login tetap rapi di layar HP (tanpa overflow)', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final session = AdminSession(AdminRepository(client: client));
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAdminTheme(),
        home: LoginPage(session: session),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Masuk panel'), findsOneWidget);
    expect(find.text('Panel Admin\nRTSQ TV'), findsOneWidget);
  });

  testWidgets('login lebar menampilkan panel merek penuh', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final session = AdminSession(AdminRepository(client: client));
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAdminTheme(),
        home: LoginPage(session: session),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Tanpa biaya bulanan'), findsOneWidget);
  });
}
