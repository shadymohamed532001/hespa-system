import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notifications/push_notifications_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (PushNotificationsService.instance.isSupported) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await PushNotificationsService.instance.initialize();
    }
  } catch (error) {
    debugPrint('Push bootstrap skipped: $error');
  }

  runApp(const HesbaApp());
}
