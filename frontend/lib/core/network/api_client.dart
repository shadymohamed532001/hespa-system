import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'api_endpoints.dart';

class ApiClient {
  ApiClient({String? baseUrl})
    : dio = Dio(
        BaseOptions(
          baseUrl: _resolveBaseUrl(baseUrl),
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.path != ApiEndpoints.login) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  void Function()? onUnauthorized;
  static const _uuid = Uuid();

  // =========================
  // Authentication Token
  // =========================

  void setToken(String? token) {
    if (token == null || token.isEmpty) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  // =========================
  // Login
  // =========================

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await dio.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'username': username, 'password': password},
    );

    return response.data ?? <String, dynamic>{};
  }

  // =========================
  // GET List
  // =========================

  Future<List<dynamic>> list(String path) async {
    final response = await dio.get<List<dynamic>>(path);

    return response.data ?? <dynamic>[];
  }

  // =========================
  // GET Map
  // =========================

  Future<Map<String, dynamic>> getMap(String path) async {
    final response = await dio.get<Map<String, dynamic>>(path);

    return response.data ?? <String, dynamic>{};
  }

  // =========================
  // POST
  // =========================

  Future<dynamic> post(String path, [Map<String, dynamic>? data]) async {
    final response = await dio.post<dynamic>(
      path,
      data: data ?? <String, dynamic>{},
      options: _mutationOptions(),
    );

    return response.data;
  }

  // =========================
  // PATCH
  // =========================

  Future<dynamic> patch(String path, Map<String, dynamic> data) async {
    final response = await dio.patch<dynamic>(
      path,
      data: data,
      options: _mutationOptions(),
    );

    return response.data;
  }

  // =========================
  // DELETE
  // =========================

  Future<dynamic> delete(String path) async {
    final response = await dio.delete<dynamic>(
      path,
      options: _mutationOptions(),
    );

    return response.data;
  }

  Options _mutationOptions() =>
      Options(headers: <String, String>{'Idempotency-Key': _uuid.v4()});

  // =========================
  // Error Handling
  // =========================

  static String errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;

      // لو الـ Backend رجع رسالة خطأ
      if (data is Map && data['message'] != null) {
        final message = data['message'];

        if (message is List) {
          return message.join('، ');
        }

        return message.toString();
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return 'انتهت مهلة الاتصال بالخادم.';

        case DioExceptionType.sendTimeout:
          return 'انتهت مهلة إرسال البيانات إلى الخادم.';

        case DioExceptionType.receiveTimeout:
          return 'انتهت مهلة انتظار استجابة الخادم.';

        case DioExceptionType.connectionError:
          return 'تعذر الاتصال بالخادم. تأكد أن الباك إند وقاعدة البيانات يعملان.';

        case DioExceptionType.badResponse:
          return 'حدث خطأ في استجابة الخادم '
              '(${error.response?.statusCode ?? 'غير معروف'}).';

        case DioExceptionType.cancel:
          return 'تم إلغاء الطلب.';

        case DioExceptionType.badCertificate:
          return 'حدث خطأ في شهادة الاتصال بالخادم.';

        default:
          return 'تعذر إكمال الاتصال بالخادم.';
      }
    }

    return 'حدث خطأ غير متوقع';
  }
}

String _resolveBaseUrl(String? override) {
  final value =
      override ??
      const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:3000/api',
      );
  final uri = Uri.tryParse(value);
  const loopbackHosts = {'localhost', '127.0.0.1', '::1'};
  if (kReleaseMode &&
      (uri == null ||
          (uri.scheme != 'https' && !loopbackHosts.contains(uri.host)))) {
    throw StateError('API_BASE_URL must use HTTPS in release builds');
  }
  return value;
}
