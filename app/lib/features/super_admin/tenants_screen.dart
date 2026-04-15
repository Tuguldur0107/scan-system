import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/ui_dialogs.dart';
import '../../widgets/ui_state_widgets.dart';
import '../../widgets/ui_surfaces.dart';

class TenantsScreen extends ConsumerWidget {
  const TenantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(tenantsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Workspace'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withAlpha(220),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Super Admin',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: S.logout,
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/super-admin/create-tenant'),
        icon: const Icon(Icons.add_business),
        label: const Text('Байгууллага нэмэх'),
      ),
      body: tenantsAsync.when(
        loading: () => const AppLoadingView(label: 'Loading tenants...'),
        error: (e, _) => AppErrorView(
          message: '$e',
          onRetry: () => ref.read(tenantsProvider.notifier).load(),
        ),
        data: (tenants) {
          final activeCount = tenants.where((tenant) => tenant.isActive).length;
          final totalUsers = tenants.fold<int>(
            0,
            (sum, tenant) => sum + tenant.userCount,
          );
          final totalScans = tenants.fold<int>(
            0,
            (sum, tenant) => sum + tenant.scanCount,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              AppReveal(
                child: _HeroPanel(
                  tenantCount: tenants.length,
                  activeCount: activeCount,
                  totalUsers: totalUsers,
                  totalScans: totalScans,
                ),
              ),
              const SizedBox(height: 20),
              if (tenants.isEmpty)
                _EmptyPanel(
                    onCreate: () => context.go('/super-admin/create-tenant'))
              else ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        'Байгууллагууд',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Spacer(),
                      Text(
                        '${tenants.length} total',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                ...tenants.map((tenant) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: AppReveal(child: _TenantCard(tenant: tenant)),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.tenantCount,
    required this.activeCount,
    required this.totalUsers,
    required this.totalScans,
  });

  final int tenantCount;
  final int activeCount;
  final int totalUsers;
  final int totalScans;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F6C5A),
            Color(0xFF1A3A5F),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withAlpha(45),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Үйл ажиллагааны удирдлага',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Multi-tenant barcode\noperations center',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  height: 1.02,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            'Байгууллагын идэвх, хэрэглэгчийн тархалт, нийт сканы урсгалыг нэг дэлгэцээс хянах төв.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withAlpha(210),
                ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroStat(label: 'Tenants', value: '$tenantCount'),
              _HeroStat(label: 'Active', value: '$activeCount'),
              _HeroStat(label: 'Users', value: '$totalUsers'),
              _HeroStat(label: 'Scans', value: '$totalScans'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return AppEmptyView(
      icon: Icons.apartment_rounded,
      title: 'Байгууллага бүртгэлгүй байна',
      message:
          'Шинэ tenant үүсгээд хэрэглэгч, даалгавар, скан урсгалаа эхлүүлнэ үү.',
      action: FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_business),
        label: const Text('Эхний байгууллага үүсгэх'),
      ),
    );
  }
}

class _TenantCard extends ConsumerWidget {
  const _TenantCard({required this.tenant});
  final TenantInfo tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () {
        ref.read(activeTenantProvider.notifier).state = tenant;
        context.go('/tenant/${tenant.slug}');
      },
      child: AppSurfaceCard(
        radius: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: tenant.isActive
                        ? const LinearGradient(
                            colors: [Color(0xFFD9F5EA), Color(0xFFB4E9D6)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFF2EAEA), Color(0xFFE6D7D7)],
                          ),
                  ),
                  child: Center(
                    child: Text(
                      tenant.name.isNotEmpty
                          ? tenant.name.substring(0, 1).toUpperCase()
                          : '?',
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontSize: 30,
                                color: tenant.isActive
                                    ? const Color(0xFF0F6C5A)
                                    : const Color(0xFF7A4A4A),
                              ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tenant.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        tenant.slug,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(isActive: tenant.isActive),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'toggle':
                        ref
                            .read(tenantsProvider.notifier)
                            .toggleActive(tenant.id);
                        break;
                      case 'delete':
                        _confirmDelete(context, ref);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(
                          tenant.isActive ? 'Идэвхгүй болгох' : 'Идэвхжүүлэх'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Устгах',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricTile(
                  accent: const Color(0xFF1A3A5F),
                  icon: Icons.people_alt_outlined,
                  label: 'Users',
                  value: '${tenant.userCount}',
                ),
                _MetricTile(
                  accent: const Color(0xFF0F6C5A),
                  icon: Icons.qr_code_2,
                  label: 'Scans',
                  value: '${tenant.scanCount}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Удирдлагын орчин руу орох',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded, color: scheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AppDialogShell(
        title: 'Байгууллага устгах?',
        subtitle: 'Энэ үйлдэл буцаагдахгүй.',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(tenantsProvider.notifier)
                    .deleteTenant(tenant.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Байгууллага устгагдлаа')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Устгаж чадсангүй: $e')),
                  );
                }
              }
            },
            child: Text(S.delete),
          ),
        ],
        child:
            Text('"${tenant.name}" байгууллагыг устгахдаа итгэлтэй байна уу?'),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF0F8B68) : const Color(0xFFB84C4C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Идэвхтэй' : 'Идэвхгүй',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.accent,
    required this.icon,
    required this.label,
    required this.value,
  });

  final Color accent;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 142,
        child: AppSurfaceCard(
          padding: const EdgeInsets.all(14),
          radius: 20,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withAlpha(24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: accent,
                          ),
                    ),
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}
