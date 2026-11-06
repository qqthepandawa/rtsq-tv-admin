import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/session.dart';
import '../core/theme.dart';
import '../features/auth/login_page.dart';
import '../features/accounts/accounts_page.dart';
import '../features/audit/audit_page.dart';
import '../features/content/content_editor_page.dart';
import '../features/content/content_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/devices/devices_page.dart';
import '../features/logs/logs_page.dart';
import '../features/pair/pair_page.dart';
import '../features/preview/preview_page.dart';
import '../features/settings/settings_page.dart';
import '../features/ticker/ticker_page.dart';
import 'shell.dart';

GoRouter buildRouter(AdminSession session) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final loggingIn = location == '/login';
      final pairing = location == '/pair';
      final pending = location == '/pending';

      if (session.loading) return null;

      if (!session.isSignedIn) {
        if (loggingIn || pairing) return null;
        return '/login';
      }

      if (!session.canUsePanel) {
        return pending ? null : '/pending';
      }

      if (loggingIn || pending) return '/';
      if ((location == '/accounts' || location == '/settings') &&
          !session.isSuper) {
        // Editor tetap boleh melihat pengaturan (hanya baca), tetapi bukan
        // halaman akun.
        if (location == '/accounts') return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => LoginPage(session: session),
      ),
      GoRoute(
        path: '/pending',
        builder: (_, _) => PendingPage(session: session),
      ),
      GoRoute(
        path: '/pair',
        builder: (_, state) =>
            PairPage(session: session, code: state.uri.queryParameters['code']),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(session: session, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => DashboardPage(session: session),
          ),
          GoRoute(
            path: '/content',
            builder: (_, _) => ContentPage(session: session),
          ),
          GoRoute(
            path: '/content/new',
            builder: (_, _) => ContentEditorPage(session: session),
          ),
          GoRoute(
            path: '/content/:id',
            builder: (_, state) => ContentEditorPage(
              session: session,
              contentId: state.pathParameters['id'],
            ),
          ),
          GoRoute(path: '/preview', builder: (_, _) => const PreviewPage()),
          GoRoute(
            path: '/ticker',
            builder: (_, _) => TickerPage(session: session),
          ),
          GoRoute(
            path: '/devices',
            builder: (_, _) => DevicesPage(session: session),
          ),
          GoRoute(
            path: '/logs',
            builder: (_, _) => LogsPage(session: session),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => SettingsPage(session: session),
          ),
          GoRoute(
            path: '/accounts',
            builder: (_, _) => AccountsPage(session: session),
          ),
          GoRoute(path: '/audit', builder: (_, _) => const AuditPage()),
        ],
      ),
    ],
  );
}

/// Halaman untuk akun yang sudah masuk tetapi belum punya profil aktif.
class PendingPage extends StatelessWidget {
  const PendingPage({super.key, required this.session});

  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_person_outlined,
                      size: 48,
                      color: AdminColors.warn,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Akun belum aktif',
                      style: AdminText.title.copyWith(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      session.accessIssue ??
                          'Email ini belum terdaftar sebagai admin RTSQ. '
                              'Minta admin utama mengirim undangan, lalu masuk '
                              'kembali.',
                      textAlign: TextAlign.center,
                      style: AdminText.body,
                    ),
                    if (session.profile?.email != null) ...[
                      const SizedBox(height: 8),
                      Text(session.profile!.email, style: AdminText.caption),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () => session.retryInvite(),
                          child: const Text('Periksa lagi'),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () async {
                            await session.signOut();
                            if (context.mounted) context.go('/login');
                          },
                          child: const Text('Keluar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
