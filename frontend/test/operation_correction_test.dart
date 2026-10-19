import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/network/api_client.dart';
import 'package:hesba_desktop/core/widgets/hesba_modal.dart';
import 'package:hesba_desktop/features/auth/session_controller.dart';
import 'package:hesba_desktop/features/ledger/operation_correction_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool reject = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final post = options.method == 'POST';
    final body = post
        ? reject
              ? {'message': 'الرصيد لا يكفي للتصحيح'}
              : {'corrected': true}
        : {
            'description': 'شحن حساب الاختبار',
            'blocked': null,
            'values': {'amount': 100, 'reference': 'REF'},
            'fields': [
              {'key': 'amount', 'label': 'المبلغ', 'type': 'number'},
              {'key': 'reference', 'label': 'المرجع', 'type': 'text'},
            ],
          };
    return ResponseBody.fromString(
      jsonEncode(body),
      post && reject ? 400 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<SessionController> mount(
    WidgetTester tester,
    _Adapter adapter, {
    bool admin = true,
    bool cancel = false,
  }) async {
    final session = SessionController(
      ApiClient(
        baseUrl: 'https://example.test/api',
        adapter: adapter,
        maxMutationAttempts: 1,
      )..setToken('test-token'),
    )..role = admin ? 'admin' : 'employee';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOperationCorrection(
                context,
                session,
                'entry-1',
                cancel: cancel,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets(
    'submits numeric business values and reason, keeping validation local',
    (tester) async {
      final adapter = _Adapter();
      await mount(tester, adapter);
      await tester.tap(find.text('حفظ التعديل'));
      await tester.pumpAndSettle();
      expect(adapter.requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.enterText(find.byType(TextFormField).at(0), '250');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'تصحيح مبلغ الشحن',
      );
      await tester.tap(find.text('حفظ التعديل'));
      await tester.pumpAndSettle();
      final request = adapter.requests.last;
      expect(request.uri.path, '/api/ledger/entry-1/correct');
      expect(request.data, {
        'reason': 'تصحيح مبلغ الشحن',
        'values': {'amount': 250, 'reference': 'REF'},
      });
      expect(find.byType(HesbaModalCard), findsNothing);
    },
  );

  testWidgets('cancel confirms the whole operation and sends only the reason', (
    tester,
  ) async {
    final adapter = _Adapter();
    await mount(tester, adapter, cancel: true);
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'إلغاء العملية الغلط');
    await tester.tap(find.text('تأكيد إلغاء العملية'));
    await tester.pumpAndSettle();
    expect(adapter.requests.last.uri.path, '/api/ledger/entry-1/cancel');
    expect(adapter.requests.last.data, {'reason': 'إلغاء العملية الغلط'});
  });

  testWidgets('keeps a rejected correction open with the entered values', (
    tester,
  ) async {
    final adapter = _Adapter()..reject = true;
    await mount(tester, adapter);
    await tester.enterText(find.byType(TextFormField).at(0), '999999');
    await tester.enterText(find.byType(TextFormField).at(2), 'سبب التعديل');
    await tester.tap(find.text('حفظ التعديل'));
    await tester.pumpAndSettle();
    expect(find.byType(HesbaModalCard), findsOneWidget);
    expect(find.text('الرصيد لا يكفي للتصحيح'), findsOneWidget);
    expect(find.text('999999'), findsOneWidget);
  });

  testWidgets('employee sessions cannot open the admin form', (tester) async {
    final adapter = _Adapter();
    await mount(tester, adapter, admin: false);
    expect(adapter.requests, isEmpty);
    expect(find.byType(HesbaModalCard), findsNothing);
  });
}
