import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/jwt_service.dart';
import 'package:server/repositories/user_repository.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }

  final authHeader = context.request.headers['authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    return Response.json(statusCode: 401, body: {'error': 'Unauthorized'});
  }

  final token = authHeader.substring(7);
  final payload = JwtService.instance.verifyToken(token);
  if (payload == null || payload['type'] != 'access') {
    return Response.json(statusCode: 401, body: {'error': 'Invalid token'});
  }

  try {
    final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    final newPassword = body['new_password'] as String;

    if (newPassword.length < 6) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Password must be at least 6 characters'},
      );
    }

    final userRepo = context.read<UserRepository>();
    await userRepo.updatePassword(payload['user_id'] as String, newPassword);

    return Response.json(body: {'message': 'Password changed successfully'});
  } catch (e) {
    return Response.json(statusCode: 400, body: {'error': e.toString()});
  }
}
