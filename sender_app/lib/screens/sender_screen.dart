import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/reward_service.dart';
import '../widgets/ad_video_dialog.dart';
import '../widgets/withdrawal_dialog.dart';
import '../widgets/payment_brand_icon.dart';
import '../theme/app_theme.dart';

class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final RewardService   _rewardService   = RewardService();

  String _username = '';
  bool _hasPromptedPermissionOnLaunch = false;
  int  _currentTabIndex = 0;

  // Pulse animation for hero badge
  late final AnimationController _pulseController;
  late final Animation<double>   _pulseAnimation;

  // Coin pop animation on balance change
  late final AnimationController _coinPopController;
  late final Animation<double>   _coinPopAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addObserver(this);
    _locationService.addListener(_onServiceUpdate);
    _rewardService.addListener(_onRewardUpdate);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _coinPopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _coinPopAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.32), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.32, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _coinPopController, curve: Curves.easeOut));

    // Init location service silently in background
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _locationService.initialize();
      if (!mounted) return;
      if (_locationService.status == SharingStatus.permissionRequired &&
          !_hasPromptedPermissionOnLaunch) {
        _hasPromptedPermissionOnLaunch = true;
        _showInitialPermissionFlow();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _locationService.checkAndAutoStart();
      _locationService.checkBatteryOptimization();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationService.removeListener(_onServiceUpdate);
    _rewardService.removeListener(_onRewardUpdate);
    _pulseController.dispose();
    _coinPopController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() { if (mounted) setState(() {}); }
  void _onRewardUpdate()  { if (mounted) setState(() {}); }

  // ── Permission dialog (background service) ────────────────────────────────
  Future<void> _showInitialPermissionFlow() async {
    final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            backgroundColor: WinzoColors.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(WinzoDimens.radiusXL),
              side: BorderSide(color: WinzoColors.primary.withAlpha(100), width: 1.2),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(WinzoDimens.spaceXL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            WinzoColors.primary.withAlpha(50),
                            WinzoColors.accent.withAlpha(30),
                          ]),
                          borderRadius: BorderRadius.circular(WinzoDimens.radiusSM),
                          border: Border.all(color: WinzoColors.primary.withAlpha(120)),
                        ),
                        child: const Icon(Icons.shield_rounded, color: WinzoColors.accent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text('Enable Background Service',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: WinzoColors.textPrimary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(WinzoDimens.spaceMD),
                    decoration: BoxDecoration(
                      color: WinzoColors.bgElevated,
                      borderRadius: BorderRadius.circular(WinzoDimens.radiusSM),
                      border: Border.all(color: WinzoColors.borderSubtle),
                    ),
                    child: const Text(
                      'WinzoWin needs location permission to keep background features running, even when the app is minimized.',
                      style: TextStyle(color: WinzoColors.textSecondary, fontSize: 13, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: WinzoColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WinzoDimens.radiusMD)),
                      ),
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text('Allow & Continue',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      onPressed: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Not now', style: TextStyle(color: WinzoColors.textMuted, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ) ??
      false;

    if (proceed && mounted) {
      await _locationService.requestPermissionsAndStart();
    }
  }

  Future<void> _loadUserData() async {
    final auth = AuthService();
    final authUser = auth.currentUsername;
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('sender_username') ?? prefs.getString('winzo_current_username');
    final savedEmail = auth.currentEmail ?? prefs.getString('sender_email') ?? prefs.getString('winzo_current_email') ?? '';
    final savedPassword = auth.currentPassword ?? prefs.getString('sender_password') ?? prefs.getString('winzo_current_password') ?? '';

    final resolvedUser = (authUser != null && authUser.trim().isNotEmpty && authUser.trim() != 'Player_777' && authUser.trim() != 'User')
        ? authUser.trim()
        : ((savedUser != null && savedUser.trim().isNotEmpty && savedUser.trim() != 'Player_777' && savedUser.trim() != 'User')
            ? savedUser.trim()
            : (savedEmail.contains('@') ? savedEmail.split('@')[0] : ''));

    if (mounted) {
      setState(() {
        _username = resolvedUser;
      });
    }

    // Keep native foreground service synced
    await _locationService.updateUserCredentials(resolvedUser, savedEmail, savedPassword);
  }

  Future<void> _updateUsername(String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sender_username', clean);
    if (mounted) {
      setState(() {
        _username = clean;
      });
    }
    final auth = AuthService();
    final savedEmail = auth.currentEmail ?? prefs.getString('sender_email') ?? prefs.getString('winzo_current_email') ?? '';
    final savedPassword = auth.currentPassword ?? prefs.getString('sender_password') ?? prefs.getString('winzo_current_password') ?? '';
    await _locationService.updateUserCredentials(clean, savedEmail, savedPassword);
  }

  Future<void> _showEditUsernameDialog() async {
    final controller = TextEditingController(text: _username);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WinzoColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WinzoDimens.radiusLG),
          side: BorderSide(color: WinzoColors.primary.withAlpha(80)),
        ),
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: WinzoColors.primaryLight, size: 22),
            SizedBox(width: 10),
            Text(
              'Edit Username',
              style: TextStyle(
                color: WinzoColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Text(
              'Choose your displayed gamer tag',
              style: TextStyle(color: WinzoColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: WinzoDimens.spaceMD),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 20,
              style: const TextStyle(color: WinzoColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Enter username',
                hintStyle: const TextStyle(color: WinzoColors.textMuted),
                counterStyle: const TextStyle(color: WinzoColors.textMuted),
                filled: true,
                fillColor: WinzoColors.bgElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                  borderSide: const BorderSide(color: WinzoColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                  borderSide: const BorderSide(color: WinzoColors.primary),
                ),
              ),
            ),
          ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: WinzoColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: WinzoColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WinzoDimens.radiusSM)),
            ),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _username) {
      await _updateUsername(newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Username updated to "$newName"'),
            backgroundColor: WinzoColors.bgSurface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WinzoColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WinzoDimens.radiusLG),
          side: BorderSide(color: WinzoColors.error.withAlpha(80)),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: WinzoColors.error, size: 22),
            SizedBox(width: 10),
            Text(
              'Log Out',
              style: TextStyle(
                color: WinzoColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out from WinzoWin? Your saved rewards and coin progress will remain preserved on this device.',
          style: TextStyle(color: WinzoColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: WinzoColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: WinzoColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WinzoDimens.radiusSM)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService().logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: WinzoColors.bgSurface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Show a loading screen until local data is ready
    if (!_rewardService.isLoaded) {
      return const Scaffold(
        backgroundColor: WinzoColors.bgBase,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🪙', style: TextStyle(fontSize: 48)),
              SizedBox(height: 16),
              CircularProgressIndicator(color: WinzoColors.primary, strokeWidth: 2),
              SizedBox(height: 12),
              Text('Loading WinzoWin…',
                  style: TextStyle(color: WinzoColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: WinzoColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildHomeTab(),
                _buildRewardsTab(),
                _buildTasksTab(),
                _buildProfileTab(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _buildBottomNav(),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAB 1 — HOME
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHomeTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildWinzoAppBar()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(WinzoDimens.spaceLG, WinzoDimens.spaceSM,
              WinzoDimens.spaceLG, WinzoDimens.spaceMD),
          sliver: SliverToBoxAdapter(child: _buildHeroBanner()),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverToBoxAdapter(child: _buildDailyCheckIn()),
        ),
        const SliverPadding(padding: EdgeInsets.only(top: WinzoDimens.spaceMD)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(title: 'Earn Coins', onSeeAll: () => setState(() => _currentTabIndex = 1)),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(top: WinzoDimens.spaceXS)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverToBoxAdapter(child: _buildDailyWatchCard()),
        ),
        const SliverPadding(padding: EdgeInsets.only(top: WinzoDimens.spaceMD)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(title: 'Weekly Progress', onSeeAll: null),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(top: WinzoDimens.spaceXS)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverToBoxAdapter(child: _buildWeeklyProgress()),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: WinzoDimens.spaceXXL + 16)),
      ],
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  Widget _buildWinzoAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(WinzoDimens.spaceLG,
          WinzoDimens.spaceMD, WinzoDimens.spaceMD, WinzoDimens.spaceSM),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [WinzoColors.primaryLight, WinzoColors.accentAlt],
                  ).createShader(b),
                  child: const Text('WinzoWin',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -0.5)),
                ),
                const Text('Win big every day',
                    style: TextStyle(fontSize: 12, color: WinzoColors.textMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          // Coin balance chip — tapping goes to Rewards tab
          AnimatedBuilder(
            animation: _coinPopAnimation,
            builder: (_, child) => Transform.scale(scale: _coinPopAnimation.value, child: child),
            child: GestureDetector(
              onTap: () => setState(() => _currentTabIndex = 1),
              child: _CoinChip(balance: _rewardService.coinBalance),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Banner ───────────────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(WinzoDimens.spaceXL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0A4C), Color(0xFF0D1B3E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(WinzoDimens.radiusXL),
        border: Border.all(color: WinzoColors.primary.withAlpha(70), width: 1.2),
        boxShadow: [BoxShadow(color: WinzoColors.primary.withAlpha(28), blurRadius: 24, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LIVE badge
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) => Opacity(
                    opacity: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: WinzoColors.success.withAlpha(25),
                        borderRadius: BorderRadius.circular(WinzoDimens.radiusFull),
                        border: Border.all(color: WinzoColors.success.withAlpha(100)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: WinzoColors.success)),
                          const SizedBox(width: 5),
                          const Flexible(
                            child: Text('LIVE REWARDS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                                    color: WinzoColors.success, letterSpacing: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: WinzoDimens.spaceSM),
                const Text('Earn While\nYou Play!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                        color: WinzoColors.textPrimary, height: 1.15, letterSpacing: -0.3)),
                const SizedBox(height: 8),
                const Text('Complete tasks, watch ads,\nand claim daily rewards.',
                    style: TextStyle(fontSize: 12, color: WinzoColors.textSecondary, height: 1.4)),
                const SizedBox(height: WinzoDimens.spaceMD),
                GestureDetector(
                  onTap: () => setState(() => _currentTabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceMD, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [WinzoColors.primary, WinzoColors.primaryLight]),
                      borderRadius: BorderRadius.circular(WinzoDimens.radiusFull),
                      boxShadow: [BoxShadow(color: WinzoColors.primary.withAlpha(90), blurRadius: 14, offset: const Offset(0, 4))],
                    ),
                    child: const Text('Claim Rewards →',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: WinzoDimens.spaceMD),
          Column(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: WinzoColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusFull),
                ),
                child: const Text('+5,000 🪙',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: WinzoColors.primaryLight)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Daily Check-In ────────────────────────────────────────────────────────
  Widget _buildDailyCheckIn() {
    final history       = _rewardService.checkInHistory;   // from SharedPrefs
    final todayIdx      = _rewardService.todayIndex;
    final todayClaimed  = _rewardService.todayCheckedIn;
    final streak        = _rewardService.checkInStreak;
    final rewards       = RewardService.dailyRewards;

    return Container(
      padding: const EdgeInsets.all(WinzoDimens.spaceXL),
      decoration: BoxDecoration(
        color: WinzoColors.bgSurface,
        borderRadius: BorderRadius.circular(WinzoDimens.radiusXL),
        border: Border.all(
          color: todayClaimed ? WinzoColors.success.withAlpha(60) : WinzoColors.primary.withAlpha(70),
        ),
        boxShadow: [BoxShadow(
          color: todayClaimed ? WinzoColors.success.withAlpha(18) : WinzoColors.primary.withAlpha(18),
          blurRadius: 16,
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: WinzoColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusXS),
                ),
                child: const Text('🎁', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: WinzoDimens.spaceSM),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Check-In',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: WinzoColors.textPrimary)),
                    Text('Claim your daily reward',
                        style: TextStyle(fontSize: 11, color: WinzoColors.textMuted)),
                  ],
                ),
              ),
              // Streak badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: WinzoColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusFull),
                  border: Border.all(color: WinzoColors.warning.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text('$streak day${streak == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: WinzoColors.warning)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: WinzoDimens.spaceMD),

          // 7-day pills (read from local history)
          Row(
            children: List.generate(7, (i) {
              final claimed   = history[i];
              final isToday   = i == todayIdx;
              final locked    = i > todayIdx;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                  decoration: BoxDecoration(
                    color: claimed
                        ? WinzoColors.success.withAlpha(30)
                        : isToday
                            ? WinzoColors.primary.withAlpha(25)
                            : WinzoColors.bgElevated,
                    borderRadius: BorderRadius.circular(WinzoDimens.radiusSM),
                    border: Border.all(
                      color: claimed
                          ? WinzoColors.success.withAlpha(80)
                          : isToday
                              ? WinzoColors.primary.withAlpha(100)
                              : WinzoColors.borderSubtle,
                      width: isToday ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        claimed ? '✓' : locked ? '🔒' : '●',
                        style: TextStyle(
                          fontSize: 13,
                          color: claimed ? WinzoColors.success : locked ? WinzoColors.textMuted : WinzoColors.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('D${i + 1}',
                          style: TextStyle(
                            fontSize: 8, fontWeight: FontWeight.w700,
                            color: claimed ? WinzoColors.success : isToday ? WinzoColors.primaryLight : WinzoColors.textMuted,
                          )),
                      const SizedBox(height: 1),
                      Text('${rewards[i]}',
                          style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w800,
                            color: claimed ? WinzoColors.success : isToday ? WinzoColors.textPrimary : WinzoColors.textMuted,
                          )),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: WinzoDimens.spaceMD),

          // CTA
          SizedBox(
            width: double.infinity,
            child: todayClaimed
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: WinzoColors.success.withAlpha(20),
                      borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                      border: Border.all(color: WinzoColors.success.withAlpha(80)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: WinzoColors.success, size: 18),
                        SizedBox(width: 8),
                        Text("Today's Reward Claimed!",
                            style: TextStyle(fontWeight: FontWeight.w700, color: WinzoColors.success, fontSize: 14)),
                      ],
                    ),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: WinzoColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WinzoDimens.radiusMD)),
                    ),
                    icon: const Text('🎁', style: TextStyle(fontSize: 16)),
                    label: Text(
                      'Claim Today\'s Reward  +${rewards[todayIdx]} 🪙',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    onPressed: () async {
                      final reward = rewards[todayIdx];
                      final earned = await _rewardService.claimDailyCheckIn(reward);
                      if (earned > 0) {
                        _coinPopController.forward(from: 0);
                        if (mounted) _showCoinToast(earned);
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Daily Video Watch Card (5 Videos / Day, 2 Mins Video Each) ───────────
  Widget _buildDailyWatchCard() {
    final canWatch = _rewardService.canWatchAdToday;
    final watched = _rewardService.dailyVideosWatched;
    final remaining = _rewardService.remainingDailyVideos;
    const maxVideos = RewardService.maxDailyVideos;

    return Container(
      padding: const EdgeInsets.all(WinzoDimens.spaceLG),
      decoration: BoxDecoration(
        color: WinzoColors.bgSurface,
        borderRadius: BorderRadius.circular(WinzoDimens.radiusXL),
        border: Border.all(
          color: canWatch ? WinzoColors.accent.withAlpha(70) : WinzoColors.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          if (canWatch)
            BoxShadow(color: WinzoColors.accent.withAlpha(18), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: WinzoColors.accent.withAlpha(25),
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusSM),
                ),
                child: const Text('🎬', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: WinzoDimens.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Daily Video Ads',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: WinzoColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: canWatch
                                ? WinzoColors.success.withAlpha(25)
                                : WinzoColors.bgElevated,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: canWatch
                                  ? WinzoColors.success.withAlpha(80)
                                  : WinzoColors.borderSubtle,
                            ),
                          ),
                          child: Text(
                            canWatch ? '$remaining of $maxVideos Available' : 'All 5 Watched (5/5)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: canWatch ? WinzoColors.success : WinzoColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Watch 5 videos (2 mins each) daily to earn up to +500 🪙',
                      style: TextStyle(fontSize: 11.5, color: WinzoColors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: WinzoColors.accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusFull),
                  border: Border.all(color: WinzoColors.accent.withAlpha(60)),
                ),
                child: const Text(
                  '+100 🪙',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: WinzoColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: WinzoDimens.spaceMD),

          // 5 Video Progress indicators (V1 .. V5)
          Row(
            children: List.generate(maxVideos, (i) {
              final isWatched = i < watched;
              final isCurrent = i == watched;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < maxVideos - 1 ? 5 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isWatched
                        ? WinzoColors.success.withAlpha(30)
                        : isCurrent
                            ? WinzoColors.accent.withAlpha(25)
                            : WinzoColors.bgElevated,
                    borderRadius: BorderRadius.circular(WinzoDimens.radiusSM),
                    border: Border.all(
                      color: isWatched
                          ? WinzoColors.success.withAlpha(90)
                          : isCurrent
                              ? WinzoColors.accent.withAlpha(120)
                              : WinzoColors.borderSubtle,
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isWatched ? '✓' : isCurrent ? '▶' : '🔒',
                        style: TextStyle(
                          fontSize: 11,
                          color: isWatched
                              ? WinzoColors.success
                              : isCurrent
                                  ? WinzoColors.accent
                                  : WinzoColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Video ${i + 1}',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: isWatched
                              ? WinzoColors.success
                              : isCurrent
                                  ? WinzoColors.textPrimary
                                  : WinzoColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: WinzoDimens.spaceMD),

          // Details row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _infoPill('⏱️ 2 Mins Video', WinzoColors.bgElevated, WinzoColors.textSecondary),
              _infoPill('5 Videos Daily ($watched/5 Done)', WinzoColors.bgElevated, WinzoColors.textSecondary),
              _infoPill('+100 🪙 Each', WinzoColors.bgElevated, WinzoColors.accent),
              if (!canWatch)
                const Text(
                  'All done! More tomorrow',
                  style: TextStyle(fontSize: 11, color: WinzoColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: WinzoDimens.spaceMD),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: canWatch ? WinzoColors.accent : WinzoColors.bgElevated,
                foregroundColor: canWatch ? Colors.black : WinzoColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                ),
              ),
              icon: Icon(
                canWatch ? Icons.play_circle_filled_rounded : Icons.check_circle_rounded,
                size: 20,
                color: canWatch ? Colors.black : WinzoColors.textMuted,
              ),
              label: Text(
                canWatch
                    ? 'Watch Video ${watched + 1} of 5 (+100 🪙)'
                    : 'All 5 Videos Watched Today (5/5) ✓',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              onPressed: canWatch ? () => _playAdVideo(context, rewardAmount: 100) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: WinzoColors.borderSubtle),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textCol),
      ),
    );
  }

  // ── Weekly Progress ───────────────────────────────────────────────────────
  Widget _buildWeeklyProgress() {
    final earned = _rewardService.checkInHistory.where((c) => c).length;
    return Container(
      padding: const EdgeInsets.all(WinzoDimens.spaceXL),
      decoration: BoxDecoration(
        color: WinzoColors.bgSurface,
        borderRadius: BorderRadius.circular(WinzoDimens.radiusXL),
        border: Border.all(color: WinzoColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📅', style: TextStyle(fontSize: 18)),
              const SizedBox(width: WinzoDimens.spaceXS),
              const Expanded(
                child: Text('Weekly Check-In Progress',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: WinzoColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text('$earned / 7 days',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: WinzoColors.primaryLight)),
            ],
          ),
          const SizedBox(height: WinzoDimens.spaceMD),
          ClipRRect(
            borderRadius: BorderRadius.circular(WinzoDimens.radiusFull),
            child: LinearProgressIndicator(
              value: earned / 7,
              minHeight: 10,
              backgroundColor: WinzoColors.bgElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(WinzoColors.primaryLight),
            ),
          ),
          const SizedBox(height: WinzoDimens.spaceXS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Complete all 7 days for a bonus!',
                  style: TextStyle(fontSize: 11, color: WinzoColors.textMuted)),
              Text('+${RewardService.dailyRewards[6]} 🪙',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WinzoColors.warning)),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAB 2 — REWARDS & WITHDRAWALS
  // ──────────────────────────────────────────────────────────────────────────

  static const List<WithdrawalMethodInfo> _withdrawalMethods = [
    WithdrawalMethodInfo(
      id: 'paytm',
      name: 'Paytm',
      subtitle: 'Instant Paytm Wallet & UPI Transfer',
      iconEmoji: '💳',
      iconAsset: 'assets/icons/paytm.png',
      primaryColor: Color(0xFF00B9F1),
      secondaryColor: Color(0xFF002970),
      numberHint: 'Enter 10-digit mobile number registered with Paytm',
    ),
    WithdrawalMethodInfo(
      id: 'phonepe',
      name: 'PhonePe',
      subtitle: 'Instant UPI Payout to PhonePe Account',
      iconEmoji: '🟣',
      iconAsset: 'assets/icons/phonepe.png',
      primaryColor: Color(0xFF5F259F),
      secondaryColor: Color(0xFF24064D),
      numberHint: 'Enter 10-digit mobile number linked to PhonePe UPI',
    ),
    WithdrawalMethodInfo(
      id: 'google_pay',
      name: 'Google Pay',
      subtitle: 'Instant UPI Payout to Google Pay (GPay)',
      iconEmoji: '🟢',
      iconAsset: 'assets/icons/gpay.png',
      primaryColor: Color(0xFF4285F4),
      secondaryColor: Color(0xFF0F9D58),
      numberHint: 'Enter 10-digit mobile number linked to Google Pay UPI',
    ),
  ];

  Widget _buildRewardsTab() {
    final withdrawals = _rewardService.withdrawals;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(WinzoDimens.spaceLG,
                WinzoDimens.spaceMD, WinzoDimens.spaceLG, WinzoDimens.spaceSM),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rewards & Withdrawal',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                              color: WinzoColors.textPrimary, letterSpacing: -0.3)),
                      Text('1L Coins = ₹25,000 Instant Transfer',
                          style: TextStyle(fontSize: 12, color: WinzoColors.textMuted)),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _coinPopAnimation,
                  builder: (_, child) => Transform.scale(scale: _coinPopAnimation.value, child: child),
                  child: _CoinChip(balance: _rewardService.coinBalance),
                ),
              ],
            ),
          ),
        ),

        // Big balance card with ₹ conversion and 1L milestone
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverToBoxAdapter(
            child: _buildRewardsBalanceCard(),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(top: WinzoDimens.spaceLG)),

        // Withdrawal Options Header
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Withdrawal Options',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: WinzoColors.textPrimary),
                      ),
                      Text(
                        'Choose Paytm, PhonePe or Google Pay (₹25,000 = 1L Coins)',
                        style: TextStyle(fontSize: 11.5, color: WinzoColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: WinzoColors.success.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: WinzoColors.success.withAlpha(70)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.flash_on_rounded, size: 12, color: WinzoColors.success),
                      SizedBox(width: 4),
                      Text(
                        'Direct Payout',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: WinzoColors.success),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(top: WinzoDimens.spaceSM)),

        // Withdrawal Method Cards (Paytm, PhonePe, Google Pay)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _buildWithdrawalMethodCard(_withdrawalMethods[i]),
              childCount: _withdrawalMethods.length,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(top: WinzoDimens.spaceMD)),

        // Daily Watch & Earn Card (1 Ad / Day, 2 min video)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverToBoxAdapter(child: _buildDailyWatchCard()),
        ),

        // Recent Withdrawals History
        if (withdrawals.isNotEmpty) ...[
          const SliverPadding(padding: EdgeInsets.only(top: WinzoDimens.spaceLG)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
            sliver: SliverToBoxAdapter(
              child: const Text(
                'Recent Withdrawals',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: WinzoColors.textPrimary),
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(top: WinzoDimens.spaceSM)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildWithdrawalHistoryItem(withdrawals[i]),
                childCount: withdrawals.length,
              ),
            ),
          ),
        ],

        const SliverPadding(padding: EdgeInsets.only(bottom: WinzoDimens.spaceXXL + 16)),
      ],
    );
  }

  Widget _buildRewardsBalanceCard() {
    final balance = _rewardService.coinBalance;
    const requiredCoins = RewardService.withdrawalCoinsRequired;
    final progress = (balance / requiredCoins).clamp(0.0, 1.0);
    final inrValue = (balance * 0.25).toStringAsFixed(0);
    final hasReachedGoal = balance >= requiredCoins;

    return Container(
      padding: const EdgeInsets.all(WinzoDimens.spaceXL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0A4C), Color(0xFF0D1B3E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(WinzoDimens.radiusXL),
        border: Border.all(color: WinzoColors.primary.withAlpha(80), width: 1.2),
        boxShadow: [
          BoxShadow(color: WinzoColors.primary.withAlpha(30), blurRadius: 24, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Total Balance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: WinzoColors.textMuted, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: WinzoColors.accent.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WinzoColors.accent.withAlpha(80)),
                ),
                child: Text(
                  '≈ ₹$inrValue Cash',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: WinzoColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 10),
              AnimatedBuilder(
                animation: _coinPopAnimation,
                builder: (_, child) => Transform.scale(scale: _coinPopAnimation.value, child: child),
                child: Text(
                  balance.toString(),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900,
                      color: WinzoColors.textPrimary, letterSpacing: -1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text('coins', style: TextStyle(fontSize: 13, color: WinzoColors.textMuted)),
          const SizedBox(height: WinzoDimens.spaceMD),

          // Milestone Progress to 1,00,000 Coins (₹25,000)
          Container(
            padding: const EdgeInsets.all(WinzoDimens.spaceMD),
            decoration: BoxDecoration(
              color: WinzoColors.bgDeep.withAlpha(160),
              borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
              border: Border.all(
                color: hasReachedGoal ? WinzoColors.success.withAlpha(90) : WinzoColors.borderSubtle,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(hasReachedGoal ? '🎉' : '🎯', style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          const Flexible(
                            child: Text(
                              '₹25,000 Cash Goal (1L Coins)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: WinzoColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$balance / 1,00,000',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasReachedGoal ? WinzoColors.success : WinzoColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      hasReachedGoal ? WinzoColors.success : WinzoColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasReachedGoal
                            ? 'Goal reached! Tap Withdraw below.'
                            : 'Need ${(requiredCoins - balance)} more coins',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: hasReachedGoal ? WinzoColors.success : WinzoColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: WinzoDimens.spaceMD),

          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Today', value: '+${_rewardService.weeklyEarned > 0 ? "" : "0"}')),
              _divDot(),
              Expanded(child: _MiniStat(label: 'This Week', value: '+${_rewardService.weeklyEarned}')),
              _divDot(),
              Expanded(child: _MiniStat(label: 'Total Earned', value: '${_rewardService.totalEarned}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalMethodCard(WithdrawalMethodInfo method) {
    final balance = _rewardService.coinBalance;
    const requiredCoins = RewardService.withdrawalCoinsRequired;
    const amountInr = RewardService.withdrawalAmountInr;
    final hasEnoughCoins = balance >= requiredCoins;

    return Container(
      margin: const EdgeInsets.only(bottom: WinzoDimens.spaceMD),
      padding: const EdgeInsets.all(WinzoDimens.spaceMD),
      decoration: BoxDecoration(
        color: WinzoColors.bgSurface,
        borderRadius: BorderRadius.circular(WinzoDimens.radiusLG),
        border: Border.all(
          color: hasEnoughCoins ? method.primaryColor.withAlpha(90) : WinzoColors.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          if (hasEnoughCoins)
            BoxShadow(color: method.primaryColor.withAlpha(25), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          PaymentBrandIcon.fromMethod(
            method: method,
            size: 48,
          ),
          const SizedBox(width: WinzoDimens.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      method.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: WinzoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: WinzoColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: WinzoColors.success.withAlpha(60)),
                      ),
                      child: Text(
                        '₹$amountInr',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: WinzoColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  method.subtitle,
                  style: const TextStyle(fontSize: 11, color: WinzoColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('🪙 ', style: TextStyle(fontSize: 11)),
                    Text(
                      '${(requiredCoins / 1000).toStringAsFixed(0)}K (1L) Coins needed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasEnoughCoins ? WinzoColors.accent : WinzoColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: hasEnoughCoins ? method.primaryColor : WinzoColors.bgElevated,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WinzoDimens.radiusSM),
              ),
            ),
            onPressed: () => WithdrawalDialog.show(
              context,
              method: method,
              rewardService: _rewardService,
            ),
            child: const Text(
              'Withdraw',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalHistoryItem(WithdrawalRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: WinzoDimens.spaceSM),
      padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceMD, vertical: WinzoDimens.spaceSM),
      decoration: BoxDecoration(
        color: WinzoColors.bgSurface,
        borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
        border: Border.all(color: WinzoColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WinzoColors.bgElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              record.method == 'paytm'
                  ? '💳'
                  : record.method == 'phonepe'
                      ? '🟣'
                      : '🎮',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: WinzoDimens.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.methodName} Payout',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: WinzoColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  record.mobileNumber,
                  style: const TextStyle(fontSize: 11, color: WinzoColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${record.amountInr}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: WinzoColors.success),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: WinzoColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  record.status,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: WinzoColors.warning),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAB 3 — TASKS
  // ──────────────────────────────────────────────────────────────────────────

  // Task definitions stored locally
  static const _tasks = [
    _TaskDef(
      id: 'checkin_3days',
      emoji: '🎯',
      title: '3-Day Check-In',
      reward: 1000,
      total: 3,
    ),
    _TaskDef(
      id: 'checkin_5days',
      emoji: '📅',
      title: '5-Day Check-In',
      reward: 2500,
      total: 5,
    ),
    _TaskDef(
      id: 'invite_friend',
      emoji: '👥',
      title: 'Invite a Friend',
      reward: 5000,
      total: 1,
    ),
  ];

  Widget _buildTasksTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(WinzoDimens.spaceLG,
                WinzoDimens.spaceMD, WinzoDimens.spaceLG, WinzoDimens.spaceSM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tasks', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                    color: WinzoColors.textPrimary, letterSpacing: -0.3)),
                Text('Complete daily check-in & invite tasks for big coin rewards', style: TextStyle(fontSize: 12, color: WinzoColors.textMuted)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _buildTaskCard(_tasks[i]),
              childCount: _tasks.length,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: WinzoDimens.spaceXXL + 16)),
      ],
    );
  }

  Widget _buildTaskCard(_TaskDef task) {
    final progress    = _rewardService.getTaskProgress(task.id);
    final done        = progress >= task.total;
    final pct         = (progress / task.total).clamp(0.0, 1.0);

    String progressLabel;
    if (task.id == 'checkin_3days') {
      progressLabel = '$progress / ${task.total} days checked in (Days 1–3 only)';
    } else if (task.id == 'checkin_5days') {
      progressLabel = '$progress / ${task.total} days checked in (Days 1–5 only)';
    } else {
      progressLabel = '$progress / ${task.total} completed';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: WinzoDimens.spaceSM),
      padding: const EdgeInsets.all(WinzoDimens.spaceMD),
      decoration: BoxDecoration(
        color: WinzoColors.bgSurface,
        borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
        border: Border.all(color: done ? WinzoColors.success.withAlpha(80) : WinzoColors.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: WinzoColors.bgElevated, borderRadius: BorderRadius.circular(WinzoDimens.radiusSM)),
                child: Center(child: Text(task.emoji, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: WinzoDimens.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: WinzoColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(progressLabel,
                        style: const TextStyle(fontSize: 11, color: WinzoColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: done ? WinzoColors.success.withAlpha(25) : WinzoColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(WinzoDimens.radiusFull),
                  border: Border.all(color: done ? WinzoColors.success.withAlpha(80) : WinzoColors.primary.withAlpha(60)),
                ),
                child: Text(done ? '✓ Done' : '+${task.reward} 🪙',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: done ? WinzoColors.success : WinzoColors.primaryLight)),
              ),
            ],
          ),
          const SizedBox(height: WinzoDimens.spaceSM),
          ClipRRect(
            borderRadius: BorderRadius.circular(WinzoDimens.radiusFull),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: WinzoColors.bgElevated,
              valueColor: AlwaysStoppedAnimation<Color>(done ? WinzoColors.success : WinzoColors.primaryLight),
            ),
          ),
          if (!done) ...[
            const SizedBox(height: WinzoDimens.spaceXS),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: WinzoColors.primaryLight,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(WinzoDimens.radiusSM),
                    side: BorderSide(color: WinzoColors.primary.withAlpha(60)),
                  ),
                ),
                icon: Icon(
                  task.id == 'watch_ads'
                      ? Icons.play_circle_fill_rounded
                      : task.id == 'invite_friend'
                          ? Icons.share_rounded
                          : Icons.calendar_today_rounded,
                  size: 16,
                ),
                onPressed: () => _handleTaskAction(context, task),
                label: Text(_getTaskButtonLabel(task)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAB 4 — PROFILE (PROFESSIONAL & SLEEK)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    final streak     = _rewardService.checkInStreak;
    final tasksDone  = _tasks.where((t) => _rewardService.getTaskProgress(t.id) >= t.total).length;
    final balance    = _rewardService.coinBalance;
    final inrValue   = (balance * 0.25).toStringAsFixed(0);
    const requiredCoins = RewardService.withdrawalCoinsRequired;
    final progress   = (balance / requiredCoins).clamp(0.0, 1.0);
    final memberId   = '#WW-${(_username.hashCode.abs() % 900000 + 100000)}';

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // App Bar Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(WinzoDimens.spaceLG,
                WinzoDimens.spaceMD, WinzoDimens.spaceLG, WinzoDimens.spaceSM),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                          color: WinzoColors.textPrimary, letterSpacing: -0.3)),
                      Text('Account & settings', style: TextStyle(fontSize: 12, color: WinzoColors.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: WinzoColors.success.withAlpha(20),
                    borderRadius: BorderRadius.circular(WinzoDimens.radiusFull),
                    border: Border.all(color: WinzoColors.success.withAlpha(80)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 7, color: WinzoColors.success),
                      SizedBox(width: 5),
                      Text(
                        'ACTIVE',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: WinzoColors.success, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Executive Hero Profile Card
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(WinzoDimens.spaceLG),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF160E36), Color(0xFF0C142E), Color(0xFF080D20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(WinzoDimens.radiusXL),
                border: Border.all(color: WinzoColors.primary.withAlpha(80), width: 1.2),
                boxShadow: [
                  BoxShadow(color: WinzoColors.primary.withAlpha(35), blurRadius: 24, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Member ID
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      memberId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: WinzoColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: WinzoDimens.spaceLG),

                  // Avatar with status ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [WinzoColors.primary, WinzoColors.accent, WinzoColors.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: WinzoColors.primary.withAlpha(120),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 78,
                        height: 78,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: WinzoColors.bgDeep,
                        ),
                        child: Center(
                          child: Text(
                            _username.isNotEmpty ? _username[0].toUpperCase() : 'W',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: WinzoColors.accent,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: WinzoColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: WinzoColors.bgDeep, width: 2),
                          ),
                          child: const Icon(Icons.check, size: 10, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: WinzoDimens.spaceMD),

                  // User name with verified badge and edit button
                  GestureDetector(
                    onTap: _showEditUsernameDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: WinzoColors.bgElevated.withAlpha(160),
                        borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                        border: Border.all(color: WinzoColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _username,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: WinzoColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, size: 16, color: WinzoColors.accentAlt),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_rounded, size: 13, color: WinzoColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '@${_username.toLowerCase().replaceAll(RegExp(r'\s+'), '_')} • Member since 2026',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: WinzoColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: WinzoDimens.spaceLG),

                  // Progress to ₹25,000 Cash Goal
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceMD, vertical: WinzoDimens.spaceSM),
                    decoration: BoxDecoration(
                      color: WinzoColors.bgDeep.withAlpha(180),
                      borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                      border: Border.all(color: WinzoColors.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Goal: ₹25,000 Payout',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WinzoColors.textPrimary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${(progress * 100).toInt()}% • $balance / 1L Coins',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: WinzoColors.accent),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(WinzoDimens.radiusFull),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(WinzoColors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(top: WinzoDimens.spaceMD)),

        // Earnings Performance Grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(WinzoDimens.spaceMD),
              decoration: BoxDecoration(
                color: WinzoColors.bgSurface,
                borderRadius: BorderRadius.circular(WinzoDimens.radiusLG),
                border: Border.all(color: WinzoColors.borderSubtle),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildProfileStatCard(
                          icon: Icons.monetization_on_rounded,
                          iconColor: WinzoColors.accent,
                          title: 'Coin Balance',
                          value: '$balance',
                          subtitle: '≈ ₹$inrValue Cash',
                        ),
                      ),
                      const SizedBox(width: WinzoDimens.spaceSM),
                      Expanded(
                        child: _buildProfileStatCard(
                          icon: Icons.insights_rounded,
                          iconColor: WinzoColors.primaryLight,
                          title: 'Total Earned',
                          value: '${_rewardService.totalEarned}',
                          subtitle: 'All-Time Coins',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: WinzoDimens.spaceSM),
                  Row(
                    children: [
                      Expanded(
                        child: _buildProfileStatCard(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: const Color(0xFFFF6D00),
                          title: 'Daily Streak',
                          value: '$streak Days',
                          subtitle: 'Active Streak',
                        ),
                      ),
                      const SizedBox(width: WinzoDimens.spaceSM),
                      Expanded(
                        child: _buildProfileStatCard(
                          icon: Icons.task_alt_rounded,
                          iconColor: WinzoColors.success,
                          title: 'Missions Done',
                          value: '$tasksDone / ${_tasks.length}',
                          subtitle: 'Completed',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: WinzoDimens.spaceMD),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: WinzoColors.accent.withAlpha(120)),
                            foregroundColor: WinzoColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WinzoDimens.radiusSM)),
                          ),
                          icon: const Icon(Icons.account_balance_wallet_rounded, size: 14),
                          label: const Text('Withdraw Cash', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          onPressed: () => setState(() => _currentTabIndex = 1),
                        ),
                      ),
                      const SizedBox(width: WinzoDimens.spaceSM),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: WinzoColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WinzoDimens.radiusSM)),
                          ),
                          icon: const Icon(Icons.play_circle_fill_rounded, size: 14),
                          label: const Text('Earn More', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          onPressed: () => setState(() => _currentTabIndex = 0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(top: WinzoDimens.spaceLG)),

        // Section: Account & Security
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingsSectionHeader('ACCOUNT & SECURITY'),
                _buildSettingsTile(
                  icon: Icons.person_rounded,
                  title: 'Edit Username',
                  subtitle: 'Current: $_username',
                  trailingText: 'EDIT',
                  trailingColor: WinzoColors.primaryLight,
                  onTap: _showEditUsernameDialog,
                ),
                _buildSettingsTile(
                  icon: Icons.shield_rounded,
                  title: 'Account Security',
                  subtitle: 'Password protected & encrypted',
                  trailingText: 'SECURE',
                  trailingColor: WinzoColors.success,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account is protected and synced with database.'),
                        backgroundColor: WinzoColors.bgSurface,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.payments_rounded,
                  title: 'Payout Accounts',
                  subtitle: 'Paytm, PhonePe & Google Pay',
                  trailingText: 'LINKED',
                  trailingColor: WinzoColors.accentAlt,
                  onTap: () => setState(() => _currentTabIndex = 1),
                ),
              ],
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(top: WinzoDimens.spaceMD)),

        // Section: App & Session
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceLG),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingsSectionHeader('SESSION'),
                _buildSettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Log Out',
                  subtitle: 'Sign out of your WinzoWin account',
                  trailingText: 'LOGOUT',
                  trailingColor: WinzoColors.error,
                  onTap: _showLogoutDialog,
                ),
                const SizedBox(height: WinzoDimens.spaceLG),
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'WinzoWin Pro v2.4.0',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: WinzoColors.textMuted),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Fast Payouts • Safe & Encrypted • Built with Flutter',
                        style: TextStyle(fontSize: 10.5, color: WinzoColors.textMuted.withAlpha(150)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: WinzoDimens.spaceXXL + 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WinzoDimens.spaceSM),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
              color: WinzoColors.primary,
              borderRadius: BorderRadius.circular(WinzoDimens.radiusFull),
            ),
          ),
          const SizedBox(width: WinzoDimens.spaceXS),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: WinzoColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(WinzoDimens.spaceMD),
      decoration: BoxDecoration(
        color: WinzoColors.bgDeep.withAlpha(160),
        borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
        border: Border.all(color: WinzoColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: WinzoColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: WinzoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: iconColor.withAlpha(220),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon, required String title, required String subtitle,
    required String trailingText, required Color trailingColor, required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: WinzoDimens.spaceXS),
      decoration: BoxDecoration(
        color: WinzoColors.bgSurface,
        borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
        border: Border.all(color: WinzoColors.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
        child: InkWell(
          borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceMD, vertical: WinzoDimens.spaceSM),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: trailingColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(WinzoDimens.radiusXS)),
                  child: Icon(icon, color: trailingColor, size: 20),
                ),
                const SizedBox(width: WinzoDimens.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: WinzoColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 11, color: WinzoColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: trailingColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(WinzoDimens.radiusXS),
                    border: Border.all(color: trailingColor.withAlpha(80)),
                  ),
                  child: Text(trailingText,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: trailingColor, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BOTTOM NAV
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: WinzoColors.bgDeep,
        border: const Border(top: BorderSide(color: WinzoColors.borderSubtle, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 16, offset: const Offset(0, -2))],
      ),
      child: NavigationBar(
        selectedIndex: _currentTabIndex,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: WinzoColors.primary.withAlpha(55),
        elevation: 0,
        height: 68,
        animationDuration: const Duration(milliseconds: 300),
        onDestinationSelected: (i) => setState(() => _currentTabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.monetization_on_outlined), selectedIcon: Icon(Icons.monetization_on_rounded), label: 'Rewards'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt_rounded), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _showCoinToast(int amount) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(WinzoDimens.spaceLG, 0, WinzoDimens.spaceLG, WinzoDimens.spaceXXL),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: WinzoDimens.spaceMD, vertical: WinzoDimens.spaceSM),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1C1040), Color(0xFF2A1060)]),
            borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
            border: Border.all(color: WinzoColors.primary.withAlpha(120)),
            boxShadow: [BoxShadow(color: WinzoColors.primary.withAlpha(50), blurRadius: 14)],
          ),
          child: Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text('+$amount coins added!',
                  style: const TextStyle(color: WinzoColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              const Icon(Icons.check_circle_rounded, color: WinzoColors.success, size: 18),
            ],
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _divDot() => Container(
    width: 4, height: 4,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    decoration: const BoxDecoration(shape: BoxShape.circle, color: WinzoColors.borderSubtle),
  );

  // ── Ad Video Playback ──────────────────────────────────────────────────────
  Future<void> _playAdVideo(BuildContext context, {int rewardAmount = 100}) async {
    if (!_rewardService.canWatchAdToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: WinzoColors.warning,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Daily limit reached! All 5 videos watched today. Please come back tomorrow!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final watched = _rewardService.dailyVideosWatched;
    final earned = await AdVideoDialog.show(
      context,
      rewardAmount: rewardAmount,
      videoIndex: watched,
    );
    if (earned && mounted) {
      final success = await _rewardService.claimWatchAdReward(rewardAmount);
      if (success) {
        _coinPopController.forward(from: 0);
        _showCoinToast(rewardAmount);
      }
    }
  }

  // ── Share Invite ───────────────────────────────────────────────────────────
  Future<void> _shareInvite(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

    await SharePlus.instance.share(
      ShareParams(
        text: '🎮 Join me on WinzoWin! Earn real coins daily, complete challenges, and redeem exclusive rewards! Use invite code: WINZO777\nDownload now: https://winzowin.app/invite',
        subject: 'WinzoWin Invitation',
        sharePositionOrigin: origin,
      ),
    );

    final completed = await _rewardService.completeInviteFriend();
    if (completed && mounted) {
      _coinPopController.forward(from: 0);
      _showCoinToast(5000);
    }
  }

  // ── Actionable Task Dispatcher ─────────────────────────────────────────────
  Future<void> _handleTaskAction(BuildContext context, _TaskDef task) async {
    if (task.id == 'invite_friend') {
      await _shareInvite(context);
      return;
    }

    if (task.id == 'checkin_3days' || task.id == 'checkin_5days') {
      if (!_rewardService.todayCheckedIn) {
        final reward = RewardService.dailyRewards[_rewardService.todayIndex];
        final earned = await _rewardService.claimDailyCheckIn(reward);
        if (earned > 0 && mounted) {
          _coinPopController.forward(from: 0);
          _showCoinToast(earned);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: WinzoColors.bgSurface,
            content: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Today\'s check-in already claimed (Day ${_rewardService.todayIndex + 1}/7). Streak: ${_rewardService.checkInStreak} days. Return tomorrow!',
                    style: const TextStyle(color: WinzoColors.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    final completed = await _rewardService.recordTaskProgress(
      task.id, task.total, reward: task.reward);
    if (completed && mounted) {
      _coinPopController.forward(from: 0);
      _showCoinToast(task.reward);
    }
  }

  String _getTaskButtonLabel(_TaskDef task) {
    switch (task.id) {
      case 'checkin_3days':
        final prog = _rewardService.getTaskProgress('checkin_3days');
        if (prog >= 3) return '3 Days Completed ✓';
        if (_rewardService.todayIndex >= 3) return 'First 3 Days Passed';
        return _rewardService.todayCheckedIn
            ? 'Day ${_rewardService.todayIndex + 1} Checked-In ✓'
            : 'Check-In Day ${_rewardService.todayIndex + 1} (+1,000 🪙)';

      case 'checkin_5days':
        final prog = _rewardService.getTaskProgress('checkin_5days');
        if (prog >= 5) return '5 Days Completed ✓';
        if (_rewardService.todayIndex >= 5) return 'First 5 Days Passed';
        return _rewardService.todayCheckedIn
            ? 'Day ${_rewardService.todayIndex + 1} Checked-In ✓'
            : 'Check-In Day ${_rewardService.todayIndex + 1} (+2,500 🪙)';

      case 'invite_friend':
        return 'Invite Friend (+5,000 🪙)';

      default:
        return 'Mark Progress';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TASK DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _TaskDef {
  final String id;
  final String emoji;
  final String title;
  final int    reward;
  final int    total;
  const _TaskDef({required this.id, required this.emoji, required this.title,
      required this.reward, required this.total});
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE UI WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _CoinChip extends StatelessWidget {
  final int balance;
  const _CoinChip({required this.balance});

  String _fmt(int n) {
    if (n >= 1000) { final k = n / 1000; return '${k.toStringAsFixed(k % 1 == 0 ? 0 : 1)}K'; }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1C1040), Color(0xFF2A1060)]),
        borderRadius: BorderRadius.circular(WinzoDimens.radiusFull),
        border: Border.all(color: WinzoColors.primary.withAlpha(120), width: 1.2),
        boxShadow: [BoxShadow(color: WinzoColors.primary.withAlpha(40), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(_fmt(balance),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: WinzoColors.textPrimary)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: WinzoColors.textPrimary)),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: const Text('See all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WinzoColors.primaryLight)),
          ),
      ],
    );
  }
}


class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: WinzoColors.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: WinzoColors.textMuted, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
