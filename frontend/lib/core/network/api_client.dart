import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_endpoints.dart';

class ApiClient {
  ApiClient({
    String? baseUrl,
    HttpClientAdapter? adapter,
    this.retryBaseDelay = const Duration(milliseconds: 250),
    this.maxMutationAttempts = 4,
    Future<void> Function(Duration)? delay,
  }) : _delay = delay ?? ((duration) => Future<void>.delayed(duration)),
       dio = Dio(
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
    if (adapter != null) dio.httpClientAdapter = adapter;
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
  final Duration retryBaseDelay;
  final int maxMutationAttempts;
  final Future<void> Function(Duration) _delay;
  void Function()? onUnauthorized;
  static const _uuid = Uuid();
  static const _pendingMutationStoragePrefix = 'pending_idempotency_keys_v1';
  final Map<String, Future<String>> _pendingMutationKeys = {};
  Future<void> _storageTail = Future<void>.value();
  String? _currentToken;
  String? _mutationScope;

  // =========================
  // Authentication Token
  // =========================

  void setToken(String? token) {
    if (_currentToken != token) {
      // Never carry an uncertain operation from one authenticated session to
      // another. Within the same session its key remains available for a
      // manual retry after a timeout.
      _pendingMutationKeys.clear();
      _currentToken = token;
    }
    if (token == null || token.isEmpty) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  void setMutationScope(String? userId) {
    if (_mutationScope == userId) return;
    _pendingMutationKeys.clear();
    _mutationScope = userId;
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
    return _mutate('POST', path, data ?? <String, dynamic>{});
  }

  // =========================
  // PATCH
  // =========================

  Future<dynamic> patch(String path, Map<String, dynamic> data) async {
    return _mutate('PATCH', path, data);
  }

  // =========================
  // DELETE
  // =========================

  Future<dynamic> delete(String path) async {
    return _mutate('DELETE', path, const <String, dynamic>{});
  }

  Future<dynamic> _mutate(
    String method,
    String path,
    Map<String, dynamic> data,
  ) async {
    final fingerprint = '$method\n$path\n${_canonicalJson(data)}';
    final key = await _pendingMutationKeys.putIfAbsent(
      fingerprint,
      () => _loadOrCreateMutationKey(fingerprint),
    );

    for (var attempt = 0; attempt < maxMutationAttempts; attempt++) {
      try {
        final response = await dio.request<dynamic>(
          path,
          data: data,
          options: Options(
            method: method,
            headers: <String, String>{'Idempotency-Key': key},
          ),
        );
        await _forgetMutationKey(fingerprint);
        return response.data;
      } on DioException catch (error) {
        final retryable = _isRetryableMutationError(error);
        final hasAnotherAttempt = attempt + 1 < maxMutationAttempts;
        if (!retryable) {
          if (!_isUncertainIdempotencyError(error)) {
            await _forgetMutationKey(fingerprint);
          }
          rethrow;
        }
        if (!hasAnotherAttempt) {
          // Keep the key. If the user retries this exact operation after an
          // uncertain timeout, the server can replay the original response
          // instead of applying the money movement twice.
          rethrow;
        }
        await _delay(retryBaseDelay * (1 << attempt));
      }
    }

    throw StateError('Mutation retry loop ended unexpectedly');
  }

  Future<String> _loadOrCreateMutationKey(String fingerprint) async {
    final scope = _mutationScope;
    if (scope == null) return _uuid.v4();

    return _withStorageLock(() async {
      final preferences = await SharedPreferences.getInstance();
      final storageKey = '$_pendingMutationStoragePrefix:$scope';
      final stored = preferences.getString(storageKey);
      final values = stored == null
          ? <String, String>{}
          : Map<String, String>.from(jsonDecode(stored) as Map);
      final key = values[fingerprint] ?? _uuid.v4();
      if (values[fingerprint] == null) {
        values[fingerprint] = key;
        await preferences.setString(storageKey, jsonEncode(values));
      }
      return key;
    });
  }

  Future<void> _forgetMutationKey(String fingerprint) async {
    _pendingMutationKeys.remove(fingerprint);
    final scope = _mutationScope;
    if (scope == null) return;

    await _withStorageLock(() async {
      final preferences = await SharedPreferences.getInstance();
      final storageKey = '$_pendingMutationStoragePrefix:$scope';
      final stored = preferences.getString(storageKey);
      if (stored == null) return;
      final values = Map<String, String>.from(jsonDecode(stored) as Map);
      if (values.remove(fingerprint) == null) return;
      if (values.isEmpty) {
        await preferences.remove(storageKey);
      } else {
        await preferences.setString(storageKey, jsonEncode(values));
      }
    });
  }

  Future<T> _withStorageLock<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _storageTail = _storageTail.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  bool _isRetryableMutationError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }
    if (error.type != DioExceptionType.badResponse) return false;

    final status = error.response?.statusCode;
    if ({408, 425, 429, 500, 502, 503, 504}.contains(status)) return true;

    final body = error.response?.data;
    return status == 409 &&
        body is Map &&
        body['code'] == 'IDEMPOTENCY_IN_PROGRESS';
  }

  bool _isUncertainIdempotencyError(DioException error) {
    if (error.response?.statusCode != 409) return false;
    final body = error.response?.data;
    return body is Map &&
        const {
          'IDEMPOTENCY_IN_PROGRESS',
          'IDEMPOTENCY_REVIEW_REQUIRED',
        }.contains(body['code']);
  }

  static String _canonicalJson(Object? value) {
    Object? normalize(Object? item) {
      if (item is Map) {
        final keys = item.keys.map((key) => '$key').toList()..sort();
        return <String, Object?>{
          for (final key in keys) key: normalize(item[key]),
        };
      }
      if (item is Iterable) return item.map(normalize).toList();
      return item;
    }

    return jsonEncode(normalize(value));
  }

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
        defaultValue: 'https://hesba.alien-fit.com/api',
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
