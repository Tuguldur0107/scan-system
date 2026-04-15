import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/repositories/user_repository.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final tc = context.read<TenantContext>();
  final userRepo = context.read<UserRepository>();

  switch (context.request.method) {
    case HttpMethod.get:
      final user = await userRepo.findById(id);
      if (user == null || user['tenant_id'] != tc.tenantId) {
        return Response.json(statusCode: 404, body: {'error': 'User not found'});
      }
      return Response.json(body: user);

    case HttpMethod.put:
      final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final user = await userRepo.update(
        id,
        username: body['username'] as String?,
        password: body['password'] as String?,
        role: body['role'] as String?,
        isActive: body['is_active'] as bool?,
      );
      if (user == null) {
        return Response.json(statusCode: 404, body: {'error': 'User not found'});
      }
      return Response.json(body: user);

    case HttpMethod.delete:
      final deleted = await userRepo.delete(id);
      if (!deleted) {
        return Response.json(statusCode: 404, body: {'error': 'User not found'});
      }
      return Response.json(body: {'message': 'Deleted'});

    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
