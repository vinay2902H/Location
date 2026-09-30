import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class ReceiverAuthService extends ChangeNotifier {
  static final ReceiverAuthService _instance = ReceiverAuthService._internal();
  factory ReceiverAuthService() => _instance;
  ReceiverAuthService._internal();

  static const String _keyUsername = 'receiver_username';
  static const String _keyEmail = 'receiver_email';

  String? _username;
  String? _email;
  bool _isInitialized = false;

  String? get currentUsername => _username;
  String? get currentEmail => _email;
  bool get isLoggedIn => _username != null && _username!.trim().isNotEmpty;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString(_keyUsername)?.trim();
    if (savedUser != null && savedUser.isNotEmpty && savedUser != 'Player_777') {
      _username = savedUser;
      _email = prefs.getString(_keyEmail);
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Login or register using just a username
  Future<void> loginWithUsername(String username) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) return;

    try {
      final res = await ApiService.loginWithUsername(cleanUsername);
      final userMap = res['user'] as Map<String, dynamic>?;
      _username = userMap?['username']?.toString() ?? cleanUsername;
      _email = userMap?['email']?.toString() ?? '$cleanUsername@winzo.app';
    } catch (_) {
      // Resilient fallback: save locally so the receiver can proceed even when offline
      _username = cleanUsername;
      _email = '$cleanUsername@winzo.app';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, _username!);
    if (_email != null) {
      await prefs.setString(_keyEmail, _email!);
    }

    notifyListeners();
  }

  /// Log out and clear saved receiver credentials
  Future<void> logout() async {
    _username = null;
    _email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyEmail);
    notifyListeners();
  }
}
