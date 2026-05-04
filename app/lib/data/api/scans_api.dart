import 'api_client.dart';

class ScansApi {
  final _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> create(Map<String, dynamic> scan) async {
    final response = await _dio.post('/scans', data: scan);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> batchSync(
      List<Map<String, dynamic>> scans) async {
    final response = await _dio.post('/scans/batch', data: {'scans': scans});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> list({
    int page = 1,
    int perPage = 50,
    String? tenantId,
    String? projectId,
    String? search,
  }) async {
    final response = await _dio.get(
      tenantId == null ? '/scans' : '/tenants/$tenantId/scans',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (projectId != null) 'project_id': projectId,
        if (search != null) 'search': search,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(String id) async {
    await _dio.delete('/scans/$id');
  }

  /// Bulk delete by `kind`. If [values] is empty/null, every row of that
  /// kind in the project is removed (used for "Clear packing list").
  /// Otherwise only the specified barcode values are removed (used for
  /// "Remove orphan EPC reads").
  ///
  /// Server enforces an allow-list: only `epc_read` and `packing_list` rows
  /// may be deleted via this endpoint.
  Future<int> bulkDelete({
    required String projectId,
    required String kind,
    List<String>? values,
  }) async {
    final response = await _dio.post(
      '/scans/bulk-delete',
      data: {
        'project_id': projectId,
        'kind': kind,
        if (values != null) 'values': values,
      },
    );
    return (response.data as Map<String, dynamic>)['deleted'] as int? ?? 0;
  }
}
