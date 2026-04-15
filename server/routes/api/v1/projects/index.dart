import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/repositories/project_repository.dart';
import 'package:shared/shared.dart';

Future<Response> onRequest(RequestContext context) async {
  final tc = context.read<TenantContext>();
  final projectRepo = context.read<ProjectRepository>();

  switch (context.request.method) {
    case HttpMethod.get:
      final projects = await projectRepo.findByTenant(tc.tenantId);
      return Response.json(body: {'data': projects});

    case HttpMethod.post:
      if (!Roles.hasPermission(tc.role, Roles.tenantAdmin)) {
        return Response.json(
            statusCode: 403, body: {'error': 'Insufficient permissions'});
      }
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final project = await projectRepo.create(
        tenantId: tc.tenantId,
        name: body['name'] as String,
        description: body['description'] as String?,
        isOpen: body['is_open'] as bool? ?? true,
      );
      return Response.json(statusCode: 201, body: project);

    default:
      return Response.json(
          statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
