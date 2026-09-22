import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

/// Permission keys matching backend `AppPermission`.
abstract final class AppPermissions {
  static const viewBalances = 'view_balances';
  static const receiveCollections = 'receive_collections';
  static const manageAssets = 'manage_assets';
  static const topUpAssets = 'top_up_assets';
  static const internalTransfer = 'internal_transfer';
  static const dailyRollover = 'daily_rollover';
  static const manageUsers = 'manage_users';
  static const sellInventory = 'sell_inventory';
  static const manageInventory = 'manage_inventory';
  static const useMachines = 'use_machines';
}

class SessionController extends ChangeNotifier {
  SessionController(this.api) {
    api.onUnauthorized = () => unawaited(logout());
  }

  final ApiClient api;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static const _tokenKey = 'access_token';
  static const _loggedOutKey = 'auth_logged_out';
  bool ready = false;
  bool busy = false;
  String? token;
  String? userId;
  String? username;
  String? displayName;
  String? role;
  List<String> permissions = const [];
  Map<String, dynamic> limits = const {};
  String? error;

  bool get signedIn => token != null;
  bool get isAdmin => role == 'admin';

  bool can(String permission) {
    if (isAdmin) return true;
    return permissions.contains(permission);
  }

  num? limitOf(String key) {
    final value = limits[key];
    if (value == null) return null;
    return value is num ? value : num.tryParse('$value');
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final explicitlyLoggedOut = prefs.getBool(_loggedOutKey) ?? false;
    try {
      if (explicitlyLoggedOut) {
        await _secureStorage.delete(key: _tokenKey);
      } else {
        token = await _secureStorage.read(key: _tokenKey);
        final legacyToken = prefs.getString('token');
        if (token == null && legacyToken != null) {
          await _secureStorage.write(key: _tokenKey, value: legacyToken);
          token = legacyToken;
        }
      }
    } catch (_) {
      // Never keep the splash screen or restore an uncertain session when the
      // platform keychain is unavailable.
      token = null;
    }
    await prefs.remove('token');
    userId = prefs.getString('userId');
    username = prefs.getString('username');
    displayName = prefs.getString('displayName');
    role = prefs.getString('role');
    permissions = prefs.getStringList('permissions') ?? const [];
    api.setToken(token);
    ready = true;
    notifyListeners();
    if (token != null) {
      try {
        await refreshProfile();
      } on DioException catch (error) {
        if (error.response?.statusCode == 401) await logout();
      }
    }
  }

  Future<bool> login(String user, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.login(user.trim(), password);
      final currentUser = result['user'] as Map<String, dynamic>;
      token = result['accessToken'] as String;
      api.setToken(token);
      await _applyUser(currentUser);
      return true;
    } catch (e) {
      try {
        await logout();
      } catch (_) {
        // The logout marker is written before keychain deletion, so an old
        // token will still not be restored on the next launch.
      }
      error = ApiClient.errorMessage(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    final me = await api.getMap(ApiEndpoints.currentUser);
    await _applyUser(me);
    notifyListeners();
  }

  Future<void> _applyUser(Map<String, dynamic> currentUser) async {
    userId = currentUser['id'] as String?;
    username = currentUser['username'] as String?;
    displayName =
        (currentUser['displayName'] as String?)?.trim().isNotEmpty == true
        ? currentUser['displayName'] as String
        : username;
    role = currentUser['role'] as String?;
    permissions = (currentUser['permissions'] as List<dynamic>? ?? const [])
        .map((e) => '$e')
        .toList();
    limits = Map<String, dynamic>.from(
      (currentUser['limits'] as Map?) ?? const {},
    );
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await _secureStorage.write(key: _tokenKey, value: token);
      await prefs.remove(_loggedOutKey);
    }
    await prefs.remove('token');
    if (userId != null) await prefs.setString('userId', userId!);
    if (username != null) await prefs.setString('username', username!);
    if (displayName != null) {
      await prefs.setString('displayName', displayName!);
    }
    if (role != null) await prefs.setString('role', role!);
    await prefs.setStringList('permissions', permissions);
  }

  Future<void> logout() async {
    token = null;
    userId = null;
    username = null;
    displayName = null;
    role = null;
    permissions = const [];
    limits = const {};
    api.setToken(null);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedOutKey, true);
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (_) {
      // The persistent logout marker prevents restoration until a later
      // successful login even if the platform keychain is temporarily down.
    } finally {
      for (final key in [
        'token',
        'userId',
        'username',
        'displayName',
        'role',
        'permissions',
      ]) {
        await prefs.remove(key);
      }
    }
  }
}
