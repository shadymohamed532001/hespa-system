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
      // getAPNSToken() throws when APNs is not ready yet — never let that abort bootstrap.
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
        debugPrint('FCM ready but token is empty (check APNs in Firebase).');
      }
    } catch (error) {
      _initFailed = true;
      debugPrint('FCM initialize failed (app continues without push): $error');
    }
  }

  Future<void> _waitForApnsToken(FirebaseMessaging messaging) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    for (var i = 0; i < 5; i++) {
      try {
        final apns = await messaging.getAPNSToken();
        if (apns != null) return;
      } catch (_) {
        // APNs not set yet — keep waiting.
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> showLocalFromRemote(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'حسبة';
    final body = notification?.body ?? message.data['body'] ?? '';
    if (body.isEmpty && notification?.title == null) return;

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
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: message.data['notificationId'],
    );
  }

  Future<void> registerWithBackend(ApiClient api) async {
    _api = api;
    if (_initFailed) return;
    try {
      if (!_ready) await initialize();
      if (_initFailed || !_ready) return;
      final current = _token ?? await _refreshToken();
      if (current == null || current.isEmpty) return;

      await api.post(ApiEndpoints.notificationDeviceToken, {
        'token': current,
        'platform': _platformName(),
      });
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
