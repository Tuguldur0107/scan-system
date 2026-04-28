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

  final params = context.request.uri.queryParameters;
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '50') ?? 50;

  final result = await scanRepo.findByTenant(
    id,
    page: page,
    perPage: perPage,
    projectId: params['project_id'],
    userId: params['user_id'],
    kind: params['kind'],
    search: params['search'],
    from: params['from'] != null ? DateTime.tryParse(params['from']!) : null,
    to: params['to'] != null ? DateTime.tryParse(params['to']!) : null,
  );

  return Response.json(body: {
    'data': result.data,
    'total': result.total,
    'page': page,
    'per_page': perPage,
  });
}
