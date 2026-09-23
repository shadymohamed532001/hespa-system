import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('retries a transient mutation with the same idempotency key', () async {
    final adapter = _QueueAdapter([
      const _StubResponse(503, {'message': 'temporary'}),
      const _StubResponse(200, {'ok': true}),
    ]);
    final client = _client(adapter, maxAttempts: 2);

    final result = await client.post('/accounts/a/top-up', {'amount': 100});

    expect(result, {'ok': true});
    expect(adapter.idempotencyKeys, hasLength(2));
    expect(adapter.idempotencyKeys.toSet(), hasLength(1));
  });

  test(
    'manual retry after an uncertain failure reuses the original key',
    () async {
      final adapter = _QueueAdapter([
        const _StubResponse(503, {'message': 'temporary'}),
        const _StubResponse(503, {'message': 'temporary'}),
        const _StubResponse(200, {'ok': true}),
      ]);
      final client = _client(adapter, maxAttempts: 2);

      await expectLater(
        client.post('/treasury/transfer', {
          'fromType': 'treasury',
          'toType': 'account',
          'toId': 'a',
          'amount': 50,
        }),
        throwsA(isA<DioException>()),
      );

      final result = await client.post('/treasury/transfer', {
        'amount': 50,
        'toId': 'a',
        'toType': 'account',
        'fromType': 'treasury',
      });

      expect(result, {'ok': true});
      expect(adapter.idempotencyKeys, hasLength(3));
      expect(adapter.idempotencyKeys.toSet(), hasLength(1));
    },
  );

  test('retry after an app restart restores the pending key', () async {
    final firstAdapter = _QueueAdapter([
      const _StubResponse(503, {'message': 'temporary'}),
    ]);
    final firstClient = _client(firstAdapter, maxAttempts: 1);
    const operation = {'amount': 75, 'reference': 'restart-test'};

    await expectLater(
      firstClient.post('/accounts/a/top-up', operation),
      throwsA(isA<DioException>()),
    );

    final secondAdapter = _QueueAdapter([
      const _StubResponse(200, {'ok': true}),
    ]);
    final restartedClient = _client(secondAdapter, maxAttempts: 1);
    expect(await restartedClient.post('/accounts/a/top-up', operation), {
      'ok': true,
    });
    expect(
      secondAdapter.idempotencyKeys.single,
      firstAdapter.idempotencyKeys.single,
    );
  });
}

ApiClient _client(_QueueAdapter adapter, {required int maxAttempts}) {
  return ApiClient(
      baseUrl: 'https://example.test/api',
      adapter: adapter,
      retryBaseDelay: Duration.zero,
      maxMutationAttempts: maxAttempts,
      delay: (_) async {},
    )
    ..setMutationScope('test-user')
    ..setToken('test-token');
}

class _StubResponse {
  const _StubResponse(this.statusCode, this.body);

  final int statusCode;
  final Object body;
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);

  final List<_StubResponse> responses;
  final List<String> idempotencyKeys = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    idempotencyKeys.add('${options.headers['Idempotency-Key']}');
    final response = responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
