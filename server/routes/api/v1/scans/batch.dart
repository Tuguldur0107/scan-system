import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/repositories/scan_repository.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }

  final tc = context.read<TenantContext>();
  final scanRepo = context.read<ScanRepository>();

  try {
    final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    final scans = (body['scans'] as List).cast<Map<String, dynamic>>();

    if (scans.length > 500) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Maximum 500 scans per batch'},
      );
    }

    final results = await scanRepo.createBatch(
      tenantId: tc.tenantId,
      userId: tc.userId,
      scans: scans,
    );

    return Response.json(
      statusCode: 201,
      body: {'data': results, 'count': results.length},
    );
  } catch (e) {
    return Response.json(statusCode: 400, body: {'error': e.toString()});
  }
}
