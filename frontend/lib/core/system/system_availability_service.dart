import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../firebase_options.dart';

/// Reads Firebase Remote Config `IS_SYSTEM_WORK` via the public fetch API.
///
/// Uses HTTP (not the native RC plugin) so macOS hot-restart / pigeon channel
/// issues cannot bypass the kill switch.
///
/// - `true` → app runs normally
/// - `false` → show contact-developer block screen
class SystemAvailabilityService {
  SystemAvailabilityService._();

  static final SystemAvailabilityService instance =
      SystemAvailabilityService._();

  static const paramKey = 'IS_SYSTEM_WORK';

  bool ready = false;
  bool isSystemWork = true;
  String? errorMessage;

  bool get isFirebasePlatform {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<void> check() async {
    ready = false;
    errorMessage = null;
    // Default open until Remote Config says otherwise.
    isSystemWork = true;

    if (!isFirebasePlatform) {
      ready = true;
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await _checkWithHttp();
      debugPrint('Remote Config $paramKey=$isSystemWork');
    } catch (error) {
      // Fail-open only when fetch itself fails (network / API).
      debugPrint('Remote Config check failed (allowing app): $error');
      errorMessage = error.toString();
      isSystemWork = true;
    } finally {
      ready = true;
    }
  }

  Future<void> _checkWithHttp() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    final instanceId = await _appInstanceId();
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
      ),
    );

    final response = await dio.post<Map<String, dynamic>>(
      'https://firebaseremoteconfig.googleapis.com/v1/projects/'
      '${options.projectId}/namespaces/firebase:fetch',
      queryParameters: {'key': options.apiKey},
      data: {
        'appId': options.appId,
        'appInstanceId': instanceId,
        'languageCode': 'ar',
      },
    );

    final data = response.data;
    final state = data?['state']?.toString();
    debugPrint('Remote Config fetch state=$state');

    final entries = data?['entries'];
    if (entries is! Map) {
      isSystemWork = true;
      return;
    }
    final raw = entries[paramKey];
    final value = raw is Map ? raw['value']?.toString() : raw?.toString();
    if (value == null) {
      isSystemWork = true;
      return;
    }
    isSystemWork = value.toLowerCase() == 'true' || value == '1';
  }

  Future<String> _appInstanceId() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'firebase_rc_app_instance_id';
    final existing = prefs.getString(key);
    if (existing != null && existing.length >= 8) return existing;
    final created = const Uuid().v4().replaceAll('-', '');
    await prefs.setString(key, created);
    return created;
  }
}
