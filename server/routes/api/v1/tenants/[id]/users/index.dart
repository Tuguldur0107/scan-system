import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/repositories/tenant_repository.dart';
import 'package:server/repositories/user_repository.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final tenantRepo = context.read<TenantRepository>();
  final userRepo = context.read<UserRepository>();

  final tenant = await tenantRepo.findById(id);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'Tenant not found'});
  }

  switch (context.request.method) {
    case HttpMethod.get:
      final users = await userRepo.findByTenant(id);
      return Response.json(body: {'data': users});

    case HttpMethod.post:
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final user = await userRepo.create(
        tenantId: id,
        username: body['username'] as String,
        password: body['password'] as String,
        role: body['role'] as String,
      );
      return Response.json(statusCode: 201, body: user);

    default:
      return Response.json(
          statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
