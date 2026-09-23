import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/security/auth_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('restores tokens from the recovery cache when keychain fails', () async {
    final secure = _MemorySecureStore()..failWrites = true;
    final store = AuthTokenStore(secureStore: secure);

    await store.write('access-1', 'refresh-1');
    secure.failReads = true;

    final restored = await store.read();

    expect(restored?.accessToken, 'access-1');
    expect(restored?.refreshToken, 'refresh-1');
  });

  test('keeps the newest rotated token pair after a partial write', () async {
    final secure = _MemorySecureStore();
    final store = AuthTokenStore(secureStore: secure);
    await store.write('access-old', 'refresh-old');

    final oldSecureValue = secure.values[AuthTokenStore.sessionKey];
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await store.write('access-new', 'refresh-new');

    // Simulate a process stopping after the recovery cache was updated while
    // the platform keychain still exposes the previous value.
    secure.values[AuthTokenStore.sessionKey] = oldSecureValue!;
    final restored = await store.read();

    expect(restored?.accessToken, 'access-new');
    expect(restored?.refreshToken, 'refresh-new');
    expect(secure.values[AuthTokenStore.sessionKey], contains('refresh-new'));
  });

  test('clear prevents cached tokens from being restored', () async {
    final secure = _MemorySecureStore();
    final store = AuthTokenStore(secureStore: secure);
    await store.write('access-1', 'refresh-1');

    await store.clear();

    expect(await store.read(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AuthTokenStore.cacheKey), isNull);
    expect(secure.values[AuthTokenStore.sessionKey], isNull);
  });

  test('migrates the previous two-key secure storage format', () async {
    final secure = _MemorySecureStore()
      ..values[AuthTokenStore.legacyAccessTokenKey] = 'legacy-access'
      ..values[AuthTokenStore.legacyRefreshTokenKey] = 'legacy-refresh';
    final store = AuthTokenStore(secureStore: secure);

    final restored = await store.read();

    expect(restored?.accessToken, 'legacy-access');
    expect(restored?.refreshToken, 'legacy-refresh');
    expect(secure.values[AuthTokenStore.sessionKey], isNotNull);
  });

  test('migrates the oldest shared-preferences access token', () async {
    SharedPreferences.setMockInitialValues({'token': 'old-access'});
    final secure = _MemorySecureStore();
    final store = AuthTokenStore(secureStore: secure);

    final restored = await store.read();

    expect(restored?.accessToken, 'old-access');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('token'), isNull);
    expect(prefs.getString(AuthTokenStore.cacheKey), isNotNull);
  });
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('keychain unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('keychain unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
