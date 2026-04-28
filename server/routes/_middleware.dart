import 'package:dart_frog/dart_frog.dart';

import 'package:server/db.dart';
import 'package:server/middleware/cors_middleware.dart';
import 'package:server/repositories/tenant_repository.dart';
import 'package:server/repositories/user_repository.dart';
import 'package:server/repositories/project_repository.dart';
import 'package:server/repositories/scan_repository.dart';
import 'package:server/repositories/refresh_token_repository.dart';
import 'package:server/repositories/audit_repository.dart';
import 'package:server/repositories/epc_counter_repository.dart';
import 'package:server/services/auth_service.dart';
import 'package:server/services/seed_service.dart';

bool _initialized = false;

Handler middleware(Handler handler) {
  // Order: outermost (.use last) runs first. Dependencies must be outer.
  return handler
      .use(_initMiddleware())
      .use(
        provider<AuthService>(
          (ctx) => AuthService(
            tenantRepo: ctx.read<TenantRepository>(),
            userRepo: ctx.read<UserRepository>(),
            refreshTokenRepo: ctx.read<RefreshTokenRepository>(),
          ),
        ),
      )
      .use(provider<AuditRepository>((_) => AuditRepository()))
      .use(provider<RefreshTokenRepository>((_) => RefreshTokenRepository()))
      .use(provider<EpcCounterRepository>((_) => EpcCounterRepository()))
      .use(provider<ScanRepository>((_) => ScanRepository()))
      .use(provider<ProjectRepository>((_) => ProjectRepository()))
      .use(provider<UserRepository>((_) => UserRepository()))
      .use(provider<TenantRepository>((_) => TenantRepository()))
      .use(corsMiddleware());
}

Middleware _initMiddleware() {
  return (handler) {
    return (context) async {
      if (!_initialized) {
        await Database.instance.initialize();
        await Database.instance.runMigrations();
        await SeedService(
          tenantRepo: TenantRepository(),
          userRepo: UserRepository(),
        ).seedSuperAdmin();
        _initialized = true;
      }
      return handler(context);
    };
  };
}
