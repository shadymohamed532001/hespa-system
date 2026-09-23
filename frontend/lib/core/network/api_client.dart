import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_endpoints.dart';
import '../settings/app_locale_holder.dart';

final _sensitiveNetworkLogValue = RegExp(
  r'''^(\s*[║╟]?\s*(?:"|')?(?:authorization|proxy-authorization|cookie|set-cookie|password|passcode|access[_-]?token|refresh[_-]?token|id[_-]?token|token|api[_-]?key|recovery[_-]?key|client[_-]?secret|secret)(?:"|')?\s*:\s*).*$''',
  caseSensitive: false,
);

void _printNetworkLog(Object message) {
  final logLine = message.toString();

  // PrettyDioLogger prints map request bodies twice. Skip the compact copy so
  // sensitive fields cannot reappear after being masked in the table above.
  if (logLine.startsWith('║ {') && logLine.endsWith('}')) return;

  final sanitizedMessage = logLine.replaceFirstMapped(
    _sensitiveNetworkLogValue,
    (match) => '${match.group(1)}***',
  );
  debugPrint(sanitizedMessage);
}

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
        onError: (error, handler) async {
          if (!_shouldAttemptRefresh(error)) {
            handler.next(error);
            return;
          }

          final refreshed = await _refreshSession();
          if (!refreshed) {
            onUnauthorized?.call();
            handler.next(error);
            return;
          }

          try {
            final request = error.requestOptions;
            final auth = dio.options.headers['Authorization'];
            if (auth != null) {
              request.headers['Authorization'] = auth;
            } else {
              request.headers.remove('Authorization');
            }
            request.extra['authRetry'] = true;
            final response = await dio.fetch<dynamic>(request);
            handler.resolve(response);
          } on DioException catch (retryError) {
            if (retryError.response?.statusCode == 401) {
              onUnauthorized?.call();
            }
            handler.next(retryError);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );
    dio.interceptors.add(
      PrettyDioLogger(
        enabled: kDebugMode,
        requestHeader: true,
        // Request bodies can contain passwords, recovery keys, financial
        // details, and other secrets. Never print them, even in debug builds.
        requestBody: false,
        responseHeader: true,
        responseBody: true,
        error: true,
        compact: true,
        maxWidth: 120,
        logPrint: _printNetworkLog,
      ),
    );
  }

  final Dio dio;
  final Duration retryBaseDelay;
  final int maxMutationAttempts;
  final Future<void> Function(Duration) _delay;
  void Function()? onUnauthorized;
  Future<void> Function(String accessToken, String refreshToken)?
  onTokensUpdated;
  static const _uuid = Uuid();
  static const _pendingMutationStoragePrefix = 'pending_idempotency_keys_v1';
  final Map<String, Future<String>> _pendingMutationKeys = {};
  Future<void> _storageTail = Future<void>.value();
  String? _currentToken;
  String? _refreshToken;
  Completer<bool>? _refreshCompleter;
  String _locale = 'ar';

  void setLocale(String languageCode) {
    _locale = languageCode == 'en' ? 'en' : 'ar';
    dio.options.headers['Accept-Language'] = _locale;
    dio.options.headers['X-App-Locale'] = _locale;
  }

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

  void setRefreshToken(String? token) {
    _refreshToken = token;
  }

  void setTokens({String? accessToken, String? refreshToken}) {
    setToken(accessToken);
    setRefreshToken(refreshToken);
  }

  void setMutationScope(String? userId) {
    if (_mutationScope == userId) return;
    _pendingMutationKeys.clear();
    _mutationScope = userId;
  }

  String? _mutationScope;

  bool _shouldAttemptRefresh(DioException error) {
    if (error.response?.statusCode != 401) return false;
    final path = error.requestOptions.path;
    if (path == ApiEndpoints.login ||
        path == ApiEndpoints.recoverAdmin ||
        path == ApiEndpoints.refresh ||
        path == ApiEndpoints.logout) {
      return false;
    }
    if (error.requestOptions.extra['skipAuthRefresh'] == true) return false;
    if (error.requestOptions.extra['authRetry'] == true) return false;
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    return true;
  }

  Future<bool> _refreshSession() async {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    try {
      final refresh = _refreshToken;
      if (refresh == null || refresh.isEmpty) {
        completer.complete(false);
        return false;
      }

      final response = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refreshToken': refresh},
        options: Options(extra: const {'skipAuthRefresh': true}),
      );
      final data = response.data ?? <String, dynamic>{};
      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      if (accessToken == null ||
          accessToken.isEmpty ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        completer.complete(false);
        return false;
      }

      setTokens(accessToken: accessToken, refreshToken: refreshToken);
      await onTokensUpdated?.call(accessToken, refreshToken);
      completer.complete(true);
      return true;
    } catch (_) {
      completer.complete(false);
      return false;
    } finally {
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
    }
  }

  /// Attempts a proactive token refresh (e.g. during session restore).
  Future<bool> tryRefresh() => _refreshSession();

  // =========================
  // Login / Logout
  // =========================

  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    required String portal,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {
        'username': username,
        'password': password,
        'portal': portal,
      },
      options: Options(extra: const {'skipAuthRefresh': true}),
    );

    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> recoverAdmin({
    required String recoveryKey,
    required String username,
    required String displayName,
    required String password,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      ApiEndpoints.recoverAdmin,
      data: {
        'recoveryKey': recoveryKey,
        'username': username,
        'displayName': displayName,
        'password': password,
      },
      options: Options(extra: const {'skipAuthRefresh': true}),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> logoutRemote() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) return;
    try {
      await dio.post<Map<String, dynamic>>(
        ApiEndpoints.logout,
        data: {'refreshToken': refresh},
        options: Options(extra: const {'skipAuthRefresh': true}),
      );
    } catch (_) {
      // Local logout must still succeed if the server is unreachable.
    }
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

  static String errorMessage(Object error, {String? locale}) {
    final isArabic = (locale ?? AppLocaleHolder.code) != 'en';
    if (error is DioException) {
      final data = error.response?.data;

      // لو الـ Backend رجع رسالة خطأ
      if (data is Map && data['message'] != null) {
        final message = data['message'];

        if (message is List) {
          return message.join(isArabic ? '، ' : ', ');
        }

        return message.toString();
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return isArabic
              ? 'انتهت مهلة الاتصال بالخادم.'
              : 'Connection to the server timed out.';

        case DioExceptionType.sendTimeout:
          return isArabic
              ? 'انتهت مهلة إرسال البيانات إلى الخادم.'
              : 'Sending data to the server timed out.';

        case DioExceptionType.receiveTimeout:
          return isArabic
              ? 'انتهت مهلة انتظار استجابة الخادم.'
              : 'Waiting for the server response timed out.';

        case DioExceptionType.connectionError:
          return isArabic
              ? 'تعذر الاتصال بالخادم. تأكد أن الباك إند وقاعدة البيانات يعملان.'
              : 'Could not connect to the server. Make sure the backend and database are running.';

        case DioExceptionType.badResponse:
          final status = error.response?.statusCode ??
              (isArabic ? 'غير معروف' : 'unknown');
          return isArabic
              ? 'حدث خطأ في استجابة الخادم ($status).'
              : 'Server response error ($status).';

        case DioExceptionType.cancel:
          return isArabic
              ? 'تم إلغاء الطلب.'
              : 'The request was cancelled.';

        case DioExceptionType.badCertificate:
          return isArabic
              ? 'حدث خطأ في شهادة الاتصال بالخادم.'
              : 'There was a problem with the server certificate.';

        default:
          return isArabic
              ? 'تعذر إكمال الاتصال بالخادم.'
              : 'Could not complete the server request.';
      }
    }

    return isArabic
        ? 'حدث خطأ غير متوقع'
        : 'An unexpected error occurred';
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
