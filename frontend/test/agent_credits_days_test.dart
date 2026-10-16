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

class _Adapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.path, endsWith('/agent-credits/days'));
    final today = DateTime.now();
    String key(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return ResponseBody.fromString(
      jsonEncode([
        {
          'date': key(today),
          'agentName': 'Ahmed',
          'openingBalance': 100,
          'credit': 20,
          'paid': 0,
          'closingBalance': 120,
          'balance': 120,
          'movementsCount': 1,
        },
        {
          'date': key(today.subtract(const Duration(days: 2))),
          'agentName': 'Ali',
          'openingBalance': 80,
          'credit': 0,
          'paid': 80,
          'closingBalance': 0,
          'balance': 0,
          'movementsCount': 1,
        },
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  testWidgets(
    'defaults to today, filters settled days, and opens the calendar',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await initializeDateFormatting('ar');
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(tester.view.reset);
      final session = SessionController(
        ApiClient(baseUrl: 'https://example.test/api', adapter: _Adapter()),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: hesbaTheme(),
          home: Scaffold(body: AgentCreditsPage(session: session)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ahmed'), findsOneWidget);
      expect(find.text('Ali'), findsNothing);
      await tester.tap(find.text('كل الأيام'));
      await tester.pumpAndSettle();
      expect(find.text('Ali'), findsOneWidget);
      await tester.tap(find.text('كل الحالات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مسدد').last);
      await tester.pumpAndSettle();
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Ahmed'), findsNothing);
      await tester.tap(find.byIcon(Icons.calendar_month));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    },
  );
}
