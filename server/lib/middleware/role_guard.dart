import 'package:dart_frog/dart_frog.dart';
import 'package:shared/shared.dart';

import 'auth_middleware.dart';

/// Only allows requests from users with the specified role or higher.
Middleware roleGuard(String requiredRole) {
  return (handler) {
    return (context) async {
      final tc = context.read<TenantContext>();
      if (!Roles.hasPermission(tc.role, requiredRole)) {
        return Response.json(
          statusCode: 403,
          body: {'error': 'Insufficient permissions'},
        );
      }
      return handler(context);
    };
  };
}
