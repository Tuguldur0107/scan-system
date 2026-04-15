import 'dart:io';

import '../repositories/tenant_repository.dart';
import '../repositories/user_repository.dart';

class SeedService {
  SeedService({required this.tenantRepo, required this.userRepo});

  final TenantRepository tenantRepo;
  final UserRepository userRepo;

  Future<void> seedSuperAdmin() async {
    // Check if system tenant exists
    var tenant = await tenantRepo.findBySlug('system');
    if (tenant == null) {
      tenant = await tenantRepo.create(
        name: 'System',
        slug: 'system',
      );
      print('Created system tenant');
    }

    final tenantId = tenant['id'] as String;
    final username =
        Platform.environment['SUPER_ADMIN_USERNAME'] ?? 'admin';
    final password =
        Platform.environment['SUPER_ADMIN_PASSWORD'] ?? 'admin123';

    final existing = await userRepo.findByUsernameAndTenant(
      username,
      tenantId,
    );

    if (existing == null) {
      await userRepo.create(
        tenantId: tenantId,
        username: username,
        password: password,
        role: 'super_admin',
      );
      print('Created super admin user: $username');
    }
  }
}
