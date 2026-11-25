import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/network/api_client.dart';
import 'package:hesba_desktop/core/theme/app_theme.dart';
import 'package:hesba_desktop/features/accounts/accounts_page.dart';
import 'package:hesba_desktop/features/auth/session_controller.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  final posts = <String, Map<String, dynamic>>{};

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
    if (options.method == 'POST') {
      posts[path] = Map<String, dynamic>.from(options.data as Map);
      body = {'id': 'qr-1', 'balance': 1005};
    } else if (path.endsWith('/accounts')) {
      body = [
        {
          'id': 'qr-1',
          'name': 'حساب QR كود',
          'type': 'profit_qr',
          'active': true,
          'balance': 0,
          'commissionBalance': 0,
          'openingBalance': 0,
          'todayTopUp': 0,
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

void main() {
  testWidgets('QR profit accounts can be topped up like regular profit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ar');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1800, 1100);
    addTearDown(tester.view.reset);
    final adapter = _Adapter();
    final session = SessionController(
      ApiClient(
        baseUrl: 'https://example.test/api',
        adapter: adapter,
        retryBaseDelay: Duration.zero,
        delay: (_) async {},
      )..setToken('t'),
    )..role = 'admin';
    await tester.pumpWidget(
      MaterialApp(
        theme: hesbaTheme(),
        home: Scaffold(
          body: AccountsPage(session: session, kind: 'profit_qr'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('سحب كاش لعميل'), findsOneWidget);
    await tester.tap(find.text('شحن حساب'));
    await tester.pumpAndSettle();
    expect(find.textContaining('يضيف ٥ جنيه'), findsWidgets);
  });
}
