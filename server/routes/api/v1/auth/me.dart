import 'package:dart_frog/dart_frog.dart';
import 'package:server/jwt_service.dart';
import 'package:server/repositories/user_repository.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
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

  final userRepo = context.read<UserRepository>();
  final user = await userRepo.findById(payload['user_id'] as String);

  if (user == null) {
    return Response.json(statusCode: 404, body: {'error': 'User not found'});
  }

  return Response.json(body: user);
}
