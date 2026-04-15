import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../providers/tenant_provider.dart';
import '../../providers/tenant_user_provider.dart';
import '../../widgets/ui_dialogs.dart';
import '../../widgets/ui_state_widgets.dart';
import '../../widgets/ui_surfaces.dart';

class TenantUsersScreen extends ConsumerStatefulWidget {
  const TenantUsersScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<TenantUsersScreen> createState() => _TenantUsersScreenState();
}

class _TenantUsersScreenState extends ConsumerState<TenantUsersScreen> {
  String? _loadedTenantId;

  void _ensureTenantLoaded(TenantInfo tenant) {
    if (_loadedTenantId == tenant.id) return;
    _loadedTenantId = tenant.id;
    Future.microtask(() async {
      ref.read(activeTenantProvider.notifier).state = tenant;
      await ref.read(tenantUsersProvider.notifier).loadUsers(tenant.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(tenantBySlugProvider(widget.slug));
    if (tenant == null) {
      return Scaffold(
        appBar: AppBar(title: Text(S.users)),
        body: const Center(child: Text('Tenant сонгогдоогүй байна')),
      );
    }
    _ensureTenantLoaded(tenant);

    final usersAsync = ref.watch(tenantUsersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tenant/${tenant.slug}'),
        ),
        title: Text('${S.users} — ${tenant.name}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, tenant.id),
        icon: const Icon(Icons.person_add),
        label: const Text('Хэрэглэгч нэмэх'),
      ),
      body: usersAsync.when(
        loading: () => const AppLoadingView(label: 'Loading users...'),
        error: (e, _) => AppErrorView(
          message: '$e',
          onRetry: () =>
              ref.read(tenantUsersProvider.notifier).loadUsers(tenant.id),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const AppEmptyView(
              icon: Icons.people_outline,
              title: 'Хэрэглэгч байхгүй',
              message: 'Шинэ хэрэглэгч нэмнэ үү',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            itemBuilder: (context, i) {
              final user = users[i];
              return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppSurfaceCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: user.isActive
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.errorContainer,
                        child: Icon(
                          user.role == 'tenant_admin'
                              ? Icons.admin_panel_settings
                              : Icons.person,
                          color: user.isActive
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                      title: Text(user.username),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: user.role == 'tenant_admin'
                                  ? Colors.orange.withAlpha(30)
                                  : Colors.blue.withAlpha(30),
                            ),
                            child: Text(
                              user.role == 'tenant_admin'
                                  ? 'Админ'
                                  : 'Оператор',
                              style: TextStyle(
                                fontSize: 11,
                                color: user.role == 'tenant_admin'
                                    ? Colors.orange
                                    : Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: user.isActive
                                  ? Colors.green.withAlpha(30)
                                  : Colors.red.withAlpha(30),
                            ),
                            child: Text(
                              user.isActive ? 'Идэвхтэй' : 'Идэвхгүй',
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    user.isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          final notifier =
                              ref.read(tenantUsersProvider.notifier);
                          try {
                            switch (action) {
                              case 'toggle':
                                await notifier.toggleActive(tenant.id, user.id);
                                break;
                              case 'make_admin':
                                await notifier.updateRole(
                                  tenant.id,
                                  user.id,
                                  'tenant_admin',
                                );
                                break;
                              case 'make_operator':
                                await notifier.updateRole(
                                  tenant.id,
                                  user.id,
                                  'operator',
                                );
                                break;
                              case 'delete':
                                await _confirmDelete(context, tenant.id, user);
                                break;
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Үйлдэл амжилтгүй: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  user.isActive
                                      ? Icons.block
                                      : Icons.check_circle,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  user.isActive
                                      ? 'Идэвхгүй болгох'
                                      : 'Идэвхжүүлэх',
                                ),
                              ],
                            ),
                          ),
                          if (user.role != 'tenant_admin')
                            const PopupMenuItem(
                              value: 'make_admin',
                              child: Row(
                                children: [
                                  Icon(Icons.admin_panel_settings, size: 20),
                                  SizedBox(width: 8),
                                  Text('Админ болгох'),
                                ],
                              ),
                            ),
                          if (user.role != 'operator')
                            const PopupMenuItem(
                              value: 'make_operator',
                              child: Row(
                                children: [
                                  Icon(Icons.person, size: 20),
                                  SizedBox(width: 8),
                                  Text('Оператор болгох'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Устгах',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ));
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, String tenantId) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'operator';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialogShell(
          title: 'Хэрэглэгч нэмэх',
          subtitle: 'Username, password, role-оор шинэ хэрэглэгч үүсгэнэ.',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(S.save),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Хэрэглэгчийн нэр',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Нууц үг',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Эрх',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security),
                ),
                items: const [
                  DropdownMenuItem(value: 'operator', child: Text('Оператор')),
                  DropdownMenuItem(value: 'tenant_admin', child: Text('Админ')),
                ],
                onChanged: (v) => setDialogState(() => selectedRole = v!),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true &&
        usernameController.text.trim().isNotEmpty &&
        passwordController.text.isNotEmpty) {
      try {
        await ref.read(tenantUsersProvider.notifier).addUser(
              tenantId: tenantId,
              username: usernameController.text.trim(),
              password: passwordController.text,
              role: selectedRole,
            );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хэрэглэгч үүсгэж чадсангүй: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String tenantId,
    TenantUser user,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmDialog(
        title: 'Устгах',
        message: '"${user.username}" хэрэглэгчийг устгах уу?',
        confirmLabel: S.delete,
        destructive: true,
      ),
    );

    if (result == true) {
      await ref
          .read(tenantUsersProvider.notifier)
          .deleteUser(tenantId, user.id);
    }
  }
}
