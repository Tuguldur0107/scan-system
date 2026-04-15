import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/middleware/role_guard.dart';
import 'package:shared/shared.dart';

Handler middleware(Handler handler) {
  return handler
      .use(roleGuard(Roles.tenantAdmin))
      .use(authMiddleware());
}
