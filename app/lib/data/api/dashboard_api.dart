import 'api_client.dart';

class DashboardApi {
  final _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> summary() async {
    final response = await _dio.get('/dashboard/summary');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> byUser() async {
    final response = await _dio.get('/dashboard/by-user');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> byProject() async {
    final response = await _dio.get('/dashboard/by-project');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> timeline({int days = 30}) async {
    final response = await _dio.get('/dashboard/timeline', queryParameters: {'days': days});
    return response.data as Map<String, dynamic>;
  }
}
