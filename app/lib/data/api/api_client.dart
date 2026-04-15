import 'package:dio/dio.dart';

import '../../core/constants.dart';
import '../../services/auth_token_service.dart';

class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  late final Dio dio = _createDio();

  Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: '${ApiConstants.baseUrl}${ApiConstants.apiPrefix}',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(_AuthInterceptor());
    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = AuthTokenService.instance.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Try refresh
      final refreshToken = AuthTokenService.instance.refreshToken;
      if (refreshToken != null) {
        try {
          final dio = Dio(BaseOptions(
            baseUrl: '${ApiConstants.baseUrl}${ApiConstants.apiPrefix}',
          ));
          final response = await dio.post('/auth/refresh', data: {
            'refresh_token': refreshToken,
          });

          final data = response.data as Map<String, dynamic>;
          await AuthTokenService.instance.saveTokens(
            accessToken: data['access_token'] as String,
            refreshToken: data['refresh_token'] as String,
          );

          // Retry original request
          err.requestOptions.headers['Authorization'] =
              'Bearer ${data['access_token']}';
          final retryResponse = await dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        } catch (_) {
          await AuthTokenService.instance.clear();
        }
      }
    }
    handler.next(err);
  }
}
