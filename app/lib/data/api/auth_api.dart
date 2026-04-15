import 'api_client.dart';

class AuthApi {
  final _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> login({
    required String tenantSlug,
    required String username,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'tenant_slug': tenantSlug,
      'username': username,
      'password': password,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _dio.get('/auth/me');
    return response.data as Map<String, dynamic>;
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post('/auth/logout', data: {
      'refresh_token': refreshToken,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post('/auth/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }
}
