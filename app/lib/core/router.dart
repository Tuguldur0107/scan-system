import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/scan/convert_screen.dart';
import '../features/scan/pending_screen.dart';
import '../features/scan/uhf_scan_screen.dart';
import '../features/scan/history_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/data/data_table_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/super_admin/tenants_screen.dart';
import '../features/super_admin/create_tenant_screen.dart';
import '../features/super_admin/tenant_detail_screen.dart';
import '../features/super_admin/tenant_users_screen.dart';
import '../features/super_admin/tenant_tasks_screen.dart';
import '../features/super_admin/tenant_dashboard_screen.dart';
import '../features/super_admin/tenant_settings_screen.dart';
import '../features/super_admin/tenant_data_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isLoggedIn = authState.isLoggedIn;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) {
        return authState.isSuperAdmin ? '/super-admin' : '/scan';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Super admin routes
      GoRoute(
        path: '/super-admin',
        builder: (context, state) => const TenantsScreen(),
      ),
      GoRoute(
        path: '/super-admin/create-tenant',
        builder: (context, state) => const CreateTenantScreen(),
      ),
      GoRoute(
        path: '/tenant/:slug',
        builder: (context, state) => TenantDetailScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: '/tenant/:slug/users',
        builder: (context, state) => TenantUsersScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: '/tenant/:slug/tasks',
        builder: (context, state) => TenantTasksScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: '/tenant/:slug/dashboard',
        builder: (context, state) => TenantDashboardScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: '/tenant/:slug/settings',
        builder: (context, state) => TenantSettingsScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: '/tenant/:slug/data',
        builder: (context, state) => TenantDataScreen(
          slug: state.pathParameters['slug']!,
          initialSendId: state.uri.queryParameters['sendId'],
        ),
      ),

      // Regular app routes (with bottom nav)
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/scan',
            builder: (context, state) => const ScanScreen(),
          ),
          GoRoute(
            path: '/convert',
            builder: (context, state) => const ConvertScreen(),
          ),
          GoRoute(
            path: '/uhf',
            builder: (context, state) => const UhfScanScreen(),
          ),
          GoRoute(
            path: '/pending',
            builder: (context, state) => const PendingScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksScreen(),
          ),
          GoRoute(
            path: '/data',
            builder: (context, state) => DataTableScreen(
              initialSendId: state.uri.queryParameters['sendId'],
            ),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminScreen(),
          ),
        ],
      ),
    ],
  );
});
