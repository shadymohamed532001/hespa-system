import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/app/app_shell.dart';
import 'package:hesba_desktop/core/network/api_client.dart';
import 'package:hesba_desktop/core/settings/app_settings.dart';
import 'package:hesba_desktop/features/auth/session_controller.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('opens a section from the home grid and returns home', (
    tester,
  ) async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    final session =
        SessionController(
            ApiClient(
              baseUrl: 'https://example.test/api',
              adapter: _EmptyAdapter(),
              retryBaseDelay: Duration.zero,
              delay: (_) async {},
            ),
          )
          ..ready = true
          ..token = 'test-token'
          ..username = 'mahmoud@gmail.com'
          ..role = 'admin';
    final settings = AppSettings()..ready = true;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: AppShell(session: session, settings: settings),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اختر القسم للدخول'), findsOneWidget);
    expect(find.text('الخزنة المركزية'), findsOneWidget);
    expect(find.text('لوحة المتابعة'), findsOneWidget);
    expect(find.byIcon(Icons.menu_rounded), findsNothing);

    await tester.tap(find.text('الخزنة المركزية'));
    await tester.pumpAndSettle();

    expect(find.text('الرصيد الفعلي والمتاح والالتزامات'), findsOneWidget);
    expect(find.text('اختر القسم للدخول'), findsNothing);

    await tester.tap(find.byTooltip('العودة للرئيسية'));
    await tester.pumpAndSettle();

    expect(find.text('اختر القسم للدخول'), findsOneWidget);
    expect(find.text('الرصيد الفعلي والمتاح والالتزامات'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _EmptyAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.path.contains('notifications')
        ? {'count': 0}
        : <String, dynamic>{};
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
