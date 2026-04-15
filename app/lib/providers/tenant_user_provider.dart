import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/users_api.dart';

class TenantUser {
  const TenantUser({
    required this.id,
    required this.tenantId,
    required this.username,
    this.role = 'operator',
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String tenantId;
  final String username;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  factory TenantUser.fromJson(Map<String, dynamic> json) => TenantUser(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        username: json['username'] as String,
        role: json['role'] as String? ?? 'operator',
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

class TenantUsersNotifier extends StateNotifier<AsyncValue<List<TenantUser>>> {
  TenantUsersNotifier() : super(const AsyncValue.data([]));

  final _api = UsersApi();

  Future<void> loadUsers(String tenantId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.list(tenantId: tenantId);
      final users = (result['data'] as List<dynamic>)
          .map((item) => TenantUser.fromJson(item as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(users);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addUser({
    required String tenantId,
    required String username,
    required String password,
    required String role,
  }) async {
    final result = await _api.create(
      tenantId: tenantId,
      username: username,
      password: password,
      role: role,
    );
    final user = TenantUser.fromJson(result);
    final current = state.valueOrNull ?? const <TenantUser>[];
    state = AsyncValue.data([user, ...current]);
  }

  Future<void> toggleActive(String tenantId, String id) async {
    final current = state.valueOrNull ?? const <TenantUser>[];
    final index = current.indexWhere((user) => user.id == id);
    if (index < 0) return;

    final updated = await _api.update(
      id,
      tenantId: tenantId,
      isActive: !current[index].isActive,
    );
    _replaceUser(TenantUser.fromJson(updated));
  }

  Future<void> updateRole(String tenantId, String id, String role) async {
    final updated = await _api.update(
      id,
      tenantId: tenantId,
      role: role,
    );
    _replaceUser(TenantUser.fromJson(updated));
  }

  Future<void> deleteUser(String tenantId, String id) async {
    await _api.delete(id, tenantId: tenantId);
    final current = state.valueOrNull ?? const <TenantUser>[];
    state = AsyncValue.data(current.where((user) => user.id != id).toList());
  }

  void _replaceUser(TenantUser updated) {
    final current = [...?(state.valueOrNull)];
    final index = current.indexWhere((user) => user.id == updated.id);
    if (index < 0) {
      state = AsyncValue.data([updated, ...current]);
      return;
    }
    current[index] = updated;
    state = AsyncValue.data(current);
  }
}

final tenantUsersProvider =
    StateNotifierProvider<TenantUsersNotifier, AsyncValue<List<TenantUser>>>(
        (ref) {
  return TenantUsersNotifier();
});
