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
          return auth.isAuthenticated
              ? const SenderScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}
