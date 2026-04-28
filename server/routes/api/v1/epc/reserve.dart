import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:server/middleware/auth_middleware.dart';
import 'package:server/repositories/epc_counter_repository.dart';

/// POST /api/v1/epc/reserve
///
/// Body: `{ "items": [ { "gtin14": "01234567890128", "qty": 10 }, ... ] }`
///
/// Response: `{ "data": [ { "gtin14": "...", "start": 1, "end": 10, "total": 10 }, ... ] }`
///
/// Atomically allocates a contiguous range of SGTIN-96 serial numbers per
/// (tenant, GTIN-14) pair so the importer can stamp unique, sequential
/// serials on every generated EPC. Subsequent calls for the same GTIN
/// continue from where the previous call left off.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response.json(statusCode: 405, body: {'error': 'Method not allowed'});
  }

  final tc = context.read<TenantContext>();
  final repo = context.read<EpcCounterRepository>();

  try {
    final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    final items = (body['items'] as List?)?.cast<Map<String, dynamic>>();
    if (items == null || items.isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': '`items` array is required'},
      );
    }
    if (items.length > 5000) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Maximum 5000 items per call'},
      );
    }

    // Sum quantities per gtin14 so duplicate rows in the same payload
    // get merged into one allocation (avoids double-charging the counter).
    final merged = <String, int>{};
    for (final item in items) {
      final gtin = (item['gtin14'] ?? '').toString().trim();
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      if (gtin.isEmpty || gtin.length != 14 || qty < 1) {
        return Response.json(
          statusCode: 400,
          body: {'error': 'Invalid item: $item (need gtin14 length 14 and qty >= 1)'},
        );
      }
      merged.update(gtin, (v) => v + qty, ifAbsent: () => qty);
    }

    final results = <Map<String, dynamic>>[];
    for (final entry in merged.entries) {
      final r = await repo.reserveRange(
        tenantId: tc.tenantId,
        gtin14: entry.key,
        qty: entry.value,
      );
      results.add({
        'gtin14': entry.key,
        'start': r.start,
        'end': r.end,
        'total': r.total,
        'qty': entry.value,
      });
    }

    return Response.json(body: {'data': results});
  } catch (e) {
    return Response.json(statusCode: 400, body: {'error': e.toString()});
  }
}
