import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/repositories/scan_repository.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }

  final tc = context.read<TenantContext>();
  final scanRepo = context.read<ScanRepository>();
  final days = int.tryParse(
        context.request.uri.queryParameters['days'] ?? '30',
      ) ?? 30;

  final data = await scanRepo.getTimeline(tc.tenantId, days: days);
  return Response.json(body: {'data': data});
}
