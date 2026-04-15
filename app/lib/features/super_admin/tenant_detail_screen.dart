import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/tenant_provider.dart';
import '../../widgets/ui_surfaces.dart';

class TenantDetailScreen extends ConsumerWidget {
  const TenantDetailScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(tenantBySlugProvider(slug));

    if (tenant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Байгууллага')),
        body: const Center(child: Text('Tenant олдсонгүй')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/super-admin'),
        ),
        title: const Text('Tenant Workspace'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tenant.slug,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          _TenantHero(tenant: tenant),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people_alt_outlined,
                  value: '${tenant.userCount}',
                  label: 'Users',
                  accent: const Color(0xFF1A3A5F),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.qr_code_2,
                  value: '${tenant.scanCount}',
                  label: 'Scans',
                  accent: const Color(0xFF0F6C5A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  value: tenant.isActive ? 'LIVE' : 'PAUSED',
                  label: 'Status',
                  accent: tenant.isActive
                      ? const Color(0xFF0F8B68)
                      : const Color(0xFFB84C4C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Command Center',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.people,
            title: 'Хэрэглэгчид',
            subtitle: 'Эрх, идэвхжилт, бүтэц',
            accent: const Color(0xFF1A3A5F),
            onTap: () => context.go('/tenant/${tenant.slug}/users'),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.task_alt,
            title: 'Даалгавар',
            subtitle: 'Scan workflow-ийн operational source',
            accent: const Color(0xFF8C5E16),
            onTap: () => context.go('/tenant/${tenant.slug}/tasks'),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.table_chart,
            title: 'Дата',
            subtitle: 'Filter, inspect, export',
            accent: const Color(0xFF0F6C5A),
            onTap: () => context.go('/tenant/${tenant.slug}/data'),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.bar_chart,
            title: 'Дашбоард',
            subtitle: 'Volumes, activity, pending signals',
            accent: const Color(0xFF5A3B78),
            onTap: () => context.go('/tenant/${tenant.slug}/dashboard'),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.settings,
            title: 'Тохиргоо',
            subtitle: 'Tenant identity and status control',
            accent: const Color(0xFF4A5960),
            onTap: () => context.go('/tenant/${tenant.slug}/settings'),
          ),
        ],
      ),
    );
  }
}

class _TenantHero extends StatelessWidget {
  const _TenantHero({required this.tenant});

  final TenantInfo tenant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF173B61),
            Color(0xFF0F6C5A),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : '?',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenant.name,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  tenant.isActive
                      ? 'Tenant operational environment is active.'
                      : 'Tenant is paused and currently restricted.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: accent,
                ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(18),
        radius: 26,
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: accent.withAlpha(18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}
