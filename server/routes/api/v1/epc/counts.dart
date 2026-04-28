import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/repositories/epc_counter_repository.dart';

/// GET /api/v1/epc/counts?gtin14=...&gtin14=...
///
/// Returns the cumulative number of SGTIN-96 EPCs that have ever been
/// generated for each requested GTIN under the caller's tenant. Useful for
/// dashboards that want to know "how many of barcode X have we received".
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }

  final tc = context.read<TenantContext>();
  final repo = context.read<EpcCounterRepository>();

  final params = context.request.uri.queryParametersAll;
  final gtins = (params['gtin14'] ?? const <String>[])
      .map((e) => e.trim())
      .where((e) => e.length == 14)
      .toList();

  if (gtins.isEmpty) {
    return Response.json(body: {'data': <Map<String, dynamic>>[]});
  }

  final counts = await repo.currentCounts(tenantId: tc.tenantId, gtins: gtins);
  return Response.json(body: {
    'data': [
      for (final g in gtins) {'gtin14': g, 'total': counts[g] ?? 0},
    ],
  });
}
