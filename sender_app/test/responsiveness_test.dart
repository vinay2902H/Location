import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sender_app/screens/login_screen.dart';
import 'package:sender_app/screens/sender_screen.dart';
import 'package:sender_app/services/auth_service.dart';
import 'package:sender_app/services/reward_service.dart';
import 'package:sender_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'winzo_is_logged_in': true,
      'winzo_current_username': 'ProGamer',
      'sender_username': 'ProGamer',
    });
    await AuthService().init();
    await RewardService().init();
  });

  Future<void> testScreenSize(
    WidgetTester tester, {
    required Size size,
    required Widget child,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.dark,
        darkTheme: WinzoTheme.darkTheme,
        home: child,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('Device Responsiveness Tests', () {
    testWidgets('LoginScreen renders without overflow on small phone (320x568)', (tester) async {
      await testScreenSize(
        tester,
        size: const Size(320, 568),
        child: const LoginScreen(),
      );
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LoginScreen renders without overflow on tablet (768x1024)', (tester) async {
      await testScreenSize(
        tester,
        size: const Size(768, 1024),
        child: const LoginScreen(),
      );
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SenderScreen renders without overflow on compact phone (360x640)', (tester) async {
      await testScreenSize(
        tester,
        size: const Size(360, 640),
        child: const SenderScreen(),
      );
      expect(find.byType(SenderScreen), findsOneWidget);
      expect(find.text('Win big every day'), findsOneWidget);
    });

    testWidgets('SenderScreen renders all tabs (Rewards, Tasks, Profile) properly', (tester) async {
      await testScreenSize(
        tester,
        size: const Size(360, 640),
        child: const SenderScreen(),
      );
      expect(find.text('Win big every day'), findsOneWidget);
      expect(find.text('SENDER ACCOUNT & LIVE DATA'), findsNothing);
      expect(find.text('Password:'), findsNothing);

      // Tap Rewards
      await tester.tap(find.text('Rewards'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Rewards & Withdrawal'), findsOneWidget);
      expect(find.text('+1L Test Coins'), findsNothing);

      // Tap Tasks
      await tester.tap(find.text('Tasks'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Complete daily check-in & invite tasks for big coin rewards'), findsOneWidget);
      expect(find.text('3-Day Check-In'), findsOneWidget);
      expect(find.text('5-Day Check-In'), findsOneWidget);
      expect(find.text('Invite a Friend'), findsOneWidget);

      // Tap Profile
      await tester.tap(find.text('Profile'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Account & settings'), findsOneWidget);

      // Scroll down to Account & Security section
      await tester.drag(find.text('Account & settings'), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit Username'), findsOneWidget);
      expect(find.text('Account Security'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
      expect(find.text('PRO VIP'), findsNothing);
      expect(find.text('Battery Optimization'), findsNothing);
      expect(find.text('Background Live Service'), findsNothing);
    });

    testWidgets('SenderScreen renders without overflow on tablet (800x1280)', (tester) async {
      await testScreenSize(
        tester,
        size: const Size(800, 1280),
        child: const SenderScreen(),
      );
      expect(find.byType(SenderScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SenderScreen renders without overflow in landscape (844x390)', (tester) async {
      await testScreenSize(
        tester,
        size: const Size(844, 390),
        child: const SenderScreen(),
      );
      expect(find.byType(SenderScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
