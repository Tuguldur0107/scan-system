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

    await authService.logout(body['refresh_token'] as String);
    return Response.json(body: {'message': 'Logged out'});
  } catch (e) {
    return Response.json(statusCode: 400, body: {'error': e.toString()});
  }
}
