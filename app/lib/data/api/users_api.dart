import 'api_client.dart';

class UsersApi {
  final _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> list({String? tenantId}) async {
    final response = await _dio.get(
      tenantId == null ? '/users' : '/tenants/$tenantId/users',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create({
    String? tenantId,
    required String username,
    required String password,
    required String role,
  }) async {
    final response = await _dio.post(
      tenantId == null ? '/users' : '/tenants/$tenantId/users',
      data: {
        'username': username,
        'password': password,
        'role': role,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(
    String id, {
    String? tenantId,
    String? username,
    String? password,
    String? role,
    bool? isActive,
  }) async {
    final response = await _dio.put(
      tenantId == null ? '/users/$id' : '/tenants/$tenantId/users/$id',
      data: {
        if (username != null) 'username': username,
        if (password != null) 'password': password,
        if (role != null) 'role': role,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(String id, {String? tenantId}) async {
    await _dio.delete(
      tenantId == null ? '/users/$id' : '/tenants/$tenantId/users/$id',
    );
  }
}
