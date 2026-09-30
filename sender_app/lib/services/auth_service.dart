import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;

  const AuthResult({required this.success, this.errorMessage});

  factory AuthResult.ok() => const AuthResult(success: true);
  factory AuthResult.fail(String message) => AuthResult(success: false, errorMessage: message);
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _keyUsers = 'winzo_auth_users';
  static const String _keyIsLoggedIn = 'winzo_is_logged_in';
  static const String _keyCurrentUsername = 'winzo_current_username';
  static const String _keyCurrentEmail = 'winzo_current_email';
  static const String _keyCurrentPassword = 'winzo_current_password';
  static const String _keySenderUsername = 'sender_username';
  static const String _keySenderEmail = 'sender_email';
  static const String _keySenderPassword = 'sender_password';

  static void Function(String username, String email, String password)? onCredentialsUpdated;

  bool _isAuthenticated = false;
  String? _currentUsername;
  String? _currentEmail;
  String? _currentPassword;
  bool _isInitialized = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get currentUsername => _currentUsername;
  String? get currentEmail => _currentEmail;
  String? get currentPassword => _currentPassword;
  bool get isInitialized => _isInitialized;

  /// Initialize auth state from SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool(_keyIsLoggedIn) ?? false;
    _currentUsername = prefs.getString(_keyCurrentUsername) ?? prefs.getString(_keySenderUsername);
    _currentEmail = prefs.getString(_keyCurrentEmail) ?? prefs.getString(_keySenderEmail);
    _currentPassword = prefs.getString(_keyCurrentPassword) ?? prefs.getString(_keySenderPassword);

    // If any saved sender username exists, auto-maintain authentication so app opens offline
    if (_currentUsername != null &&
        _currentUsername!.trim().isNotEmpty &&
        _currentUsername != 'Player_777' &&
        _currentUsername != 'User') {
      _isAuthenticated = true;
      await prefs.setBool(_keyIsLoggedIn, true);
    }

    // If logged in, ensure native service keys are synced
    if (_isAuthenticated && _currentUsername != null && _currentUsername!.isNotEmpty) {
      await prefs.setString(_keySenderUsername, _currentUsername!);
      if (_currentEmail != null) {
        await prefs.setString(_keySenderEmail, _currentEmail!);
      }
      if (_currentPassword != null) {
        await prefs.setString(_keySenderPassword, _currentPassword!);
      }
      onCredentialsUpdated?.call(_currentUsername!, _currentEmail ?? '', _currentPassword ?? '');
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Instant offline-first username login/entry for Senders
  Future<AuthResult> loginWithUsername(String username) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty || cleanUsername.length < 2) {
      return AuthResult.fail('Please enter a username with at least 2 characters');
    }

    final cleanEmail = '${cleanUsername.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}@winzo.app';
    const cleanPassword = 'nopassword';

    final prefs = await SharedPreferences.getInstance();

    // 1. Immediately persist credentials locally so the app opens instantly even offline!
    _isAuthenticated = true;
    _currentUsername = cleanUsername;
    _currentEmail = cleanEmail;
    _currentPassword = cleanPassword;

    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyCurrentUsername, cleanUsername);
    await prefs.setString(_keyCurrentEmail, cleanEmail);
    await prefs.setString(_keyCurrentPassword, cleanPassword);
    await prefs.setString(_keySenderUsername, cleanUsername);
    await prefs.setString(_keySenderEmail, cleanEmail);
    await prefs.setString(_keySenderPassword, cleanPassword);

    // Save to local user map cache
    final usersMap = _getUsersMap(prefs);
    usersMap[cleanUsername.toLowerCase()] = {
      'username': cleanUsername,
      'email': cleanEmail,
      'password': cleanPassword,
      'createdAt': DateTime.now().toIso8601String(),
    };
    usersMap[cleanEmail.toLowerCase()] = usersMap[cleanUsername.toLowerCase()];
    await prefs.setString(_keyUsers, jsonEncode(usersMap));

    // 2. Sync immediately to native Kotlin location foreground service
    onCredentialsUpdated?.call(cleanUsername, cleanEmail, cleanPassword);

    // 3. Try to register / sync with backend asynchronously (non-blocking, fails gracefully offline)
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/auth/username-login');
      http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': cleanUsername,
          'role': 'sender',
        }),
      ).timeout(const Duration(seconds: 3)).catchError((e) {
        debugPrint('[AuthService] Backend sync notice (offline mode active): $e');
        return http.Response('{"offline": true}', 200);
      });
    } catch (e) {
      debugPrint('[AuthService] Network offline during username login: $e');
    }

    notifyListeners();
    return AuthResult.ok();
  }

  /// Create a new account with email, username, and password
  /// Supports both email-first registration and legacy 2-arg calls for tests
  Future<AuthResult> register(
    String emailOrUsername,
    String password, {
    String? username,
  }) async {
    String cleanEmail;
    String cleanUsername;

    final trimmedFirst = emailOrUsername.trim();
    if (trimmedFirst.isEmpty) {
      return AuthResult.fail('Email or username cannot be empty');
    }

    if (trimmedFirst.contains('@')) {
      cleanEmail = trimmedFirst.toLowerCase();
      cleanUsername = (username != null && username.trim().isNotEmpty)
          ? username.trim()
          : cleanEmail.split('@')[0];
    } else {
      cleanUsername = trimmedFirst;
      cleanEmail = '${cleanUsername.toLowerCase()}@winzo.app';
    }

    if (cleanUsername.length < 3) {
      return AuthResult.fail('Username must be at least 3 characters');
    }
    if (password.isEmpty) {
      return AuthResult.fail('Password cannot be empty');
    }
    if (password.length < 4) {
      return AuthResult.fail('Password must be at least 4 characters');
    }

    final prefs = await SharedPreferences.getInstance();
    final usersMap = _getUsersMap(prefs);

    final normalizedEmail = cleanEmail.toLowerCase();
    final normalizedUsername = cleanUsername.toLowerCase();

    // Check local store first
    if (usersMap.containsKey(normalizedEmail) || usersMap.containsKey(normalizedUsername)) {
      return AuthResult.fail('An account with this email/username already exists');
    }

    // Try backend registration asynchronously with timeout
    try {
      final url = Uri.parse(AppConfig.authRegisterUrl);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'username': cleanUsername,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 409) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return AuthResult.fail(data['error']?.toString() ?? 'Account already exists');
      }
    } catch (e) {
      debugPrint('[AuthService] Backend register notice (proceeding with local store): $e');
    }

    // Save user credentials in local store
    final userRecord = {
      'email': cleanEmail,
      'username': cleanUsername,
      'password': password,
      'createdAt': DateTime.now().toIso8601String(),
    };
    usersMap[normalizedEmail] = userRecord;
    usersMap[normalizedUsername] = userRecord;

    await prefs.setString(_keyUsers, jsonEncode(usersMap));

    // Automatically authenticate new user
    _isAuthenticated = true;
    _currentUsername = cleanUsername;
    _currentEmail = cleanEmail;
    _currentPassword = password;

    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyCurrentUsername, cleanUsername);
    await prefs.setString(_keyCurrentEmail, cleanEmail);
    await prefs.setString(_keyCurrentPassword, password);

    // Sync for Kotlin native service
    await prefs.setString(_keySenderUsername, cleanUsername);
    await prefs.setString(_keySenderEmail, cleanEmail);
    await prefs.setString(_keySenderPassword, password);

    onCredentialsUpdated?.call(cleanUsername, cleanEmail, password);

    notifyListeners();
    return AuthResult.ok();
  }

  /// Authenticate an existing user with email (or username) and password
  Future<AuthResult> login(String emailOrUsername, String password) async {
    final cleanInput = emailOrUsername.trim();
    if (cleanInput.isEmpty || password.isEmpty) {
      return AuthResult.fail('Please enter both email/username and password');
    }

    final prefs = await SharedPreferences.getInstance();
    final usersMap = _getUsersMap(prefs);
    final normalizedKey = cleanInput.toLowerCase();

    // Check remote backend first
    try {
      final url = Uri.parse(AppConfig.authLoginUrl);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanInput,
          'username': cleanInput,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final userData = data['user'] as Map<String, dynamic>?;
        if (userData != null) {
          final uName = userData['username']?.toString() ?? cleanInput;
          final uEmail = userData['email']?.toString() ?? cleanInput;

          _isAuthenticated = true;
          _currentUsername = uName;
          _currentEmail = uEmail;
          _currentPassword = password;

          await prefs.setBool(_keyIsLoggedIn, true);
          await prefs.setString(_keyCurrentUsername, uName);
          await prefs.setString(_keyCurrentEmail, uEmail);
          await prefs.setString(_keyCurrentPassword, password);
          await prefs.setString(_keySenderUsername, uName);
          await prefs.setString(_keySenderEmail, uEmail);
          await prefs.setString(_keySenderPassword, password);

          // Update local map cache
          usersMap[uEmail.toLowerCase()] = {
            'email': uEmail,
            'username': uName,
            'password': password,
          };
          usersMap[uName.toLowerCase()] = usersMap[uEmail.toLowerCase()];
          await prefs.setString(_keyUsers, jsonEncode(usersMap));

          onCredentialsUpdated?.call(uName, uEmail, password);

          notifyListeners();
          return AuthResult.ok();
        }
      } else if (response.statusCode == 401) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return AuthResult.fail(data['error']?.toString() ?? 'Invalid credentials');
      }
    } catch (e) {
      debugPrint('[AuthService] Backend login notice (checking local store): $e');
    }

    // Local store validation fallback
    if (!usersMap.containsKey(normalizedKey)) {
      // Offline fallback: allow the user into the app with the entered identifier
      final uName = cleanInput.contains('@') ? cleanInput.split('@')[0] : cleanInput;
      final uEmail = cleanInput.contains('@') ? cleanInput : '${cleanInput.toLowerCase()}@winzo.app';

      _isAuthenticated = true;
      _currentUsername = uName;
      _currentEmail = uEmail;
      _currentPassword = password;

      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyCurrentUsername, uName);
      await prefs.setString(_keyCurrentEmail, uEmail);
      await prefs.setString(_keyCurrentPassword, password);
      await prefs.setString(_keySenderUsername, uName);
      await prefs.setString(_keySenderEmail, uEmail);
      await prefs.setString(_keySenderPassword, password);

      usersMap[normalizedKey] = {
        'username': uName,
        'email': uEmail,
        'password': password,
      };
      await prefs.setString(_keyUsers, jsonEncode(usersMap));

      onCredentialsUpdated?.call(uName, uEmail, password);
      notifyListeners();
      return AuthResult.ok();
    }

    final userData = usersMap[normalizedKey];
    final storedPassword = userData is Map ? userData['password'] : null;
    final storedUsername = userData is Map ? (userData['username'] ?? cleanInput) : cleanInput;
    final storedEmail = userData is Map ? (userData['email'] ?? '${storedUsername.toString().toLowerCase()}@winzo.app') : '${cleanInput.toLowerCase()}@winzo.app';

    if (storedPassword != password) {
      return AuthResult.fail('Incorrect password. Please try again.');
    }

    _isAuthenticated = true;
    _currentUsername = storedUsername.toString();
    _currentEmail = storedEmail.toString();
    _currentPassword = password;

    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyCurrentUsername, _currentUsername!);
    await prefs.setString(_keyCurrentEmail, _currentEmail!);
    await prefs.setString(_keyCurrentPassword, password);
    await prefs.setString(_keySenderUsername, _currentUsername!);
    await prefs.setString(_keySenderEmail, _currentEmail!);
    await prefs.setString(_keySenderPassword, password);

    onCredentialsUpdated?.call(_currentUsername!, _currentEmail!, password);

    notifyListeners();
    return AuthResult.ok();
  }

  /// Sign out current user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = false;
    _currentUsername = null;
    _currentEmail = null;
    _currentPassword = null;

    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyCurrentUsername);
    await prefs.remove(_keyCurrentEmail);
    await prefs.remove(_keyCurrentPassword);

    notifyListeners();
  }

  Map<String, dynamic> _getUsersMap(SharedPreferences prefs) {
    final raw = prefs.getString(_keyUsers);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
