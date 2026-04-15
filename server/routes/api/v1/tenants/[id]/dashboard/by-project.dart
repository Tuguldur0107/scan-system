import 'package:dart_frog/dart_frog.dart';
import 'package:server/repositories/scan_repository.dart';
import 'package:server/repositories/tenant_repository.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final tenantRepo = context.read<TenantRepository>();
  final scanRepo = context.read<ScanRepository>();

  final tenant = await tenantRepo.findById(id);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'Tenant not found'});
  }

  if (context.request.method != HttpMethod.get) {
    return Response.json(
        statusCode: 405, body: {'error': 'Method not allowed'});
  }

  final data = await scanRepo.getByProject(id);
  return Response.json(body: {'data': data});
}
