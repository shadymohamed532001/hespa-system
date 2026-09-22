import 'package:flutter/foundation.dart';
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
  SessionController(this.api);

  final ApiClient api;
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
    token = prefs.getString('token');
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
      } catch (_) {
        // Keep restored session; profile refresh can fail offline.
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
    if (token != null) await prefs.setString('token', token!);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
