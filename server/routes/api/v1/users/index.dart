import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/repositories/user_repository.dart';

Future<Response> onRequest(RequestContext context) async {
  final tc = context.read<TenantContext>();
  final userRepo = context.read<UserRepository>();

  switch (context.request.method) {
    case HttpMethod.get:
      final users = await userRepo.findByTenant(tc.tenantId);
      return Response.json(body: {'data': users});

    case HttpMethod.post:
      final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final user = await userRepo.create(
        tenantId: tc.tenantId,
        username: body['username'] as String,
        password: body['password'] as String,
        role: body['role'] as String,
      );
      return Response.json(statusCode: 201, body: user);

    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
