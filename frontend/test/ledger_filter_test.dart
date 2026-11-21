import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/network/api_client.dart';
import 'package:hesba_desktop/core/theme/app_theme.dart';
import 'package:hesba_desktop/features/auth/session_controller.dart';
import 'package:hesba_desktop/features/ledger/ledger_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LedgerAdapter implements HttpClientAdapter {
  final ledgerRequests = <Uri>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    Object body = <dynamic>[];
    if (path.endsWith('/ledger')) {
      ledgerRequests.add(options.uri);
      final walletOnly = options.uri.queryParameters['entityType'] == 'wallet';
      body = [
        {
          'id': 'w1',
          'createdAt': '2026-11-21T10:00:00.000Z',
          'category': 'top_up',
          'description': 'شحن المحفظة',
          'amount': 500,
        },
        if (!walletOnly)
          {
            'id': 'a1',
            'createdAt': '2026-11-21T09:00:00.000Z',
            'category': 'company_execution',
            'description': 'تنفيذ فوري لصالح شركة',
            'amount': -1000,
          },
      ];
    } else if (path.endsWith('/wallets')) {
      body = [
        {'id': 'wallet-1', 'name': '01023123321', 'ownerName': 'محمد سعيد'},
      ];
    } else if (path.endsWith('/accounts')) {
      body = [
        {'id': 'account-1', 'name': 'حساب شركة 01'},
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

void main() {
  testWidgets('filters the ledger to one wallet found by its owner name', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ar');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(tester.view.reset);

    final adapter = _LedgerAdapter();
    final session = SessionController(
      ApiClient(baseUrl: 'https://example.test/api', adapter: adapter),
    )..role = 'admin';
    await tester.pumpWidget(
      MaterialApp(
        theme: hesbaTheme(),
        home: Scaffold(body: LedgerPage(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تنفيذ فوري لصالح شركة'), findsOneWidget);
    expect(adapter.ledgerRequests.last.queryParameters['entityType'], isNull);

    await tester.tap(find.byKey(const ValueKey('ledger-scope')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('ledger-scope')),
        matching: find.byType(TextField),
      ),
      'سعيد',
    );
    await tester.pumpAndSettle();
    expect(find.text('حساب · حساب شركة 01'), findsNothing);
    await tester.tap(find.text('محفظة · محمد سعيد — 01023123321').last);
    await tester.pumpAndSettle();

    final uri = adapter.ledgerRequests.last;
    expect(uri.queryParameters['entityType'], 'wallet');
    expect(uri.queryParameters['entityId'], 'wallet-1');
    expect(find.text('تنفيذ فوري لصالح شركة'), findsNothing);
    expect(find.text('شحن المحفظة'), findsOneWidget);
    expect(find.textContaining('1 عملية على'), findsOneWidget);

    await tester.tap(find.text('عرض كل الحسابات'));
    await tester.pumpAndSettle();
    expect(adapter.ledgerRequests.last.queryParameters['entityType'], isNull);
    expect(find.text('تنفيذ فوري لصالح شركة'), findsOneWidget);
  });
}
