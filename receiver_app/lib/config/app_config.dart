import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _keyBaseUrl = 'receiver_backend_url';

  // Active backend URL: 10.0.2.2 for Android emulator, 127.0.0.1 for desktop/web
  static String get defaultBaseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:5001';
    }
    return 'http://127.0.0.1:5001';
  }

  static String _baseUrl = 'http://10.0.2.2:5001';

  static String get baseUrl => _baseUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_keyBaseUrl);
    if (savedUrl == null || savedUrl.isEmpty || savedUrl.contains('onrender.com')) {
      _baseUrl = defaultBaseUrl;
      await prefs.setString(_keyBaseUrl, _baseUrl);
    } else {
      _baseUrl = savedUrl;
    }
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, _baseUrl);
  }

  static String get locationApiUrl => '$_baseUrl/api/location';
  static String get healthApiUrl => '$_baseUrl/api/health';
  static String get socketUrl => _baseUrl;
}
