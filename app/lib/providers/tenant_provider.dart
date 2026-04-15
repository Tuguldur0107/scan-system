import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/tenants_api.dart';

class TenantInfo {
  const TenantInfo({
    required this.id,
    required this.name,
    required this.slug,
    this.isActive = true,
    this.userCount = 0,
    this.scanCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final bool isActive;
  final int userCount;
  final int scanCount;

  factory TenantInfo.fromJson(Map<String, dynamic> json) => TenantInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        isActive: json['is_active'] as bool? ?? true,
        userCount: json['user_count'] as int? ?? 0,
        scanCount: json['scan_count'] as int? ?? 0,
      );

  TenantInfo copyWith({
    String? name,
    String? slug,
    bool? isActive,
    int? userCount,
    int? scanCount,
  }) =>
      TenantInfo(
        id: id,
        name: name ?? this.name,
        slug: slug ?? this.slug,
        isActive: isActive ?? this.isActive,
        userCount: userCount ?? this.userCount,
        scanCount: scanCount ?? this.scanCount,
      );
}

final activeTenantProvider = StateProvider<TenantInfo?>((ref) => null);

class TenantsNotifier extends StateNotifier<AsyncValue<List<TenantInfo>>> {
  TenantsNotifier() : super(const AsyncValue.data([]));

  final _api = TenantsApi();

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final result = await _api.list();
      final tenants = (result['data'] as List<dynamic>)
          .map((item) => TenantInfo.fromJson(item as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(tenants);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<TenantInfo> addTenant({
    required String name,
    required String slug,
    required String adminUsername,
    required String adminPassword,
  }) async {
    final result = await _api.create(
      name: name,
      slug: slug,
      adminUsername: adminUsername,
      adminPassword: adminPassword,
    );
    final tenant = TenantInfo.fromJson(result);
    final current = state.valueOrNull ?? const <TenantInfo>[];
    state = AsyncValue.data([tenant, ...current]);
    return tenant;
  }

  Future<TenantInfo> updateTenant(
    String id, {
    String? name,
    String? slug,
    bool? isActive,
  }) async {
    final result = await _api.update(
      id,
      name: name,
      slug: slug,
      isActive: isActive,
    );
    final updated = TenantInfo.fromJson(result);
    final current = [...?state.valueOrNull];
    final index = current.indexWhere((tenant) => tenant.id == id);
    if (index >= 0) {
      current[index] = updated;
      state = AsyncValue.data(current);
    } else {
      state = AsyncValue.data([updated, ...current]);
    }
    return updated;
  }

  Future<void> toggleActive(String id) async {
    final current = state.valueOrNull ?? const <TenantInfo>[];
    final index = current.indexWhere((tenant) => tenant.id == id);
    if (index < 0) return;
    await updateTenant(id, isActive: !current[index].isActive);
  }

  Future<void> deleteTenant(String id) async {
    await _api.delete(id);
    final current = state.valueOrNull ?? const <TenantInfo>[];
    state = AsyncValue.data(
      current.where((tenant) => tenant.id != id).toList(),
    );
  }
}

final tenantsProvider =
    StateNotifierProvider<TenantsNotifier, AsyncValue<List<TenantInfo>>>((ref) {
  final notifier = TenantsNotifier();
  Future.microtask(notifier.load);
  return notifier;
});

final tenantBySlugProvider = Provider.family<TenantInfo?, String>((ref, slug) {
  final activeTenant = ref.watch(activeTenantProvider);
  if (activeTenant != null && activeTenant.slug == slug) {
    return activeTenant;
  }

  final tenants =
      ref.watch(tenantsProvider).valueOrNull ?? const <TenantInfo>[];
  for (final tenant in tenants) {
    if (tenant.slug == slug) return tenant;
  }
  return null;
});
