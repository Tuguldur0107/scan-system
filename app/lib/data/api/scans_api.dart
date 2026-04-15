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
}
