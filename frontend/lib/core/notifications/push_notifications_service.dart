import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../../firebase_options.dart';

/// Top-level background handler required by firebase_messaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Already initialized in this isolate.
  }
}

typedef PushArrivedCallback = void Function(RemoteMessage message);

class PushNotificationsService {
  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _localReady = false;
  bool _initFailed = false;
  String? _token;
  PushArrivedCallback? onMessage;
  ApiClient? _api;

  String? get token => _token;

  /// FCM desktop push is officially usable on macOS (APNs). Windows/Linux skip.
  bool get isSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> initialize() async {
    if (_ready || _initFailed) return;

    // Local notifications work without APNs — used as fallback when FCM fails.
    await _ensureLocalReady();

    if (!isSupported) {
      debugPrint('FCM skipped: platform does not support desktop push');
      _initFailed = true;
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push permission denied');
        _ready = true;
        return;
      }

      // macOS needs the APNs token before an FCM token is issued.
      await _waitForApnsToken(messaging);

      try {
        _token = await messaging.getToken();
      } catch (error) {
        debugPrint('FCM getToken skipped (APNs not ready): $error');
      }

      messaging.onTokenRefresh.listen((value) {
        _token = value;
        final api = _api;
        if (api != null) {
          registerWithBackend(api);
        }
      });

      FirebaseMessaging.onMessage.listen((message) async {
        await showLocalFromRemote(message);
        onMessage?.call(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        onMessage?.call(message);
      });

      try {
        final initial = await messaging.getInitialMessage();
        if (initial != null) {
          onMessage?.call(initial);
        }
      } catch (error) {
        debugPrint('FCM getInitialMessage skipped: $error');
      }

      _ready = true;
      if (_token != null && _token!.length > 12) {
        debugPrint('FCM ready. token=${_token!.substring(0, 12)}…');
      } else {
        debugPrint(
          'FCM token empty — in-app/local notifications still work via polling.',
        );
      }
    } catch (error) {
      // Keep local notifications usable even if FCM bootstrap fails.
      _ready = true;
      debugPrint('FCM initialize failed (local fallback stays on): $error');
    }
  }

  Future<void> _ensureLocalReady() async {
    if (_localReady) return;
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      settings: const InitializationSettings(
        macOS: darwinSettings,
        iOS: darwinSettings,
      ),
    );
    _localReady = true;
  }

  Future<void> _waitForApnsToken(FirebaseMessaging messaging) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    for (var i = 0; i < 8; i++) {
      try {
        final apns = await messaging.getAPNSToken();
        if (apns != null) return;
      } catch (_) {
        // APNs not set yet — keep waiting.
      }
      await Future<void>.delayed(const Duration(milliseconds: 750));
    }
  }

  Future<void> showLocalFromRemote(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'حسبة';
    final body = notification?.body ?? message.data['body'] ?? '';
    await showLocal(
      title: title,
      body: body,
      id: message.hashCode,
      payload: message.data['notificationId'],
    );
  }

  /// Shows a macOS/local banner even when FCM/APNs is unavailable.
  Future<void> showLocal({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    if (body.isEmpty && title.isEmpty) return;
    await _ensureLocalReady();

    const details = NotificationDetails(
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _local.show(
      id: id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<void> registerWithBackend(ApiClient api) async {
    _api = api;
    try {
      if (!_ready && !_initFailed) await initialize();
      final current = _token ?? await _refreshToken();
      if (current == null || current.isEmpty) {
        debugPrint('Skip device-token register: no FCM token yet');
        return;
      }

      await api.post(ApiEndpoints.notificationDeviceToken, {
        'token': current,
        'platform': _platformName(),
      });
      debugPrint('FCM device token registered with backend');
    } catch (error) {
      debugPrint('Failed to register FCM token: $error');
    }
  }

  Future<void> unregisterFromBackend(ApiClient api) async {
    final current = _token;
    if (current == null || current.isEmpty) return;
    try {
      await api.post(ApiEndpoints.notificationDeviceTokenUnregister, {
        'token': current,
      });
    } catch (_) {}
  }

  Future<String?> _refreshToken() async {
    if (!isSupported) return null;
    try {
      await _waitForApnsToken(FirebaseMessaging.instance);
      _token = await FirebaseMessaging.instance.getToken();
    } catch (_) {}
    return _token;
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      _ => defaultTargetPlatform.name,
    };
  }
}
