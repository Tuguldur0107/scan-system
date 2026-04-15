import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/repositories/scan_repository.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.delete) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }

  final tc = context.read<TenantContext>();
  final scanRepo = context.read<ScanRepository>();

  final deleted = await scanRepo.delete(id, tc.tenantId);
  if (!deleted) {
    return Response.json(statusCode: 404, body: {'error': 'Scan not found'});
  }
  return Response.json(body: {'message': 'Deleted'});
}
