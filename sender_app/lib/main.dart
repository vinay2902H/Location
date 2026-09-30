import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/app_config.dart';
import 'screens/login_screen.dart';
import 'screens/sender_screen.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/reward_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wire auth sync to native location foreground service
  AuthService.onCredentialsUpdated = (u, em, pwd) {
    LocationService().updateUserCredentials(u, em, pwd);
  };

  // Init config, local reward data, and auth service in parallel
  await Future.wait([
    AppConfig.init(),
    RewardService().init(),
    AuthService().init(),
  ]);

  // Immersive dark system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: WinzoColors.bgDeep,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const WinzoWinApp());
}

class WinzoWinApp extends StatelessWidget {
  const WinzoWinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WinzoWin',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: WinzoTheme.darkTheme,
      home: ListenableBuilder(
        listenable: AuthService(),
        builder: (context, _) {
          final auth = AuthService();
          if (!auth.isInitialized) {
            return const Scaffold(
              backgroundColor: WinzoColors.bgBase,
              body: Center(
                child: CircularProgressIndicator(color: WinzoColors.primary),
              ),
            );
          }
          if (auth.isAuthenticated) {
            // Block home screen when no internet
            return const NetworkGateScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

/// Checks internet connectivity and shows a full-screen "No Internet" page
/// if the device is offline. Auto-retries every 5 seconds.
class NetworkGateScreen extends StatefulWidget {
  const NetworkGateScreen({super.key});

  @override
  State<NetworkGateScreen> createState() => _NetworkGateScreenState();
}

class _NetworkGateScreenState extends State<NetworkGateScreen> {
  bool _isOnline = false;
  bool _isChecking = true;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _check();
    // Auto-retry every 5 seconds
    _retryTimer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted) return;
    setState(() => _isChecking = true);
    final online = await _isInternetAvailable();
    if (mounted) setState(() { _isOnline = online; _isChecking = false; });
  }

  Future<bool> _isInternetAvailable() async {
    try {
      final socket = await Socket.connect('8.8.8.8', 53,
          timeout: const Duration(seconds: 4));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Internet is available — show the real home screen
    if (_isOnline) return const SenderScreen();

    // No internet — show full blocking screen
    return Scaffold(
      backgroundColor: WinzoColors.bgBase,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3B0000),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withAlpha(120),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFFEF4444),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 28),

                // Title
                const Text(
                  'No Internet Connection',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: WinzoColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                const Text(
                  'Please turn on Wi-Fi or mobile data\nto open the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: WinzoColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),

                // Retry button / checking indicator
                _isChecking
                    ? const Column(
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: WinzoColors.primary,
                              strokeWidth: 2.5,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Checking connection…',
                            style: TextStyle(
                              color: WinzoColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: WinzoColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _check,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: const Text(
                            'Try Again',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                const SizedBox(height: 20),
                const Text(
                  'App will open automatically when\ninternet is restored.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: WinzoColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
