import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/repositories/tenant_repository.dart';
import 'package:server/repositories/user_repository.dart';

Future<Response> onRequest(
  RequestContext context,
  String id,
  String userId,
) async {
  final tenantRepo = context.read<TenantRepository>();
  final userRepo = context.read<UserRepository>();

  final tenant = await tenantRepo.findById(id);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'Tenant not found'});
  }

  final existingUser = await userRepo.findById(userId);
  if (existingUser == null || existingUser['tenant_id'] != id) {
    return Response.json(statusCode: 404, body: {'error': 'User not found'});
  }

  switch (context.request.method) {
    case HttpMethod.get:
      return Response.json(body: existingUser);

    case HttpMethod.put:
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final updated = await userRepo.update(
        userId,
        username: body['username'] as String?,
        password: body['password'] as String?,
        role: body['role'] as String?,
        isActive: body['is_active'] as bool?,
      );
      return Response.json(body: updated);

    case HttpMethod.delete:
      final deleted = await userRepo.delete(userId);
      if (!deleted) {
        return Response.json(
            statusCode: 404, body: {'error': 'User not found'});
      }
      return Response.json(body: {'message': 'Deleted'});

    default:
      return Response.json(
          statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
