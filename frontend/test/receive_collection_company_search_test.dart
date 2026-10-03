import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/network/api_client.dart';
import 'package:hesba_desktop/core/theme/app_theme.dart';
import 'package:hesba_desktop/features/auth/session_controller.dart';
import 'package:hesba_desktop/features/collections/receive_collection_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('company field filters names that contain the typed letter', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    final session = SessionController(
      ApiClient(
        baseUrl: 'https://example.test/api',
        adapter: _AccountsAdapter(),
        retryBaseDelay: Duration.zero,
        delay: (_) async {},
      )..setToken('test-token'),
    )..username = 'shady';

    await tester.pumpWidget(
      MaterialApp(
        theme: hesbaTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showReceiveCollectionDialog(
                context: context,
                session: session,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('اسم المندوب *'), findsNothing);
    expect(find.text('الشركة *'), findsOneWidget);

    final companyField = find.descendant(
      of: find.byType(DropdownMenu<String>),
      matching: find.byType(TextField),
    );
    await tester.tap(companyField);
    await tester.pumpAndSettle();

    expect(find.text('طلبات'), findsOneWidget);
    expect(find.text('ايديتا'), findsOneWidget);
    expect(find.text('ايجيبت فودز'), findsOneWidget);
    expect(find.text('شركة اليسر'), findsOneWidget);
    expect(find.text('ياسين للتجارة'), findsOneWidget);
    expect(find.text('جهينة'), findsOneWidget);
    expect(find.text('حساب شركة 01'), findsOneWidget);
    expect(find.text('شركة ياسمين فوري'), findsNothing);

    await tester.enterText(companyField, 'ي');
    await tester.pumpAndSettle();

    expect(find.text('شركة اليسر'), findsOneWidget);
    expect(find.text('ياسين للتجارة'), findsOneWidget);
    expect(find.text('جهينة'), findsOneWidget);
    expect(find.text('حساب شركة 01'), findsNothing);
  });

  testWidgets('pending collection requires the agent name', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    final session = SessionController(
      ApiClient(
        baseUrl: 'https://example.test/api',
        adapter: _AccountsAdapter(),
        retryBaseDelay: Duration.zero,
        delay: (_) async {},
      )..setToken('test-token'),
    )..username = 'shady';

    await tester.pumpWidget(
      MaterialApp(
        theme: hesbaTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showReceiveCollectionDialog(
                context: context,
                session: session,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تنفيذ العملية الآن'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل كمعلّق وتنفيذ لاحقًا').last);
    await tester.pumpAndSettle();

    expect(find.text('اسم المندوب *'), findsOneWidget);

    final submit = find.text('تسجيل كمعلّق');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('اكتب اسم المندوب'), findsOneWidget);
  });

  testWidgets('agent credit calculates the difference from cash received', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1100);
    addTearDown(tester.view.reset);

    final session = SessionController(
      ApiClient(
        baseUrl: 'https://example.test/api',
        adapter: _AccountsAdapter(),
        retryBaseDelay: Duration.zero,
        delay: (_) async {},
      )..setToken('test-token'),
    )..username = 'shady';

    await tester.pumpWidget(
      MaterialApp(
        theme: hesbaTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showReceiveCollectionDialog(
                context: context,
                session: session,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('collection-amount')),
      '50000',
    );
    await tester.tap(find.text('آجل المندوب'));
    await tester.pumpAndSettle();

    expect(find.text('اسم المندوب *'), findsOneWidget);
    expect(find.text('المبلغ المستلم فعليًا *'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('agent-name')),
      'مندوب أحمد',
    );
    await tester.enterText(
      find.byKey(const ValueKey('received-amount')),
      '48000',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('هيتسجل على مندوب أحمد آجل'), findsOneWidget);
    expect(find.textContaining('2,000'), findsWidgets);
  });

  testWidgets(
    'split option credits treasury cash and a wallet from one account',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.reset);

      final session = SessionController(
        ApiClient(
          baseUrl: 'https://example.test/api',
          adapter: _AccountsAdapter(),
          retryBaseDelay: Duration.zero,
          delay: (_) async {},
        )..setToken('test-token'),
      )..username = 'shady';

      await tester.pumpWidget(
        MaterialApp(
          theme: hesbaTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showReceiveCollectionDialog(
                  context: context,
                  session: session,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final split = find.text('تقسيم المبلغ الداخل');
      await tester.ensureVisible(split);
      await tester.tap(split);
      await tester.pumpAndSettle();

      expect(find.text('الكاش اللي يدخل الخزنة *'), findsNothing);
      expect(find.text('المحفظة *'), findsOneWidget);
      expect(find.text('مبلغ المحفظة *'), findsOneWidget);
    },
  );
}

class _AccountsAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.path.endsWith('/collections/agent-credits')
        ? <dynamic>[]
        : [
            {
              'id': '1',
              'name': 'شركة اليسر',
              'type': 'company',
              'active': true,
            },
            {
              'id': '2',
              'name': 'ياسين للتجارة',
              'type': 'company',
              'active': true,
            },
            {'id': '3', 'name': 'جهينة', 'type': 'company', 'active': true},
            {
              'id': '4',
              'name': 'حساب شركة 01',
              'type': 'company',
              'active': true,
            },
            {
              'id': '5',
              'name': 'شركة ياسمين فوري',
              'type': 'fawry',
              'active': true,
            },
          ];
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
