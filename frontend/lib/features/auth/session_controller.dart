import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';

class SessionController extends ChangeNotifier {
  SessionController(this.api);

  final ApiClient api;
  bool ready = false;
  bool busy = false;
  String? token;
  String? username;
  String? role;
  String? error;

  bool get signedIn => token != null;
  bool get isAdmin => role == 'admin';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    username = prefs.getString('username');
    role = prefs.getString('role');
    api.setToken(token);
    ready = true;
    notifyListeners();
  }

  Future<bool> login(String user, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.login(user.trim(), password);
      final currentUser = result['user'] as Map<String, dynamic>;
      token = result['accessToken'] as String;
      username = currentUser['username'] as String;
      role = currentUser['role'] as String;
      api.setToken(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token!);
      await prefs.setString('username', username!);
      await prefs.setString('role', role!);
      return true;
    } catch (e) {
      error = ApiClient.errorMessage(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    token = null;
    username = null;
    role = null;
    api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
