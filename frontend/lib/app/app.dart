import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/network/api_client.dart';
import '../features/auth/login_page.dart';
import '../features/auth/session_controller.dart';
import 'app_shell.dart';
import '../core/theme/app_theme.dart';

class HesbaApp extends StatefulWidget {
  const HesbaApp({super.key});

  @override
  State<HesbaApp> createState() => _HesbaAppState();
}

class _HesbaAppState extends State<HesbaApp> {
  late final SessionController session;

  @override
  void initState() {
    super.initState();
    session = SessionController(ApiClient())..restore();
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'حِسبة',
      theme: hesbaTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AnimatedBuilder(
        animation: session,
        builder: (context, _) {
          if (!session.ready) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return session.signedIn
              ? AppShell(session: session)
              : LoginPage(session: session);
        },
      ),
    );
  }
}
