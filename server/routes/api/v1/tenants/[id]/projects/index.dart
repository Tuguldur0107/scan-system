import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/repositories/project_repository.dart';
import 'package:server/repositories/tenant_repository.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final tenantRepo = context.read<TenantRepository>();
  final projectRepo = context.read<ProjectRepository>();

  final tenant = await tenantRepo.findById(id);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'Tenant not found'});
  }

  switch (context.request.method) {
    case HttpMethod.get:
      final projects = await projectRepo.findByTenant(id);
      return Response.json(body: {'data': projects});

    case HttpMethod.post:
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final project = await projectRepo.create(
        tenantId: id,
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
