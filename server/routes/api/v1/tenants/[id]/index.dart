import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/repositories/tenant_repository.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final tenantRepo = context.read<TenantRepository>();

  switch (context.request.method) {
    case HttpMethod.get:
      final tenant = await tenantRepo.findById(id);
      if (tenant == null) {
        return Response.json(statusCode: 404, body: {'error': 'Tenant not found'});
      }
      return Response.json(body: tenant);

    case HttpMethod.put:
      final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final tenant = await tenantRepo.update(
        id,
        name: body['name'] as String?,
        slug: body['slug'] as String?,
        isActive: body['is_active'] as bool?,
        settings: body['settings'] as Map<String, dynamic>?,
      );
      if (tenant == null) {
        return Response.json(statusCode: 404, body: {'error': 'Tenant not found'});
      }
      return Response.json(body: tenant);

    case HttpMethod.delete:
      final deleted = await tenantRepo.delete(id);
      if (!deleted) {
        return Response.json(statusCode: 404, body: {'error': 'Tenant not found'});
      }
      return Response.json(body: {'message': 'Deleted'});

    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
