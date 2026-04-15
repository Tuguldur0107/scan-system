import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/repositories/project_repository.dart';
import 'package:server/repositories/tenant_repository.dart';

Future<Response> onRequest(
  RequestContext context,
  String id,
  String projectId,
) async {
  final tenantRepo = context.read<TenantRepository>();
  final projectRepo = context.read<ProjectRepository>();

  final tenant = await tenantRepo.findById(id);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'Tenant not found'});
  }

  final existing = await projectRepo.findById(projectId, id);
  if (existing == null) {
    return Response.json(statusCode: 404, body: {'error': 'Project not found'});
  }

  switch (context.request.method) {
    case HttpMethod.get:
      return Response.json(body: existing);

    case HttpMethod.put:
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final updated = await projectRepo.update(
        projectId,
        id,
        name: body['name'] as String?,
        description: body['description'] as String?,
        isOpen: body['is_open'] as bool?,
      );
      return Response.json(body: updated);

    case HttpMethod.delete:
      final deleted = await projectRepo.delete(projectId, id);
      if (!deleted) {
        return Response.json(
            statusCode: 404, body: {'error': 'Project not found'});
      }
      return Response.json(body: {'message': 'Deleted'});

    default:
      return Response.json(
          statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
