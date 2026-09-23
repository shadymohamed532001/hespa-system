import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notifications/push_notifications_service.dart';
import 'core/system/system_availability_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (SystemAvailabilityService.instance.isFirebasePlatform &&
        Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    if (PushNotificationsService.instance.isSupported) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await PushNotificationsService.instance.initialize();
    }
  } catch (error) {
    debugPrint('Firebase bootstrap skipped: $error');
  }

  runApp(const HesbaApp());
}
