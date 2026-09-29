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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('paying an agent credit adds it to treasury and clears the row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    final adapter = _AgentCreditsAdapter();
    final session = SessionController(
      ApiClient(
        baseUrl: 'https://example.test/api',
        adapter: adapter,
        retryBaseDelay: Duration.zero,
        delay: (_) async {},
      )..setToken('test-token'),
    )..username = 'shady';

    await tester.pumpWidget(
      MaterialApp(
        theme: hesbaTheme(),
        home: Scaffold(body: AgentCreditsPage(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مندوب أحمد'), findsOneWidget);
    expect(find.text('2,000 ج.م'), findsWidgets);

    await tester.tap(find.text('تسديد'));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل سداد الآجل'), findsOneWidget);
    expect(find.textContaining('المبلغ هيتضاف لرصيد الخزنة'), findsOneWidget);

    await tester.tap(find.text('إضافة للخزنة وتسجيل السداد'));
    await tester.pumpAndSettle();

    expect(adapter.payment, {'agentName': 'مندوب أحمد', 'amount': 2000});
    expect(find.text('مفيش آجل على أي مندوب'), findsOneWidget);
    expect(
      find.textContaining('تم سداد آجل مندوب أحمد بالكامل'),
      findsOneWidget,
    );
  });
}

class _AgentCreditsAdapter implements HttpClientAdapter {
  Map<String, dynamic>? payment;
  bool paid = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object body;
    if (options.method == 'POST' &&
        options.path.endsWith('/collections/agent-credits/payments')) {
      payment = Map<String, dynamic>.from(options.data as Map);
      paid = true;
      body = {'remainingBalance': 0, 'treasuryBalance': 12000};
    } else if (options.path.endsWith('/collections/agent-credits')) {
      body = paid
          ? <dynamic>[]
          : <dynamic>[
              {
                'agentName': 'مندوب أحمد',
                'balance': 2000,
                'movementsCount': 1,
                'lastActivityAt': '2026-09-29T03:00:00.000Z',
              },
            ];
    } else {
      body = <String, dynamic>{};
    }

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
