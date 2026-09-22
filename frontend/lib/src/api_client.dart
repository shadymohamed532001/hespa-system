import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({String? baseUrl})
    : dio = Dio(
        BaseOptions(
          baseUrl:
              baseUrl ??
              const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://localhost:3000/api',
              ),
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          headers: {'Content-Type': 'application/json'},
        ),
      );

  final Dio dio;

  void setToken(String? token) {
    if (token == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    return response.data!;
  }

  Future<List<dynamic>> list(String path) async {
    final response = await dio.get<List<dynamic>>(path);
    return response.data ?? [];
  }

  Future<Map<String, dynamic>> getMap(String path) async {
    final response = await dio.get<Map<String, dynamic>>(path);
    return response.data ?? {};
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? data]) async {
    final response = await dio.post<dynamic>(path, data: data ?? {});
    return response.data;
  }

  Future<dynamic> patch(String path, Map<String, dynamic> data) async {
    final response = await dio.patch<dynamic>(path, data: data);
    return response.data;
  }

  static String errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        final message = data['message'];
        return message is List ? message.join('، ') : message.toString();
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'تعذر الاتصال بالخادم. تأكد أن الباك إند وقاعدة البيانات يعملان.';
      }
    }
    return 'حدث خطأ غير متوقع';
  }
}
