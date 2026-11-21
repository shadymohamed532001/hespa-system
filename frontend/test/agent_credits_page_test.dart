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

String _today() {
  final date = DateTime.now();
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<_AgentCreditsAdapter> pumpPage(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1800, 1000);
    addTearDown(tester.view.reset);

    final adapter = _AgentCreditsAdapter();
    final session =
        SessionController(
            ApiClient(
              baseUrl: 'https://example.test/api',
              adapter: adapter,
              retryBaseDelay: Duration.zero,
              delay: (_) async {},
            )..setToken('test-token'),
          )
          ..username = 'shady'
          ..role = 'admin';

    await tester.pumpWidget(
      MaterialApp(
        theme: hesbaTheme(),
        home: Scaffold(body: AgentCreditsPage(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    return adapter;
  }

  testWidgets('shows owed and held balances and filters deposits', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('مندوب أحمد'), findsOneWidget);
    expect(find.text('مندوب سعد'), findsOneWidget);
    expect(find.text('عليه 2,000 ج.م'), findsWidgets);
    expect(find.text('ليه 90,000 ج.م'), findsWidgets);
    expect(find.text('إجمالي أمانات المندوبين'), findsOneWidget);
    expect(find.text('90,000 ج.م'), findsOneWidget);

    await tester.tap(find.text('كل الحالات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ليه أمانة').last);
    await tester.pumpAndSettle();

    expect(find.text('مندوب سعد'), findsOneWidget);
    expect(find.text('مندوب أحمد'), findsNothing);
  });

  testWidgets('receiving more than the credit records the extra as a deposit', (
    tester,
  ) async {
    final adapter = await pumpPage(tester);

    final receive = find.widgetWithText(FilledButton, 'استلام').first;
    await tester.ensureVisible(receive);
    await tester.pumpAndSettle();
    await tester.tap(receive);
    await tester.pumpAndSettle();
    expect(find.text('استلام فلوس من مندوب'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).last, '5000');
    await tester.pumpAndSettle();
    expect(find.textContaining('هتتسجل أمانة للمندوب'), findsOneWidget);

    expect(find.textContaining('على رصيد الخزنة'), findsOneWidget);

    await tester.tap(find.text('تسجيل الاستلام'));
    await tester.pumpAndSettle();

    expect(adapter.lastPath, endsWith('/collections/agent-credits/payments'));
    expect(adapter.lastBody, {'agentName': 'مندوب أحمد', 'amount': 5000});
  });

  testWidgets(
    'money from an agent can land on an InstaPay wallet or QR account',
    (tester) async {
      final adapter = await pumpPage(tester);

      await tester.tap(find.text('استلام فلوس من مندوب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مندوب جديد'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'مندوب جديد');
      await tester.enterText(find.byType(TextFormField).at(1), '100000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('الخزنة (كاش)'));
      await tester.pumpAndSettle();
      expect(find.text('حساب مكسب QR فودافون QR'), findsOneWidget);
      expect(find.text('Stopped wallet'), findsNothing);
      await tester.tap(find.text('InstaPay 01 · InstaPay').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('على InstaPay 01 · InstaPay'), findsOneWidget);

      await tester.tap(find.text('تسجيل الاستلام'));
      await tester.pumpAndSettle();

      expect(adapter.lastPath, endsWith('/collections/agent-credits/payments'));
      expect(adapter.lastBody, {
        'agentName': 'مندوب جديد',
        'amount': 100000,
        'walletId': 'wallet-1',
      });
    },
  );

  testWidgets('picks an existing agent by any letter instead of a duplicate', (
    tester,
  ) async {
    final adapter = await pumpPage(tester);

    await tester.tap(find.text('استلام فلوس من مندوب'));
    await tester.pumpAndSettle();
    expect(find.text('مندوب قديم (2)'), findsOneWidget);

    // Searching by part of the name, spelled without the hamza.
    await tester.enterText(
      find.byKey(const ValueKey('agent-search-field')),
      'احم',
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'مندوب سعد'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'مندوب أحمد'));
    await tester.pumpAndSettle();
    expect(find.textContaining('هتتحسب على نفس حسابه'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '2500');
    await tester.pumpAndSettle();
    expect(find.textContaining('الزيادة 500'), findsOneWidget);
    await tester.tap(find.text('تسجيل الاستلام'));
    await tester.pumpAndSettle();
    expect(adapter.lastBody, {'agentName': 'مندوب أحمد', 'amount': 2500});
  });

  testWidgets('typing an existing name as a new agent is blocked', (
    tester,
  ) async {
    final adapter = await pumpPage(tester);

    await tester.tap(find.text('استلام فلوس من مندوب'));
    await tester.pumpAndSettle();
    // Searching without choosing from the list is not enough.
    await tester.enterText(
      find.byKey(const ValueKey('agent-search-field')),
      'مندوب',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '100');
    await tester.tap(find.text('تسجيل الاستلام'));
    await tester.pumpAndSettle();
    expect(find.textContaining('اختار المندوب من القايمة'), findsOneWidget);

    await tester.tap(find.text('مندوب جديد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, ' مندوب احمد ');
    await tester.pumpAndSettle();
    expect(find.textContaining('المندوب ده موجود'), findsOneWidget);
    await tester.tap(find.text('تسجيل الاستلام'));
    await tester.pumpAndSettle();
    expect(find.textContaining('موجود بالفعل'), findsOneWidget);
    expect(adapter.lastPath, isNull);

    await tester.tap(find.textContaining('المندوب ده موجود'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل الاستلام'));
    await tester.pumpAndSettle();
    expect(adapter.lastBody, {'agentName': 'مندوب أحمد', 'amount': 100});
  });

  testWidgets('refunds only up to the deposit held for the agent', (
    tester,
  ) async {
    final adapter = await pumpPage(tester);

    final refundButtons = find.widgetWithText(OutlinedButton, 'رد للمندوب');
    expect(
      tester.widget<OutlinedButton>(refundButtons.first).onPressed,
      isNull,
      reason: 'Ahmed owes us, so there is nothing to refund',
    );
    await tester.ensureVisible(refundButtons.last);
    await tester.pumpAndSettle();
    await tester.tap(refundButtons.last);
    await tester.pumpAndSettle();
    expect(find.text('رد فلوس للمندوب'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '90001');
    await tester.tap(find.text('صرف من الخزنة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('أقصى مبلغ رد هو'), findsOneWidget);
    expect(adapter.lastPath, isNull);

    await tester.enterText(find.byType(TextFormField).last, '10000');
    await tester.tap(find.text('صرف من الخزنة'));
    await tester.pumpAndSettle();

    expect(adapter.lastPath, endsWith('/collections/agent-credits/refunds'));
    expect(adapter.lastBody, {'agentName': 'مندوب سعد', 'amount': 10000});
  });
}

class _AgentCreditsAdapter implements HttpClientAdapter {
  String? lastPath;
  Map<String, dynamic>? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object body;
    if (options.method == 'POST') {
      lastPath = options.path;
      lastBody = Map<String, dynamic>.from(options.data as Map);
      body = {'remainingBalance': -3000, 'treasuryBalance': 12000};
    } else if (options.path.endsWith('/wallets')) {
      body = <dynamic>[
        {'id': 'wallet-1', 'name': 'InstaPay 01', 'type': 'instapay'},
        {
          'id': 'wallet-2',
          'name': 'Stopped wallet',
          'type': 'wallet',
          'active': false,
        },
      ];
    } else if (options.path.endsWith('/accounts')) {
      body = <dynamic>[
        {'id': 'qr-1', 'name': 'فودافون QR', 'type': 'profit_qr'},
        {'id': 'company-1', 'name': 'شركة', 'type': 'company'},
      ];
    } else if (options.path.endsWith('/collections/agent-credits/days')) {
      body = <dynamic>[
        {
          'date': _today(),
          'agentName': 'مندوب أحمد',
          'openingBalance': 0,
          'credit': 2000,
          'paid': 0,
          'refunded': 0,
          'closingBalance': 2000,
          'balance': 2000,
          'movementsCount': 1,
        },
        {
          'date': _today(),
          'agentName': 'مندوب سعد',
          'openingBalance': 0,
          'credit': 0,
          'paid': 100000,
          'refunded': 10000,
          'closingBalance': -90000,
          'balance': -90000,
          'movementsCount': 2,
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
