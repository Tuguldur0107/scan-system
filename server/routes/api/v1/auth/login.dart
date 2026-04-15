import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/services/auth_service.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }

  try {
    final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    final authService = context.read<AuthService>();

    final result = await authService.login(
      tenantSlug: body['tenant_slug'] as String,
      username: body['username'] as String,
      password: body['password'] as String,
    );

    return Response.json(body: result);
  } catch (e) {
    return Response.json(
      statusCode: 401,
      body: {'error': e.toString()},
    );
  }
}
