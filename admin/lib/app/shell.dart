import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/session.dart';
import '../core/theme.dart';
import 'widgets.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.route, {this.superOnly = false});

  final String label;
  final IconData icon;
  final String route;
  final bool superOnly;
}

const _items = <_NavItem>[
  _NavItem('Dasbor', Icons.dashboard_outlined, '/'),
  _NavItem('Konten', Icons.article_outlined, '/content'),
  _NavItem('Pratinjau', Icons.tv_outlined, '/preview'),
  _NavItem('Ticker', Icons.text_fields_outlined, '/ticker'),
  _NavItem('Perangkat', Icons.connected_tv_outlined, '/devices'),
  _NavItem('Log', Icons.receipt_long_outlined, '/logs'),
  _NavItem('Pengaturan', Icons.tune_outlined, '/settings'),
  _NavItem('Akun', Icons.group_outlined, '/accounts', superOnly: true),
  _NavItem('Audit', Icons.history_outlined, '/audit'),
];

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.session, required this.child});

  final AdminSession session;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final items = [
      for (final item in _items)
        if (!item.superOnly || session.isSuper) item,
    ];
    final selected = _selectedIndex(items, location);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final extended = MediaQuery.sizeOf(context).width >= 1240;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AdminColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: wide ? 20 : 4,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!wide)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Image.asset('assets/brand/rtsq_trim.png', height: 26),
              ),
            Text(
              wide ? 'RTSQ TV · Panel Admin' : 'RTSQ TV',
              style: AdminText.h2.copyWith(fontSize: wide ? 18 : 16),
            ),
          ],
        ),
        actions: [
          if (session.profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: StatusPill(
                label: session.profile!.role == 'super'
                    ? 'Admin utama'
                    : 'Editor',
                tone: session.profile!.role == 'super'
                    ? PillTone.warn
                    : PillTone.info,
                icon: Icons.verified_user_outlined,
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'Akun',
            onSelected: (value) async {
              if (value == 'signout') {
                await session.signOut();
                if (context.mounted) context.go('/login');
              }
              if (value == 'accounts' && context.mounted) {
                context.go('/accounts');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.profile?.name ?? 'Admin',
                      style: AdminText.label.copyWith(color: AdminColors.ink),
                    ),
                    Text(
                      session.profile?.email ?? '',
                      style: AdminText.caption,
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              if (session.isSuper)
                const PopupMenuItem(
                  value: 'accounts',
                  child: Text('Kelola akun'),
                ),
              const PopupMenuItem(value: 'signout', child: Text('Keluar')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AdminColors.tealSoft,
                child: Text(
                  _initials(session.profile?.name),
                  style: const TextStyle(
                    fontFamily: AdminText.family,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.teal,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AdminColors.line),
        ),
      ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Row(
                        children: [
                          Image.asset('assets/brand/rtsq_trim.png', height: 34),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Panel Admin',
                              style: AdminText.h2.copyWith(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final item in items)
                            ListTile(
                              leading: Icon(item.icon),
                              title: Text(item.label),
                              selected:
                                  _selectedIndex(items, location) ==
                                  items.indexOf(item),
                              selectedColor: AdminColors.teal,
                              selectedTileColor: AdminColors.tealSoft,
                              onTap: () {
                                Navigator.of(context).pop();
                                context.go(item.route);
                              },
                            ),
                        ],
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Keluar'),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await session.signOut();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ],
                ),
              ),
            ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: extended,
              backgroundColor: AdminColors.surface,
              selectedIndex: selected,
              onDestinationSelected: (index) => context.go(items[index].route),
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              minExtendedWidth: 212,
              selectedIconTheme: const IconThemeData(color: AdminColors.teal),
              selectedLabelTextStyle: const TextStyle(
                fontFamily: AdminText.family,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AdminColors.teal,
              ),
              unselectedLabelTextStyle: AdminText.caption,
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
              ],
            ),
          if (wide) Container(width: 1, color: AdminColors.line),
          Expanded(child: child),
        ],
      ),
    );
  }

  static int _selectedIndex(List<_NavItem> items, String location) {
    if (location == '/') return items.indexWhere((item) => item.route == '/');
    for (var i = items.length - 1; i >= 0; i--) {
      final route = items[i].route;
      if (route != '/' && location.startsWith(route)) return i;
    }
    return 0;
  }

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'A';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
