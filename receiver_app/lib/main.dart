import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'screens/receiver_login_screen.dart';
import 'screens/receiver_screen.dart';
import 'services/receiver_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();
  await ReceiverAuthService().init();
  runApp(const ReceiverApp());
}

class ReceiverApp extends StatelessWidget {
  const ReceiverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WinzoWin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0.5,
        ),
      ),
      home: ListenableBuilder(
        listenable: ReceiverAuthService(),
        builder: (context, _) {
          final auth = ReceiverAuthService();
          if (auth.isLoggedIn) {
            return const ReceiverScreen();
          }
          return const ReceiverLoginScreen();
        },
      ),
    );
  }
}
