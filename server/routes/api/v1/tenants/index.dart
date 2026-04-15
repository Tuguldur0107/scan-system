import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/repositories/tenant_repository.dart';
import 'package:server/repositories/user_repository.dart';

Future<Response> onRequest(RequestContext context) async {
  final tenantRepo = context.read<TenantRepository>();
  final userRepo = context.read<UserRepository>();

  switch (context.request.method) {
    case HttpMethod.get:
      final tenants = await tenantRepo.findAll();
      return Response.json(body: {'data': tenants});

    case HttpMethod.post:
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final tenant = await tenantRepo.create(
        name: body['name'] as String,
        slug: body['slug'] as String,
        settings: body['settings'] as Map<String, dynamic>? ?? {},
      );
      final adminUsername = body['admin_username'] as String?;
      final adminPassword = body['admin_password'] as String?;
      if (adminUsername != null &&
          adminUsername.isNotEmpty &&
          adminPassword != null &&
          adminPassword.isNotEmpty) {
        await userRepo.create(
          tenantId: tenant['id'] as String,
          username: adminUsername,
          password: adminPassword,
          role: 'tenant_admin',
        );
      }
      return Response.json(statusCode: 201, body: tenant);

    default:
      return Response.json(
          statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
