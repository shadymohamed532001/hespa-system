import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/network/api_client.dart';
import '../core/settings/app_settings.dart';
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

  @override
  void initState() {
    super.initState();
    session = SessionController(ApiClient())..restore();
    settings = AppSettings()..restore();
    initializeDateFormatting('ar');
    initializeDateFormatting('en');
  }

  @override
  void dispose() {
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
          home: !session.ready || !settings.ready
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : session.signedIn
              ? AppShell(session: session, settings: settings)
              : LoginPage(session: session),
        );
      },
    );
  }
}
