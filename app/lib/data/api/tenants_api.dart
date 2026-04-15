import 'api_client.dart';

class TenantsApi {
  final _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> list() async {
    final response = await _dio.get('/tenants');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final response = await _dio.get('/tenants/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create({
    required String name,
    required String slug,
    Map<String, dynamic>? settings,
    String? adminUsername,
    String? adminPassword,
  }) async {
    final response = await _dio.post('/tenants', data: {
      'name': name,
      'slug': slug,
      if (settings != null) 'settings': settings,
      if (adminUsername != null) 'admin_username': adminUsername,
      if (adminPassword != null) 'admin_password': adminPassword,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(
    String id, {
    String? name,
    String? slug,
    bool? isActive,
    Map<String, dynamic>? settings,
  }) async {
    final response = await _dio.put('/tenants/$id', data: {
      if (name != null) 'name': name,
      if (slug != null) 'slug': slug,
      if (isActive != null) 'is_active': isActive,
      if (settings != null) 'settings': settings,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(String id) async {
    await _dio.delete('/tenants/$id');
  }
}
