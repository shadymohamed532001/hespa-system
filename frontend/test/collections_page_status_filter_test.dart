import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/network/api_client.dart';
import 'package:hesba_desktop/core/theme/app_theme.dart';
import 'package:hesba_desktop/features/auth/session_controller.dart';
import 'package:hesba_desktop/features/collections/collections_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('status chips split pending collections from completed ones', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(tester.view.reset);

    final session = SessionController(
      ApiClient(
        baseUrl: 'https://example.test/api',
        adapter: _CollectionsAdapter(),
        retryBaseDelay: Duration.zero,
        delay: (_) async {},
      )..setToken('test-token'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: hesbaTheme(),
        home: Scaffold(body: CollectionsPage(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COL-PEND'), findsOneWidget);
    expect(find.text('COL-DONE'), findsOneWidget);
    expect(find.text('COL-REV'), findsOneWidget);
    expect(find.text('COL-OLD'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'معلّق (1)'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'خلص (1)'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'معلّق (1)'));
    await tester.pumpAndSettle();

    expect(find.text('COL-PEND'), findsOneWidget);
    expect(find.text('COL-DONE'), findsNothing);
    expect(find.text('COL-REV'), findsNothing);
    expect(find.text('تنفيذ'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'خلص (1)'));
    await tester.pumpAndSettle();

    expect(find.text('COL-DONE'), findsOneWidget);
    expect(find.text('COL-PEND'), findsNothing);
    expect(find.text('COL-REV'), findsNothing);
    expect(find.text('تنفيذ'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'الكل').at(1));
    await tester.pumpAndSettle();
    expect(find.text('COL-REV'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'الكل').first);
    await tester.pumpAndSettle();
    expect(find.text('COL-OLD'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'خلص (2)'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'خلص (2)'));
    await tester.pumpAndSettle();

    expect(find.text('COL-DONE'), findsOneWidget);
    expect(find.text('COL-OLD'), findsOneWidget);
    expect(find.text('COL-PEND'), findsNothing);
  });
}

class _CollectionsAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final today = DateTime.now();
    final older = today.subtract(const Duration(days: 40));
    Object body = <dynamic>[];
    if (options.path.endsWith('/collections')) {
      body = [
        _row('COL-PEND', 'pending', today),
        _row('COL-DONE', 'done', today),
        _row('COL-REV', 'reversed', today),
        _row('COL-OLD', 'done', older),
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

  Map<String, dynamic> _row(String reference, String status, DateTime day) {
    final received = DateTime(day.year, day.month, day.day, 10);
    return {
      'reference': reference,
      'agentName': 'shady',
      'companyName': 'فودافون',
      'amount': 100,
      'cashAmount': 100,
      'agentCreditChange': 0,
      'executionMode': status == 'pending' ? 'hold' : 'immediate',
      'status': status,
      'receivedAt': received.toIso8601String(),
      'executedAt': status == 'pending' ? null : received.toIso8601String(),
      'commission': 5,
    };
  }

  @override
  void close({bool force = false}) {}
}
