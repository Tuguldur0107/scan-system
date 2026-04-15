import 'api_client.dart';

class ProjectsApi {
  final _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> list({String? tenantId}) async {
    final response = await _dio.get(
      tenantId == null ? '/projects' : '/tenants/$tenantId/projects',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create({
    String? tenantId,
    required String name,
    String? description,
    bool isOpen = true,
  }) async {
    final response = await _dio.post(
      tenantId == null ? '/projects' : '/tenants/$tenantId/projects',
      data: {
        'name': name,
        if (description != null) 'description': description,
        'is_open': isOpen,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(
    String id, {
    String? tenantId,
    String? name,
    String? description,
    bool? isOpen,
  }) async {
    final response = await _dio.put(
      tenantId == null ? '/projects/$id' : '/tenants/$tenantId/projects/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (isOpen != null) 'is_open': isOpen,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(String id, {String? tenantId}) async {
    await _dio.delete(
      tenantId == null ? '/projects/$id' : '/tenants/$tenantId/projects/$id',
    );
  }
}
