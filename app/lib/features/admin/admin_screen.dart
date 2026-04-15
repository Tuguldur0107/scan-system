import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_strings.dart';
import '../../data/api/dashboard_api.dart';
import '../../data/api/users_api.dart';
import '../../widgets/ui_charts.dart';
import '../../widgets/ui_state_widgets.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _dashboardApi = DashboardApi();
  final _usersApi = UsersApi();

  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>>? _users;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _dashboardApi.summary(),
        _usersApi.list(),
      ]);
      _summary = results[0];
      _users = (results[1]['data'] as List).cast<Map<String, dynamic>>();
      _error = null;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.dashboard),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: S.dashboard),
            Tab(text: S.users),
          ],
        ),
      ),
      body: _loading
          ? const AppLoadingView(label: 'Loading admin workspace...')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _loadData)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboard(),
                    _buildUsers(),
                  ],
                ),
    );
  }

  Widget _buildDashboard() {
    if (_summary == null) return Center(child: Text(S.error));

    final totalScans = (_summary!['total_scans'] as int?) ?? 0;
    final activeUsers = (_summary!['active_users'] as int?) ?? 0;
    final projects = (_summary!['active_projects'] as int?) ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 760;
            final cards = [
              _StatCard(
                title: 'Total Scans',
                value: '$totalScans',
                icon: Icons.qr_code,
              ),
              _StatCard(
                title: 'Active Users',
                value: '$activeUsers',
                icon: Icons.people,
              ),
              _StatCard(
                title: 'Projects',
                value: '$projects',
                icon: Icons.folder,
              ),
              _StatCard(
                title: 'Last Scan',
                value: _summary!['last_scan']?.toString().substring(0, 10) ??
                    'N/A',
                icon: Icons.schedule,
              ),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards
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
        const SizedBox(height: 18),
        MiniBarChart(
          title: 'Platform Snapshot',
          values: [totalScans, activeUsers, projects],
          labels: const ['Scans', 'Users', 'Projects'],
          color: const Color(0xFF1A3A5F),
          emptyLabel: 'Платформын metric алга',
        ),
      ],
    );
  }

  Widget _buildUsers() {
    if (_users == null) return Center(child: Text(S.error));
    if (_users!.isEmpty) {
      return const AppEmptyView(
        icon: Icons.people_outline,
        title: 'Хэрэглэгч байхгүй',
        message: 'Энэ workspace дээр хэрэглэгч хараахан алга.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _users!.length,
      itemBuilder: (context, i) {
        final user = _users![i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text(user['username'] as String),
            subtitle: Text(user['role'] as String),
            trailing: Switch(
              value: user['is_active'] as bool? ?? true,
              onChanged: (v) async {
                await _usersApi.update(user['id'] as String, isActive: v);
                _loadData();
              },
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
