import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/repositories/project_repository.dart';
import 'package:shared/shared.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final tc = context.read<TenantContext>();
  final projectRepo = context.read<ProjectRepository>();

  switch (context.request.method) {
    case HttpMethod.get:
      final project = await projectRepo.findById(id, tc.tenantId);
      if (project == null) {
        return Response.json(
            statusCode: 404, body: {'error': 'Project not found'});
      }
      return Response.json(body: project);

    case HttpMethod.put:
      if (!Roles.hasPermission(tc.role, Roles.tenantAdmin)) {
        return Response.json(
            statusCode: 403, body: {'error': 'Insufficient permissions'});
      }
      final body =
          jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final project = await projectRepo.update(
        id,
        tc.tenantId,
        name: body['name'] as String?,
        description: body['description'] as String?,
        isOpen: body['is_open'] as bool?,
      );
      if (project == null) {
        return Response.json(
            statusCode: 404, body: {'error': 'Project not found'});
      }
      return Response.json(body: project);

    case HttpMethod.delete:
      if (!Roles.hasPermission(tc.role, Roles.tenantAdmin)) {
        return Response.json(
            statusCode: 403, body: {'error': 'Insufficient permissions'});
      }
      final deleted = await projectRepo.delete(id, tc.tenantId);
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
