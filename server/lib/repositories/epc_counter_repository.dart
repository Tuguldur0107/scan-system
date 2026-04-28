import 'package:postgres/postgres.dart';

import 'base_repository.dart';

/// Tracks per-(tenant, GTIN-14) cumulative SGTIN-96 serial numbers.
///
/// `reserveRange` atomically allocates [qty] serial numbers for the given
/// `gtin14` within `tenantId` and returns the [start, end] inclusive range.
/// The first time a barcode is seen for a tenant the range begins at 1.
class EpcCounterRepository extends BaseRepository {
  /// Reserves [qty] sequential serials for [gtin14] under [tenantId].
  /// Returns `(start, end)` (both inclusive). Throws if [qty] < 1.
  Future<({int start, int end, int total})> reserveRange({
    required String tenantId,
    required String gtin14,
    required int qty,
  }) async {
    if (qty < 1) {
      throw ArgumentError('qty must be >= 1');
    }

    // Atomic UPSERT: insert with last_serial = qty for new rows; for existing
    // rows bump last_serial by qty. RETURNING gives us the new value so we
    // can compute the range. Postgres serializes per-row updates so concurrent
    // callers can't get overlapping ranges.
    final result = await db.execute(
      Sql.named('''
        INSERT INTO epc_counters (tenant_id, gtin14, last_serial, updated_at)
        VALUES (@tenant_id, @gtin14, @qty, NOW())
        ON CONFLICT (tenant_id, gtin14)
        DO UPDATE SET
          last_serial = epc_counters.last_serial + EXCLUDED.last_serial,
          updated_at  = NOW()
        RETURNING last_serial
      '''),
      parameters: {
        'tenant_id': tenantId,
        'gtin14': gtin14,
        'qty': qty,
      },
    );

    final lastSerial = (result.first.toColumnMap()['last_serial'] as num).toInt();
    final start = lastSerial - qty + 1;
    return (start: start, end: lastSerial, total: lastSerial);
  }

  /// Returns the current cumulative count for [gtin14] under [tenantId],
  /// or 0 if the tenant has never produced an EPC for that barcode.
  Future<int> currentCount({
    required String tenantId,
    required String gtin14,
  }) async {
    final result = await db.execute(
      Sql.named('''
        SELECT last_serial FROM epc_counters
        WHERE tenant_id = @tenant_id AND gtin14 = @gtin14
      '''),
      parameters: {'tenant_id': tenantId, 'gtin14': gtin14},
    );
    if (result.isEmpty) return 0;
    return (result.first.toColumnMap()['last_serial'] as num).toInt();
  }

  /// Returns counts for many GTINs in one call: `{gtin14: total}`.
  Future<Map<String, int>> currentCounts({
    required String tenantId,
    required List<String> gtins,
  }) async {
    if (gtins.isEmpty) return <String, int>{};
    final result = await db.execute(
      Sql.named('''
        SELECT gtin14, last_serial FROM epc_counters
        WHERE tenant_id = @tenant_id AND gtin14 = ANY(@gtins)
      '''),
      parameters: {'tenant_id': tenantId, 'gtins': gtins},
    );
    final out = <String, int>{};
    for (final row in result) {
      final m = row.toColumnMap();
      out[m['gtin14'] as String] = (m['last_serial'] as num).toInt();
    }
    return out;
  }
}
