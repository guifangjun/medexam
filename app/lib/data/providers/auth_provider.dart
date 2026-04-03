import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> checkAuth() async {
    await _api.loadToken();
    if (!_api.hasToken) {
      _isLoggedIn = false;
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.getMe();
      _user = User.fromJson(res.data);
      _isLoggedIn = true;
      _error = null;
    } catch (e) {
      _isLoggedIn = false;
      _user = null;
      await _api.clearToken();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final res = await _api.login(username, password);
      await _api.setToken(res.data['access_token']);

      final userRes = await _api.getMe();
      _user = User.fromJson(userRes.data);
      _isLoggedIn = true;
      return true;
    } catch (e) {
      _error = '登录失败，请检查用户名和密码';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _api.register({
        'username': username,
        'email': email,
        'password': password,
        if (fullName != null) 'full_name': fullName,
      });

      // 注册成功后自动登录
      return await login(username, password);
    } catch (e) {
      _error = '注册失败，请稍后重试';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
