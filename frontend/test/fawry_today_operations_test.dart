import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hesba_desktop/core/network/api_client.dart';
import 'package:hesba_desktop/core/theme/app_theme.dart';
import 'package:hesba_desktop/features/accounts/accounts_page.dart';
import 'package:hesba_desktop/features/auth/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ar');
  });

  testWidgets('fawry icon opens today operations for review', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    final session = SessionController(
      ApiClient(
        baseUrl: 'https://example.test/api',
        adapter: _FawryOperationsAdapter(),
        retryBaseDelay: Duration.zero,
        delay: (_) async {},
      )..setToken('test-token'),
    )..username = 'shady';

    await tester.pumpWidget(
      MaterialApp(
        theme: hesbaTheme(),
        home: Scaffold(
          body: AccountsPage(session: session, kind: 'fawry'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('عمليات فوري النهارده'));
    await tester.pumpAndSettle();

    expect(find.text('عمليات فوري النهارده'), findsOneWidget);
    expect(
      find.text('اختار حساب فوري عشان تشوف عملياته النهارده'),
      findsOneWidget,
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حساب فوري 01').last);
    await tester.pumpAndSettle();

    expect(find.text('تنفيذ فوري لصالح طلبات'), findsOneWidget);
    expect(find.text('COL-014'), findsOneWidget);
    expect(find.text('2,000 ج.م'), findsOneWidget);
    expect(find.text('تنفيذ فوري لصالح جهينة'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.byTooltip('رجوع لحسابات فوري'));
    await tester.pumpAndSettle();
    expect(find.text('حسابات فوري'), findsOneWidget);
  });
}

class _FawryOperationsAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final accountId = options.uri.queryParameters['accountId'];
    final isOperations = options.uri.path.endsWith('/fawry-today-operations');
    final operations = [
      {
        'id': '1',
        'createdAt': '2026-10-03T09:00:00.000Z',
        'description': 'تنفيذ فوري لصالح طلبات',
        'amount': 2000,
        'reference': 'COL-014',
        'accountId': '1',
        'accountName': 'حساب فوري 01',
        'category': 'company_execution',
        'status': 'done',
        'performedBy': 'shady',
      },
      {
        'id': '2',
        'createdAt': '2026-10-03T08:00:00.000Z',
        'description': 'تنفيذ فوري لصالح جهينة',
        'amount': -32145,
        'reference': 'COL-009',
        'accountId': '2',
        'accountName': 'حساب فوري 02',
        'category': 'company_execution',
        'status': 'reversed',
        'performedBy': 'shady',
      },
    ];
    final visible = accountId == null
        ? operations
        : operations.where((item) => item['accountId'] == accountId).toList();
    final body = isOperations
        ? {
            'date': '2026-10-03',
            'accountId': accountId,
            'accounts': [
              {'id': '1', 'name': 'حساب فوري 01'},
              {'id': '2', 'name': 'حساب فوري 02'},
            ],
            'count': visible.length,
            'operations': visible,
          }
        : options.path.contains('fawry-daily-drops')
        ? {'date': '2026-10-03', 'drops': []}
        : [
            {
              'id': '1',
              'name': 'حساب فوري 01',
              'type': 'fawry',
              'active': true,
              'balance': 82400,
              'commissionBalance': 0,
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
