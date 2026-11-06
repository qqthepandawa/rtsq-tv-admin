import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'app/session.dart';
import 'core/supabase_config.dart';
import 'core/theme.dart';
import 'data/admin_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // URL bersih: /pair?code=123456, bukan /#/pair?code=123456.
    usePathUrlStrategy();
  }
  await initializeDateFormatting('id_ID');

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    ).timeout(const Duration(seconds: 10));
  } catch (error) {
    debugPrint('Supabase gagal diinisialisasi: $error');
    runApp(BootstrapErrorApp(message: 'Supabase gagal diinisialisasi: $error'));
    return;
  }

  final repo = AdminRepository();
  final session = AdminSession(repo);
  await session.start();

  runApp(AdminApp(session: session));
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key, required this.session});

  final AdminSession session;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final _router = buildRouter(widget.session);

  @override
  void dispose() {
    _router.dispose();
    widget.session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RTSQ TV · Panel Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      routerConfig: _router,
    );
  }
}

/// Ditampilkan hanya bila konfigurasi Supabase tidak dapat dimuat.
class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RTSQ TV · Panel Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 44,
                        color: AdminColors.danger,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Panel tidak dapat terhubung',
                        style: AdminText.title.copyWith(fontSize: 22),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Periksa koneksi internet, lalu muat ulang halaman.',
                        textAlign: TextAlign.center,
                        style: AdminText.body,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        message,
                        textAlign: TextAlign.center,
                        style: AdminText.caption.copyWith(
                          color: AdminColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
