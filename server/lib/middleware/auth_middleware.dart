import 'package:dart_frog/dart_frog.dart';

import '../jwt_service.dart';

/// Extracts and verifies the JWT from the Authorization header.
/// Sets userId, tenantId, and role on the request context.
Middleware authMiddleware() {
  return (handler) {
    return (context) async {
      final authHeader = context.request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.json(
          statusCode: 401,
          body: {'error': 'Missing or invalid authorization header'},
        );
      }

      final token = authHeader.substring(7);
      final payload = JwtService.instance.verifyToken(token);

      if (payload == null || payload['type'] != 'access') {
        return Response.json(
          statusCode: 401,
          body: {'error': 'Invalid or expired token'},
        );
      }

      final updatedContext = context
          .provide<String>(() => payload['user_id'] as String)
          .provide<TenantContext>(
            () => TenantContext(
              tenantId: payload['tenant_id'] as String,
              userId: payload['user_id'] as String,
              role: payload['role'] as String,
            ),
          );

      return handler(updatedContext);
    };
  };
}

class TenantContext {
  const TenantContext({
    required this.tenantId,
    required this.userId,
    required this.role,
  });

  final String tenantId;
  final String userId;
  final String role;
}
