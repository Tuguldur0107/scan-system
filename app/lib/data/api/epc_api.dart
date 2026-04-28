import 'api_client.dart';

/// Range of serials reserved by the server for one GTIN.
class EpcReservation {
  EpcReservation({
    required this.gtin14,
    required this.start,
    required this.end,
    required this.total,
    required this.qty,
  });

  factory EpcReservation.fromJson(Map<String, dynamic> json) => EpcReservation(
        gtin14: json['gtin14'] as String,
        start: (json['start'] as num).toInt(),
        end: (json['end'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        qty: (json['qty'] as num).toInt(),
      );

  final String gtin14;

  /// First serial included in the reservation (inclusive).
  final int start;

  /// Last serial included in the reservation (inclusive).
  final int end;

  /// Cumulative count for this GTIN under the tenant after this reservation.
  final int total;

  /// Number of serials reserved in this call.
  final int qty;
}

class EpcApi {
  final _dio = ApiClient.instance.dio;

  /// Atomically reserves a contiguous block of serial numbers for each
  /// `(gtin14, qty)` pair. Returns one [EpcReservation] per unique GTIN.
  Future<List<EpcReservation>> reserve(
    List<({String gtin14, int qty})> items,
  ) async {
    final response = await _dio.post(
      '/epc/reserve',
      data: {
        'items': [
          for (final i in items) {'gtin14': i.gtin14, 'qty': i.qty},
        ],
      },
    );
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return [
      for (final r in data) EpcReservation.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Returns the cumulative EPC count per GTIN for the current tenant.
  Future<Map<String, int>> counts(List<String> gtins) async {
    if (gtins.isEmpty) return <String, int>{};
    final response = await _dio.get(
      '/epc/counts',
      queryParameters: {'gtin14': gtins},
    );
    final data = (response.data as Map<String, dynamic>)['data'] as List;
    return {
      for (final row in data)
        (row as Map<String, dynamic>)['gtin14'] as String:
            (row['total'] as num).toInt(),
    };
  }
}
