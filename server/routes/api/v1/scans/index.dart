import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/repositories/scan_repository.dart';

Future<Response> onRequest(RequestContext context) async {
  final tc = context.read<TenantContext>();
  final scanRepo = context.read<ScanRepository>();

  switch (context.request.method) {
    case HttpMethod.get:
      final params = context.request.uri.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final perPage = int.tryParse(params['per_page'] ?? '50') ?? 50;

      final result = await scanRepo.findByTenant(
        tc.tenantId,
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

    case HttpMethod.post:
      final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
      final scan = await scanRepo.create(
        tenantId: tc.tenantId,
        projectId: body['project_id'] as String,
        userId: tc.userId,
        barcodeValue: body['barcode_value'] as String,
        barcodeFormat: body['barcode_format'] as String?,
        scannedAt: DateTime.parse(body['scanned_at'] as String),
        notes: body['notes'] as String?,
        metadata: body['metadata'] as Map<String, dynamic>? ?? {},
        kind: body['kind'] as String?,
      );
      return Response.json(statusCode: 201, body: scan);

    default:
      return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }
}
