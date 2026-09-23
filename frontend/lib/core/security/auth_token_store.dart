import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    required this.updatedAtMicros,
  });

  final String accessToken;
  final String? refreshToken;
  final int updatedAtMicros;

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'updatedAtMicros': updatedAtMicros,
  };

  static AuthTokens? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final accessToken = json['accessToken'];
      final refreshToken = json['refreshToken'];
      final updatedAt = json['updatedAtMicros'];
      if (accessToken is! String || accessToken.isEmpty) return null;
      if (refreshToken != null &&
          (refreshToken is! String || refreshToken.isEmpty)) {
        return null;
      }
      return AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken as String?,
        updatedAtMicros: updatedAt is int ? updatedAt : 0,
      );
    } catch (_) {
      return null;
    }
  }
}

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore();

  static const _storage = FlutterSecureStorage(
    // The legacy macOS keychain works for distributable builds without the
    // Keychain Sharing entitlement/provisioning requirement.
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Persists the access/refresh pair as one versioned value.
///
/// The secure store is the primary copy. Shared preferences is a recovery
/// cache for desktop machines where the OS keychain is temporarily unavailable
/// or reports a successful write that cannot be read after an app restart.
class AuthTokenStore {
  AuthTokenStore({SecureKeyValueStore? secureStore})
    : _secureStore = secureStore ?? const FlutterSecureKeyValueStore();

  static const sessionKey = 'auth_session_v2';
  static const cacheKey = 'auth_session_cache_v2';
  static const legacyAccessTokenKey = 'access_token';
  static const legacyRefreshTokenKey = 'refresh_token';

  final SecureKeyValueStore _secureStore;

  Future<AuthTokens?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = AuthTokens.fromJson(prefs.getString(cacheKey));
    final legacyCachedAccess = prefs.getString('token');
    final legacyCached =
        legacyCachedAccess == null || legacyCachedAccess.isEmpty
        ? null
        : AuthTokens(accessToken: legacyCachedAccess, updatedAtMicros: 0);

    AuthTokens? secureSession;
    AuthTokens? secured;
    try {
      secureSession = AuthTokens.fromJson(await _secureStore.read(sessionKey));
      secured = secureSession ?? await _readLegacySecureTokens();
    } catch (_) {
      // The recovery cache below keeps the user signed in when the platform
      // keychain is unavailable.
    }

    final selected = _newest(_newest(secured, cached), legacyCached);
    if (selected == null) return null;

    // Repair either copy after a partial write or a temporary keychain error.
    final encoded = jsonEncode(selected.toJson());
    if (cached?.updatedAtMicros != selected.updatedAtMicros) {
      await prefs.setString(cacheKey, encoded);
    }
    await prefs.remove('token');
    if (secureSession?.updatedAtMicros != selected.updatedAtMicros) {
      try {
        await _secureStore.write(sessionKey, encoded);
      } catch (_) {
        // The cache remains a valid recovery copy.
      }
    }
    return selected;
  }

  Future<void> write(String accessToken, String refreshToken) async {
    final tokens = AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
    final encoded = jsonEncode(tokens.toJson());

    // Both stores receive the same single value, so a rotated refresh token
    // cannot be paired with an older access token after a restart.
    try {
      await _secureStore.write(sessionKey, encoded);
    } catch (_) {
      // Continue to the recovery cache.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey, encoded);
    await prefs.remove('token');

    await _deleteLegacySecureTokens();
  }

  Future<void> clear() async {
    // Clear the recovery copy first so a keychain failure can never resurrect
    // a session after an explicit logout.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cacheKey);
    await prefs.remove('token');
    try {
      await _secureStore.delete(sessionKey);
    } catch (_) {
      // The explicit logout marker in SessionController is authoritative.
    }
    await _deleteLegacySecureTokens();
  }

  Future<AuthTokens?> _readLegacySecureTokens() async {
    final access = await _secureStore.read(legacyAccessTokenKey);
    if (access == null || access.isEmpty) return null;
    final refresh = await _secureStore.read(legacyRefreshTokenKey);
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh?.isEmpty == true ? null : refresh,
      updatedAtMicros: 0,
    );
  }

  Future<void> _deleteLegacySecureTokens() async {
    for (final key in [legacyAccessTokenKey, legacyRefreshTokenKey]) {
      try {
        await _secureStore.delete(key);
      } catch (_) {
        // Best-effort migration cleanup.
      }
    }
  }

  static AuthTokens? _newest(AuthTokens? first, AuthTokens? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first.updatedAtMicros >= second.updatedAtMicros ? first : second;
  }
}
