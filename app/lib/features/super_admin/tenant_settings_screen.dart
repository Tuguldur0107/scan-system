import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/ui_dialogs.dart';
import '../../widgets/ui_forms.dart';
import '../../widgets/ui_surfaces.dart';

class TenantSettingsScreen extends ConsumerStatefulWidget {
  const TenantSettingsScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<TenantSettingsScreen> createState() =>
      _TenantSettingsScreenState();
}

class _TenantSettingsScreenState extends ConsumerState<TenantSettingsScreen> {
  late TextEditingController _nameController;
  bool _saving = false;
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(tenantBySlugProvider(widget.slug));
    final activeTenant = ref.watch(activeTenantProvider);
    if (tenant == null) {
      return Scaffold(
        appBar: AppBar(title: Text(S.settings)),
        body: const Center(child: Text('Tenant сонгогдоогүй байна')),
      );
    }
    if (activeTenant?.id != tenant.id) {
      Future.microtask(() {
        ref.read(activeTenantProvider.notifier).state = tenant;
      });
    }

    if (_nameController.text.isEmpty && !_saving) {
      _nameController.text = tenant.name;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tenant/${tenant.slug}'),
        ),
        title: const Text('Tenant Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          _settingsHero(context, tenant),
          const SizedBox(height: 18),
          _identityPanel(context, tenant),
          const SizedBox(height: 18),
          _statusPanel(context, tenant),
          const SizedBox(height: 18),
          _dangerPanel(context),
        ],
      ),
    );
  }

  Widget _settingsHero(BuildContext context, TenantInfo tenant) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF173B61), Color(0xFF0F6C5A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Identity and control',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            tenant.name,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tenant status, naming, and destructive actions are managed here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }

  Widget _identityPanel(BuildContext context, TenantInfo tenant) {
    return AppFormPanel(
      title: 'Identity',
      subtitle: 'Tenant name, slug, and system reference.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Байгууллагын нэр',
              prefixIcon: Icon(Icons.business_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            readOnly: true,
            controller: TextEditingController(text: tenant.slug),
            decoration: const InputDecoration(
              labelText: 'Код (slug)',
              prefixIcon: Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            readOnly: true,
            controller: TextEditingController(text: tenant.id),
            decoration: const InputDecoration(
              labelText: 'ID',
              prefixIcon: Icon(Icons.fingerprint),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : () => _saveTenant(context, tenant),
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Хадгалж байна...' : S.save),
          ),
        ],
      ),
    );
  }

  Widget _statusPanel(BuildContext context, TenantInfo tenant) {
    final active = tenant.isActive;
    final accent = active ? const Color(0xFF0F8B68) : const Color(0xFFB84C4C);
    return AppSurfaceCard(
      padding: const EdgeInsets.all(22),
      radius: 28,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withAlpha(18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(active ? Icons.check_circle : Icons.pause_circle,
                color: accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(active ? 'Идэвхтэй tenant' : 'Идэвхгүй tenant',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'Хэрэглэгчид нэвтрэх, ажиллах боломжтой.'
                      : 'Хэрэглэгчид нэвтрэх болон ажиллагаа хязгаарлагдана.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch(
            value: active,
            onChanged: _updatingStatus
                ? null
                : (v) => _toggleStatus(context, tenant, v),
          ),
        ],
      ),
    );
  }

  Widget _dangerPanel(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(22),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppInlineBanner(
            message:
                'Tenant, users, tasks, and scans бүгд хамт устах эрсдэлтэй.',
            error: true,
          ),
          const SizedBox(height: 16),
          Text(
            'Danger Zone',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Байгууллага устгах'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final tenant = ref.read(activeTenantProvider);
    if (tenant == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmDialog(
        title: 'Байгууллага устгах',
        message:
            '"${tenant.name}" байгууллагыг устгах уу?\n\nБүх хэрэглэгч, даалгавар, скан устна!',
        confirmLabel: S.delete,
        destructive: true,
      ),
    );
    if (result == true) {
      try {
        await ref.read(tenantsProvider.notifier).deleteTenant(tenant.id);
        ref.read(activeTenantProvider.notifier).state = null;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Байгууллага устгагдлаа')),
          );
          context.go('/super-admin');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Устгаж чадсангүй: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveTenant(BuildContext context, TenantInfo tenant) async {
    setState(() => _saving = true);
    try {
      final updated = await ref.read(tenantsProvider.notifier).updateTenant(
            tenant.id,
            name: _nameController.text.trim(),
          );
      ref.read(activeTenantProvider.notifier).state = updated;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хадгалагдлаа')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Хадгалж чадсангүй: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleStatus(
      BuildContext context, TenantInfo tenant, bool isActive) async {
    setState(() => _updatingStatus = true);
    try {
      final updated = await ref.read(tenantsProvider.notifier).updateTenant(
            tenant.id,
            isActive: isActive,
          );
      ref.read(activeTenantProvider.notifier).state = updated;
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Төлөв шинэчилж чадсангүй: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }
}
