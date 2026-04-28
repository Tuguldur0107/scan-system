import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_strings.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _tasksLoaded = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final scheme = Theme.of(context).colorScheme;

    // Load tasks from server once after login
    if (!_tasksLoaded && authState.isLoggedIn) {
      _tasksLoaded = true;
      Future.microtask(() => ref.read(tasksProvider.notifier).loadFromServer());
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surface,
              const Color(0xFFEAF6F0),
              const Color(0xFFF6F3E7),
            ],
          ),
        ),
        child: widget.child,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withAlpha(18),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            selectedIndex: _currentIndex(context),
            onDestinationSelected: (i) =>
                _onTap(context, i, authState.isTenantAdmin),
            destinations: kIsWeb
                ? [
                    NavigationDestination(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: S.scan,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.transform),
                      label: S.barcodeEpcImport,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.task_alt),
                      label: S.tasks,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.table_chart),
                      label: S.data,
                    ),
                    if (authState.isTenantAdmin)
                      NavigationDestination(
                        icon: const Icon(Icons.admin_panel_settings),
                        label: S.dashboard,
                      ),
                  ]
                : [
                    NavigationDestination(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: S.scan,
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.sensors),
                      label: 'UHF',
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.hourglass_bottom),
                      label: S.pending,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.history),
                      label: S.history,
                    ),
                  ],
          ),
        ),
      ),
    );
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isAdmin = ref.read(authStateProvider).isTenantAdmin;
    if (kIsWeb) {
      if (location.startsWith('/scan')) return 0;
      if (location.startsWith('/import/barcode-epc')) return 1;
      if (location.startsWith('/tasks')) return 2;
      if (location.startsWith('/data')) return 3;
      if (location.startsWith('/admin')) return isAdmin ? 4 : 0;
      return 0;
    } else {
      if (location.startsWith('/scan')) return 0;
      if (location.startsWith('/uhf') || location.startsWith('/convert')) return 1;
      if (location.startsWith('/pending')) return 2;
      if (location.startsWith('/history')) return 3;
      return 0;
    }
  }

  void _onTap(BuildContext context, int index, bool isAdmin) {
    if (kIsWeb) {
      switch (index) {
        case 0:
          context.go('/scan');
          break;
        case 1:
          context.go('/import/barcode-epc');
          break;
        case 2:
          context.go('/tasks');
          break;
        case 3:
          context.go('/data');
          break;
        case 4:
          context.go('/admin');
          break;
      }
    } else {
      switch (index) {
        case 0:
          context.go('/scan');
          break;
        case 1:
          context.go('/uhf');
          break;
        case 2:
          context.go('/pending');
          break;
        case 3:
          context.go('/history');
          break;
      }
    }
  }
}
