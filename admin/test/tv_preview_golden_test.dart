import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsq_admin/data/models.dart';
import 'package:rtsq_admin/features/preview/prayer_preview.dart';
import 'package:rtsq_admin/features/preview/tv_preview.dart';

Future<void> _loadFonts() async {
  final jakarta = FontLoader('PlusJakartaSans')
    ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Variable.ttf'));
  await jakarta.load();
  final amiri = FontLoader('Amiri')
    ..addFont(rootBundle.load('assets/fonts/Amiri-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
  await amiri.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> _precacheBrand(WidgetTester tester) async {
  final context = tester.element(find.byType(TvPreview));
  await tester.runAsync(() async {
    await Future.wait([
      precacheImage(
        const AssetImage('assets/brand/rtsq_white_trim.png'),
        context,
      ),
      precacheImage(const AssetImage('assets/brand/ykca_trim.png'), context),
    ]);
  });
  await tester.pump();
}

const _prayers = <PreviewPrayer>[
  PreviewPrayer(label: 'SUBUH', time: '04:28', isPrayer: true),
  PreviewPrayer(label: 'SYURUQ', time: '05:42', isPrayer: false),
  PreviewPrayer(label: 'DHUHA', time: '06:10', isPrayer: false),
  PreviewPrayer(label: 'DZUHUR', time: '11:51', isPrayer: true),
  PreviewPrayer(label: 'ASHAR', time: '15:11', isPrayer: true),
  PreviewPrayer(label: 'MAGHRIB', time: '17:53', isPrayer: true),
  PreviewPrayer(label: 'ISYA', time: '19:03', isPrayer: true),
];

// 4 Nov 2026 14:32 WIB.
final _fixedNow = DateTime.utc(2026, 11, 4, 7, 32, 10);

void main() {
  setUpAll(_loadFonts);

  testWidgets('pratinjau 1920x1080 sesuai tata letak app TV', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: TvPreview(
          content: const ContentItem(
            type: 'announcement',
            title: 'Pengumuman Penting',
            body: 'Kegiatan tasmi berlangsung ba\'da Ashar di aula utama.',
          ),
          settings: const SettingsRow(orgName: 'RTSQ Batam'),
          prayers: _prayers,
          tickerText: 'RTSQ TV · Mari jaga kebersihan dan ketertiban bersama.',
          animateTicker: false,
          fixedNow: _fixedNow,
        ),
      ),
    );
    await _precacheBrand(tester);
    await tester.pump();

    await expectLater(
      find.byType(TvPreview),
      matchesGoldenFile('goldens/tv_preview_1920x1080.png'),
    );
  });
}
