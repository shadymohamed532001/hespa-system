import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/network/api_client.dart';
import 'package:hesba_desktop/core/theme/app_theme.dart';
import 'package:hesba_desktop/features/auth/session_controller.dart';
import 'package:hesba_desktop/features/collections/agent_credits_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DebtsAdapter implements HttpClientAdapter {
  final posts = <Map<String, dynamic>>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object body = <dynamic>[];
    final path = options.uri.path;
    if (options.method == 'POST' && path.endsWith('/shop-debts')) {
      posts.add(Map<String, dynamic>.from(options.data as Map));
      body = {'id': 'm1', 'reference': 'DBT-001'};
    } else if (path.endsWith('/shop-debts')) {
      body = [
        {
          'personName': 'السيد',
          'borrowed': 5000,
          'repaid': 2000,
          'owed': 3000,
          'lastActivityAt': '2026-11-25T10:00:00.000Z',
          'movementsCount': 2,
        },
      ];
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Future<_DebtsAdapter> _pump(
  WidgetTester tester, {
  String role = 'admin',
}) async {
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('ar');
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1800, 1100);
  addTearDown(tester.view.reset);
  final adapter = _DebtsAdapter();
  final session = SessionController(
    ApiClient(
      baseUrl: 'https://example.test/api',
      adapter: adapter,
      retryBaseDelay: Duration.zero,
      delay: (_) async {},
    )..setToken('t'),
  )..role = role;
  await tester.pumpWidget(
    MaterialApp(
      theme: hesbaTheme(),
      home: Scaffold(body: AgentCreditsPage(session: session)),
    ),
  );
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  testWidgets('admins see the shop loans tab and record a new loan', (
    tester,
  ) async {
    final adapter = await _pump(tester);

    await tester.tap(find.text('سلف المحل'));
    await tester.pumpAndSettle();
    expect(find.text('السيد'), findsOneWidget);
    expect(find.text('إجمالي اللي على المحل'), findsOneWidget);
    expect(find.text('3,000 ج.م'), findsWidgets);

    await tester.tap(find.text('تسجيل سلفة جديدة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شخص جديد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'أبو علي');
    await tester.enterText(
      find.byKey(const ValueKey('shop-debt-amount')),
      '1500',
    );
    await tester.tap(find.text('تسجيل السلفة').last);
    await tester.pumpAndSettle();

    expect(adapter.posts.single, {
      'personName': 'أبو علي',
      'kind': 'borrow',
      'amount': 1500,
    });
  });

  testWidgets('repaying is capped at what the shop still owes', (tester) async {
    final adapter = await _pump(tester);
    await tester.tap(find.text('سلف المحل'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'سداد'));
    await tester.pumpAndSettle();
    expect(find.text('سداد سلفة'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('shop-debt-amount')),
      '3001',
    );
    await tester.tap(find.text('تسجيل السداد'));
    await tester.pumpAndSettle();
    expect(find.textContaining('أقصى مبلغ سداد هو'), findsOneWidget);
    expect(adapter.posts, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('shop-debt-amount')),
      '3000',
    );
    await tester.tap(find.text('تسجيل السداد'));
    await tester.pumpAndSettle();
    expect(adapter.posts.single, {
      'personName': 'السيد',
      'kind': 'repay',
      'amount': 3000,
    });
  });

  testWidgets('employees do not see the shop loans tab', (tester) async {
    await _pump(tester, role: 'employee');
    expect(find.text('سلف المحل'), findsNothing);
  });
}
