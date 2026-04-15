import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/repositories/scan_repository.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }

  final tc = context.read<TenantContext>();
  final scanRepo = context.read<ScanRepository>();
  final params = context.request.uri.queryParameters;

  final rows = await scanRepo.exportCsv(
    tc.tenantId,
    projectId: params['project_id'],
    from: params['from'] != null ? DateTime.tryParse(params['from']!) : null,
    to: params['to'] != null ? DateTime.tryParse(params['to']!) : null,
  );

  final buffer = StringBuffer();
  buffer.writeln('barcode_value,barcode_format,scanned_at,notes,username,project_name');

  for (final row in rows) {
    final values = [
      _escapeCsv(row['barcode_value']?.toString() ?? ''),
      _escapeCsv(row['barcode_format']?.toString() ?? ''),
      _escapeCsv(row['scanned_at']?.toString() ?? ''),
      _escapeCsv(row['notes']?.toString() ?? ''),
      _escapeCsv(row['username']?.toString() ?? ''),
      _escapeCsv(row['project_name']?.toString() ?? ''),
    ];
    buffer.writeln(values.join(','));
  }

  return Response(
    body: buffer.toString(),
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': 'attachment; filename="scans_export.csv"',
    },
  );
}

String _escapeCsv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
