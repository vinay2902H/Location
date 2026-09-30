import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';
import 'screens/receiver_login_screen.dart';
import 'screens/receiver_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();
  final prefs = await SharedPreferences.getInstance();
  final savedUser = prefs.getString('mapped_receiver_username')?.trim();
  final hasUser = savedUser != null && savedUser.isNotEmpty;
  runApp(ReceiverApp(
    initialHome: hasUser ? const ReceiverScreen() : const ReceiverLoginScreen(),
  ));
}

class ReceiverApp extends StatelessWidget {
  final Widget? initialHome;
  const ReceiverApp({super.key, this.initialHome});

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
      home: initialHome ?? const ReceiverScreen(),
    );
  }
}
