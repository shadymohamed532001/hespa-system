import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/network/api_client.dart';
import '../core/notifications/push_notifications_service.dart';
import '../core/settings/app_settings.dart';
import '../core/system/system_availability_service.dart';
import '../core/system/system_unavailable_page.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/login_page.dart';
import '../features/auth/session_controller.dart';
import 'app_shell.dart';

class HesbaApp extends StatefulWidget {
  const HesbaApp({super.key});

  @override
  State<HesbaApp> createState() => _HesbaAppState();
}

class _HesbaAppState extends State<HesbaApp> {
  late final SessionController session;
  late final AppSettings settings;
  final SystemAvailabilityService availability =
      SystemAvailabilityService.instance;
  bool _availabilityChecking = true;

  @override
  void initState() {
    super.initState();
    session = SessionController(ApiClient())..restore();
    settings = AppSettings()..restore();
    initializeDateFormatting('ar');
    initializeDateFormatting('en');
    session.addListener(_onSessionChanged);
    _refreshAvailability();
  }

  Future<void> _refreshAvailability() async {
    setState(() => _availabilityChecking = true);
    await availability.check();
    if (!mounted) return;
    setState(() => _availabilityChecking = false);
  }

  void _onSessionChanged() {
    if (session.signedIn) {
      PushNotificationsService.instance.registerWithBackend(session.api);
    }
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    session.dispose();
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([session, settings]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'حِسبة',
          theme: hesbaTheme(),
          darkTheme: hesbaDarkTheme(),
          themeMode: settings.themeMode,
          locale: settings.locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: settings.textDirection,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (_availabilityChecking || !availability.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!availability.isSystemWork) {
      return SystemUnavailablePage(onRetry: _refreshAvailability);
    }
    if (!session.ready || !settings.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (session.signedIn) {
      return AppShell(session: session, settings: settings);
    }
    return LoginPage(session: session);
  }
}
