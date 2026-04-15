import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../providers/scan_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../providers/tenant_user_provider.dart';
import '../../widgets/ui_charts.dart';
import '../../widgets/ui_state_widgets.dart';
import '../../widgets/ui_surfaces.dart';

class TenantDashboardScreen extends ConsumerStatefulWidget {
  const TenantDashboardScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<TenantDashboardScreen> createState() =>
      _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends ConsumerState<TenantDashboardScreen> {
  String? _loadedTenantId;

  void _ensureTenantLoaded(TenantInfo tenant) {
    if (_loadedTenantId == tenant.id) return;
    _loadedTenantId = tenant.id;
    Future.microtask(() async {
      ref.read(activeTenantProvider.notifier).state = tenant;
      await ref.read(tenantUsersProvider.notifier).loadUsers(tenant.id);
      await ref
          .read(tasksProvider.notifier)
          .loadFromServer(tenantId: tenant.id);
      await ref
          .read(scanProvider.notifier)
          .fetchFromServer(tenantId: tenant.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(tenantBySlugProvider(widget.slug));
    if (tenant == null) {
      return Scaffold(
        appBar: AppBar(title: Text(S.dashboard)),
        body: const Center(child: Text('Tenant сонгогдоогүй байна')),
      );
    }
    _ensureTenantLoaded(tenant);

    final users =
        ref.watch(tenantUsersProvider).valueOrNull ?? const <TenantUser>[];
    final usersState = ref.watch(tenantUsersProvider);
    final tasks = ref.watch(tasksProvider);
    final scans = ref.watch(scanProvider);

    final openTasks = tasks.where((t) => t.isOpen).length;
    final syncedScans = scans.where((s) => s.synced).length;
    final pendingScans = scans.where((s) => !s.synced).length;
    final activeUsers = users.where((u) => u.isActive).length;
    final topProjects = [...tasks]..sort((a, b) {
        final aCount = scans.where((s) => s.projectId == a.id).length;
        final bCount = scans.where((s) => s.projectId == b.id).length;
        return bCount.compareTo(aCount);
      });
    final topUsers = [...users]..sort((a, b) {
        final aCount = scans.where((s) => s.username == a.username).length;
        final bCount = scans.where((s) => s.username == b.username).length;
        return bCount.compareTo(aCount);
      });
    final now = DateTime.now();
    final inactiveUsers = users.where((u) => !u.isActive).length;
    final stalledTasks = tasks.where((task) {
      final taskScans = scans.where((scan) => scan.projectId == task.id);
      if (taskScans.isEmpty) return task.isOpen;
      final latest = taskScans
          .map((scan) => scan.scannedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      return task.isOpen && now.difference(latest).inDays >= 3;
    }).length;
    final attentionCards = <_AttentionCardData>[
      if (pendingScans > 0)
        _AttentionCardData(
          title: 'Pending Sync',
          message: '$pendingScans скан сервер рүү бүрэн sync хийгдээгүй байна.',
          icon: Icons.cloud_upload,
          color: const Color(0xFFB84C4C),
        ),
      if (inactiveUsers > 0)
        _AttentionCardData(
          title: 'Inactive Users',
          message: '$inactiveUsers хэрэглэгч идэвхгүй төлөвтэй байна.',
          icon: Icons.person_off,
          color: const Color(0xFF8A5A00),
        ),
      if (stalledTasks > 0)
        _AttentionCardData(
          title: 'Stalled Tasks',
          message: '$stalledTasks нээлттэй task дээр 3+ хоног activity алга.',
          icon: Icons.timelapse,
          color: const Color(0xFF1A3A5F),
        ),
      if (openTasks == 0)
        const _AttentionCardData(
          title: 'No Open Tasks',
          message: 'Операторуудад ажиллах нээлттэй task алга.',
          icon: Icons.lock_outline,
          color: Color(0xFF7A8595),
        ),
    ];
    final dayBuckets = List<int>.filled(7, 0);
    final dayLabels = List<String>.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return '${day.month}/${day.day}';
    });
    for (final scan in scans) {
      final normalized = DateTime(
        scan.scannedAt.year,
        scan.scannedAt.month,
        scan.scannedAt.day,
      );
      final diff = now.difference(normalized).inDays;
      if (diff >= 0 && diff < 7) {
        dayBuckets[6 - diff] += 1;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tenant/${tenant.slug}'),
        ),
        title: Text('${S.dashboard} — ${tenant.name}'),
      ),
      body: usersState.isLoading
          ? const AppLoadingView(label: 'Loading dashboard...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 860;
                      final statCards = [
                        _StatCard(
                          icon: Icons.people,
                          value: '${users.length}',
                          label: 'Нийт хэрэглэгч',
                          color: Colors.blue,
                          subtitle: '$activeUsers идэвхтэй',
                        ),
                        _StatCard(
                          icon: Icons.task_alt,
                          value: '${tasks.length}',
                          label: 'Нийт даалгавар',
                          color: Colors.orange,
                          subtitle: '$openTasks нээлттэй',
                        ),
                        _StatCard(
                          icon: Icons.qr_code,
                          value: '${scans.length}',
                          label: 'Нийт скан',
                          color: Colors.green,
                          subtitle: '$syncedScans синк',
                        ),
                        _StatCard(
                          icon: Icons.pending,
                          value: '$pendingScans',
                          label: 'Хүлээгдэж буй',
                          color: pendingScans > 0 ? Colors.red : Colors.grey,
                          subtitle: pendingScans > 0
                              ? 'Синк хийгдээгүй'
                              : 'Бүгд синк',
                        ),
                      ];
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: statCards
                            .map((card) => SizedBox(
                                  width: wide
                                      ? (constraints.maxWidth - 12) / 2
                                      : constraints.maxWidth,
                                  child: card,
                                ))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  MiniBarChart(
                    title: '7 Day Activity',
                    values: dayBuckets,
                    labels: dayLabels,
                    color: const Color(0xFF0F6C5A),
                    emptyLabel: 'Сүүлийн 7 хоногт scan activity алга',
                  ),
                  const SizedBox(height: 24),
                  Text('Attention',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (attentionCards.isEmpty)
                    const AppEmptyView(
                      icon: Icons.verified,
                      title: 'Анхаарах зүйл алга',
                      message: 'Tenant-ийн operational health хэвийн байна.',
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: attentionCards
                          .map((card) => SizedBox(
                                width: MediaQuery.of(context).size.width > 860
                                    ? 320
                                    : double.infinity,
                                child: _AttentionCard(data: card),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 24),
                  Text('Insights',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 860;
                      final projectChart = _LeaderboardCard(
                        title: 'Top Projects',
                        color: const Color(0xFF0F6C5A),
                        rows: topProjects.take(5).map((task) {
                          final count =
                              scans.where((s) => s.projectId == task.id).length;
                          return _ChartRowData(label: task.name, value: count);
                        }).toList(),
                      );
                      final userChart = _LeaderboardCard(
                        title: 'Top Users',
                        color: const Color(0xFF1A3A5F),
                        rows: topUsers.take(5).map((user) {
                          final count = scans
                              .where((s) => s.username == user.username)
                              .length;
                          return _ChartRowData(
                              label: user.username, value: count);
                        }).toList(),
                      );
                      if (!wide) {
                        return Column(
                          children: [
                            projectChart,
                            const SizedBox(height: 12),
                            userChart,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: projectChart),
                          const SizedBox(width: 12),
                          Expanded(child: userChart),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('Daalgavar',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (tasks.isEmpty)
                    const AppEmptyView(
                      icon: Icons.task_alt,
                      title: 'Даалгавар байхгүй',
                      message:
                          'Tenant дээр ажиллах даалгавар хараахан үүсээгүй байна.',
                    )
                  else
                    ...tasks.map((task) {
                      final taskScans =
                          scans.where((s) => s.projectId == task.id).toList();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            task.isOpen ? Icons.lock_open : Icons.lock,
                            color: task.isOpen ? Colors.green : Colors.red,
                          ),
                          title: Text(task.name),
                          subtitle: Text(
                              '${taskScans.length} скан • ${task.isOpen ? "Нээлттэй" : "Хаалттай"}'),
                          trailing: SizedBox(
                            width: 76,
                            child: _MiniBar(
                              value: taskScans.length,
                              max: scans.isEmpty ? 1 : scans.length,
                              color: const Color(0xFF0F6C5A),
                              text: '${taskScans.length}',
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  Text('Хэрэглэгчид',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (users.isEmpty)
                    const AppEmptyView(
                      icon: Icons.people_outline,
                      title: 'Хэрэглэгч байхгүй',
                      message: 'Tenant дээр бүртгэлтэй хэрэглэгч алга.',
                    )
                  else
                    ...users.map((user) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                user.role == 'tenant_admin'
                                    ? Icons.admin_panel_settings
                                    : Icons.person,
                              ),
                            ),
                            title: Text(user.username),
                            subtitle: Text(
                                '${user.role == "tenant_admin" ? "Админ" : "Оператор"} • ${user.isActive ? "Идэвхтэй" : "Идэвхгүй"}'),
                            trailing: SizedBox(
                              width: 76,
                              child: _MiniBar(
                                value: scans
                                    .where((s) => s.username == user.username)
                                    .length,
                                max: scans.isEmpty ? 1 : scans.length,
                                color: const Color(0xFF1A3A5F),
                                text:
                                    '${scans.where((s) => s.username == user.username).length}',
                              ),
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.title,
    required this.color,
    required this.rows,
  });

  final String title;
  final Color color;
  final List<_ChartRowData> rows;

  @override
  Widget build(BuildContext context) {
    final max = rows.isEmpty
        ? 1
        : rows.map((row) => row.value).reduce((a, b) => a > b ? a : b);
    return Card(
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text('Activity алга',
                  style: Theme.of(context).textTheme.bodySmall)
            else
              ...rows.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.label,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${row.value}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: row.value / max,
                            minHeight: 10,
                            backgroundColor: color.withAlpha(20),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.value,
    required this.max,
    required this.color,
    required this.text,
  });

  final int value;
  final int max;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(text, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: max == 0 ? 0 : value / max,
            minHeight: 8,
            backgroundColor: color.withAlpha(20),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ChartRowData {
  const _ChartRowData({required this.label, required this.value});

  final String label;
  final int value;
}

class _AttentionCardData {
  const _AttentionCardData({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.data});

  final _AttentionCardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: data.color.withAlpha(16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: data.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    data.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.subtitle,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      )),
            ],
          ],
        ),
      ),
    );
  }
}
