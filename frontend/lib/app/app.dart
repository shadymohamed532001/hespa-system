import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/network/api_client.dart';
import '../core/notifications/push_notifications_service.dart';
import '../core/settings/app_settings.dart';
import '../core/settings/hesba_l10n.dart';
import '../core/system/system_availability_service.dart';
import '../core/system/system_unavailable_page.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/login_page.dart';
import '../features/auth/session_controller.dart';
import 'app_shell.dart';
import '../core/settings/tr.dart';

class HesbaApp extends StatefulWidget {
  const HesbaApp({
    super.key,
    this.checkSystemAvailability = true,
    this.sessionController,
    this.appSettings,
  });

  final bool checkSystemAvailability;
  final SessionController? sessionController;
  final AppSettings? appSettings;

  @override
  State<HesbaApp> createState() => _HesbaAppState();
}

class _HesbaAppState extends State<HesbaApp> {
  late final SessionController session;
  late final AppSettings settings;
  final SystemAvailabilityService availability =
      SystemAvailabilityService.instance;
  bool _availabilityChecking = false;

  @override
  void initState() {
    super.initState();
    session = widget.sessionController ?? SessionController(ApiClient());
    settings = widget.appSettings ?? AppSettings();
    if (widget.sessionController == null) {
      session.restore();
    }
    if (widget.appSettings == null) {
      settings.restore();
    }
    initializeDateFormatting('ar');
    initializeDateFormatting('en');
    session.addListener(_onSessionChanged);
    settings.addListener(_syncLocale);
    if (widget.checkSystemAvailability) {
      _refreshAvailability();
    }
  }

  void _syncLocale() {
    session.setLocale(settings.locale.languageCode);
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
    settings.removeListener(_syncLocale);
    if (widget.sessionController == null) {
      session.dispose();
    }
    if (widget.appSettings == null) {
      settings.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([session, settings]),
      builder: (context, _) {
        session.setLocale(settings.locale.languageCode);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: settings.isArabic ? tr(ar: 'حِسبة', en: 'Hesba') : 'Hesba',
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
            return HesbaL10n(
              settings: settings,
              child: Directionality(
                textDirection: settings.textDirection,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (widget.checkSystemAvailability) {
      if (_availabilityChecking || !availability.ready) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!availability.isSystemWork) {
        return SystemUnavailablePage(onRetry: _refreshAvailability);
      }
    }
    if (!session.ready || !settings.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (session.signedIn) {
      return AppShell(session: session, settings: settings);
    }
    return LoginPage(session: session, settings: settings);
  }
}
