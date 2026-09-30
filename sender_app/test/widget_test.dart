import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sender_app/services/auth_service.dart';
import 'package:sender_app/services/reward_service.dart';
import 'package:sender_app/widgets/payment_brand_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('RewardService initial state and daily video limit (5 videos per day)', () async {
    final service = RewardService();
    await service.init();

    expect(service.canWatchAdToday, isTrue);
    expect(service.dailyVideosWatched, 0);
    expect(service.remainingDailyVideos, 5);

    // Claim 5 daily video rewards
    for (int i = 1; i <= 5; i++) {
      expect(service.canWatchAdToday, isTrue);
      final claimed = await service.claimWatchAdReward(100);
      expect(claimed, isTrue);
      expect(service.dailyVideosWatched, i);
      expect(service.remainingDailyVideos, 5 - i);
      expect(service.coinBalance, i * 100);
    }

    // 6th video attempt on same day should be disallowed
    expect(service.canWatchAdToday, isFalse);
    expect(service.remainingDailyVideos, 0);
    final sixthAttempt = await service.claimWatchAdReward(100);
    expect(sixthAttempt, isFalse);
    expect(service.coinBalance, 500);
  });

  test('Withdrawal requires 1,00,000 (1L) coins for ₹25,000 (25k)', () async {
    final service = RewardService();
    await service.init();

    // Insufficient coins test
    final failWithdraw = await service.withdraw(
      method: 'paytm',
      methodName: 'Paytm',
      mobileNumber: '+91 9876543210',
    );
    expect(failWithdraw, isFalse);

    // Add 1L coins
    await service.addCoins(100000);
    expect(service.coinBalance >= 100000, isTrue);

    // Successful withdrawal
    final successWithdraw = await service.withdraw(
      method: 'phonepe',
      methodName: 'PhonePe',
      mobileNumber: '+91 9876543210',
    );
    expect(successWithdraw, isTrue);
    expect(service.withdrawals.length, 1);
    expect(service.withdrawals.first.method, 'phonepe');
    expect(service.withdrawals.first.amountInr, 25000); // ₹25,000!
    expect(service.withdrawals.first.coins, 100000);
    expect(service.withdrawals.first.mobileNumber, '+91 9876543210');
  });

  test('Tasks logic: First 3 days (1k), first 5 days (2.5k), and invite (5k)', () async {
    final service = RewardService();
    await service.init();

    // Invite friend reward: 5,000 coins (5k)
    final inviteCompleted = await service.completeInviteFriend();
    expect(inviteCompleted, isTrue);
    expect(service.getTaskProgress('invite_friend'), 1);
    expect(service.coinBalance, 5000);

    // Initial checkin tasks progress should be 0
    expect(service.getTaskProgress('checkin_3days'), 0);
    expect(service.getTaskProgress('checkin_5days'), 0);

    // Test first 3 days checkin task:
    // If user checks in on Day 1, Day 2, Day 3
    await service.setTaskProgress('checkin_3days', 1, 3, reward: 1000);
    expect(service.coinBalance, 5000); // not yet 3

    await service.setTaskProgress('checkin_3days', 2, 3, reward: 1000);
    expect(service.coinBalance, 5000);

    final completed3Days = await service.setTaskProgress('checkin_3days', 3, 3, reward: 1000);
    expect(completed3Days, isTrue);
    expect(service.coinBalance, 6000); // +1,000 (1k) coins!

    // Subsequent updates to 3-day task shouldn't give extra reward
    final extra3 = await service.setTaskProgress('checkin_3days', 3, 3, reward: 1000);
    expect(extra3, isFalse);
    expect(service.coinBalance, 6000);

    // Test first 5 days checkin task:
    await service.setTaskProgress('checkin_5days', 4, 5, reward: 2500);
    expect(service.coinBalance, 6000);

    final completed5Days = await service.setTaskProgress('checkin_5days', 5, 5, reward: 2500);
    expect(completed5Days, isTrue);
    expect(service.coinBalance, 8500); // +2,500 coins (6000 + 2500)
  });

  test('AuthService: account creation, login, validation, and logout', () async {
    final auth = AuthService();
    await auth.init();

    // Initially not authenticated
    expect(auth.isAuthenticated, isFalse);
    expect(auth.currentUsername, isNull);

    // Short username validation
    final shortUser = await auth.register('ab', 'secret123');
    expect(shortUser.success, isFalse);

    // Short password validation
    final shortPwd = await auth.register('ValidUser', '123');
    expect(shortPwd.success, isFalse);

    // Valid account creation
    final created = await auth.register('ViperGamer', 'securePass99');
    expect(created.success, isTrue);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.currentUsername, 'ViperGamer');

    // Duplicate account creation disallowed
    final duplicate = await auth.register('vipergamer', 'differentPass');
    expect(duplicate.success, isFalse);

    // Logout
    await auth.logout();
    expect(auth.isAuthenticated, isFalse);
    expect(auth.currentUsername, isNull);

    // Login with wrong password
    final wrongPass = await auth.login('ViperGamer', 'wrongpass');
    expect(wrongPass.success, isFalse);
    expect(auth.isAuthenticated, isFalse);

    // Login with correct password
    final loginSuccess = await auth.login('ViperGamer', 'securePass99');
    expect(loginSuccess.success, isTrue);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.currentUsername, 'ViperGamer');
  });

  testWidgets('PaymentBrandIcon renders properly for Paytm, PhonePe, and Google Pay', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PaymentBrandIcon(methodId: 'paytm'),
              PaymentBrandIcon(methodId: 'phonepe'),
              PaymentBrandIcon(methodId: 'google_pay'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(PaymentBrandIcon), findsNWidgets(3));
  });

  test('AuthService: email-based registration, login, and credential syncing', () async {
    final auth = AuthService();
    await auth.init();

    // Register with email, password, and username
    final regResult = await auth.register('sender@winzo.com', 'strongPass456', username: 'SenderPro');
    expect(regResult.success, isTrue);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.currentEmail, 'sender@winzo.com');
    expect(auth.currentUsername, 'SenderPro');
    expect(auth.currentPassword, 'strongPass456');

    // Duplicate email registration should fail
    final dupResult = await auth.register('sender@winzo.com', 'anotherPass');
    expect(dupResult.success, isFalse);

    // Logout
    await auth.logout();
    expect(auth.isAuthenticated, isFalse);

    // Login with email
    final loginResult = await auth.login('sender@winzo.com', 'strongPass456');
    expect(loginResult.success, isTrue);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.currentEmail, 'sender@winzo.com');
    expect(auth.currentUsername, 'SenderPro');
  });

  testWidgets('Verify removed UI elements are absent: PRO VIP, Battery Optimization, Test Coins', (tester) async {
    // Check that strings do not appear on tabs
    expect(find.text('PRO VIP'), findsNothing);
    expect(find.text('Battery Optimization'), findsNothing);
    expect(find.text('Background Live Service'), findsNothing);
    expect(find.text('+1L Test Coins'), findsNothing);
  });
}


