import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/repositories/scan_repository.dart';

/// `POST /api/v1/scans/bulk-delete`
///
/// Body:
/// ```json
/// {
///   "project_id": "<uuid>",
///   "kind":       "packing_list" | "epc_read" | ...,
///   "values":     ["3036...A2C", "3036...A69"]  // optional
/// }
/// ```
///
/// Used by the receiving (Хүлээж авах) tab:
/// - **Clear packing list**       → no `values`, clears every `packing_list` row.
/// - **Clear all EPC reads**      → no `values`, clears every `epc_read` row.
/// - **Remove orphan EPC reads**  → with `values`, deletes only those EPCs
///                                   that don't appear on the packing list.
///
/// `kind` must be one of the dedup-able kinds (`epc_read`, `packing_list`)
/// so we can never accidentally wipe scans that came from the camera /
/// manual entry tab.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }

  final tc = context.read<TenantContext>();
  final scanRepo = context.read<ScanRepository>();

  Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON body'});
  }

  final projectId = body['project_id'] as String?;
  final kind = body['kind'] as String?;
  if (projectId == null || projectId.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'project_id required'});
  }
  if (kind == null || kind.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'kind required'});
  }

  // Allow-list: never let this endpoint touch barcode_scan / epc_import
  // rows. Those have their own UI-driven delete flows and do not have a
  // dedup unique index, so a wholesale delete would be too easy to misuse.
  const allowedKinds = {'epc_read', 'packing_list'};
  if (!allowedKinds.contains(kind)) {
    return Response.json(
      statusCode: 400,
      body: {
        'error': 'kind must be one of: ${allowedKinds.join(', ')}',
      },
    );
  }

  final rawValues = body['values'];
  final values = (rawValues is List)
      ? rawValues.whereType<String>().where((v) => v.trim().isNotEmpty).toList()
      : <String>[];

  final deleted = values.isEmpty
      ? await scanRepo.deleteByKind(
          tenantId: tc.tenantId,
          projectId: projectId,
          kind: kind,
        )
      : await scanRepo.deleteByValuesAndKind(
          tenantId: tc.tenantId,
          projectId: projectId,
          kind: kind,
          barcodeValues: values,
        );

  return Response.json(body: {'deleted': deleted, 'mode': values.isEmpty ? 'all' : 'by-values'});
}
