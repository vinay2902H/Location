import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/reward_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOnline = true;
  Timer? _networkCheckTimer;

  @override
  void initState() {
    super.initState();
    _checkNetwork();
    _networkCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkNetwork());
  }

  Future<void> _checkNetwork() async {
    final online = await ApiService.checkHealth();
    if (mounted && online != _isOnline) setState(() => _isOnline = online);
  }

  @override
  void dispose() {
    _networkCheckTimer?.cancel();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final input = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final rawUsername = _usernameController.text.trim();
    final cleanUsername = rawUsername.isNotEmpty
        ? rawUsername
        : (input.contains('@') ? input.split('@')[0] : input);

    if (_isSignUp && password.isNotEmpty) {
      final confirmPassword = _confirmPasswordController.text.trim();
      if (password != confirmPassword) {
        setState(() => _errorMessage = 'Passwords do not match');
        return;
      }
    }

    setState(() => _isLoading = true);

    final authService = AuthService();
    AuthResult result;

    if (password.isEmpty || (!input.contains('@') && !_isSignUp)) {
      // Instant offline-capable username entry
      result = await authService.loginWithUsername(cleanUsername);
    } else if (_isSignUp) {
      result = await authService.register(input, password.isNotEmpty ? password : 'nopassword', username: cleanUsername);
    } else {
      result = await authService.login(input, password);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      setState(() => _errorMessage = result.errorMessage ?? 'Authentication failed');
    } else {
      final displayName = authService.currentUsername ?? cleanUsername;
      final effectiveEmail = authService.currentEmail ?? '$displayName@winzo.app';
      final effectivePassword = authService.currentPassword ?? (password.isNotEmpty ? password : 'nopassword');

      // Initialize RewardService scoped to this user so new logins start at Day 1
      await RewardService().loadForUser(displayName);

      // Sync credentials to native Android background foreground service
      await LocationService().updateUserCredentials(
        displayName,
        effectiveEmail,
        effectivePassword,
      );
      await LocationService().checkAndAutoStart();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, $displayName! You are all set.'),
          backgroundColor: WinzoColors.bgSurface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WinzoColors.bgBase,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: WinzoDimens.spaceLG,
                vertical: WinzoDimens.spaceXL,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  // App Brand Logo & Icon
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [WinzoColors.primary, WinzoColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: WinzoColors.primary.withAlpha(140),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.sports_esports_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: WinzoDimens.spaceMD),

                  // Brand Title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [WinzoColors.primaryLight, WinzoColors.accent, WinzoColors.accentAlt],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'WINZOWIN',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Play, Share & Earn Real Cash Rewards',
                    style: TextStyle(
                      fontSize: 13,
                      color: WinzoColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: WinzoDimens.spaceXL),

                  // Segmented Mode Switcher (Sign In vs Create Account)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: WinzoColors.bgSurface,
                      borderRadius: BorderRadius.circular(WinzoDimens.radiusLG),
                      border: Border.all(color: WinzoColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_isSignUp) {
                                setState(() {
                                  _isSignUp = false;
                                  _errorMessage = null;
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isSignUp ? WinzoColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                              ),
                              child: Center(
                                child: Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: !_isSignUp ? Colors.white : WinzoColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!_isSignUp) {
                                setState(() {
                                  _isSignUp = true;
                                  _errorMessage = null;
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isSignUp ? WinzoColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                              ),
                              child: Center(
                                child: Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _isSignUp ? Colors.white : WinzoColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: WinzoDimens.spaceLG),

                  // Auth Card Container
                  Container(
                    padding: const EdgeInsets.all(WinzoDimens.spaceXL),
                    decoration: BoxDecoration(
                      color: WinzoColors.bgSurface,
                      borderRadius: BorderRadius.circular(WinzoDimens.radiusXL),
                      border: Border.all(color: WinzoColors.borderPrimary, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(90),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isSignUp ? 'New User Registration' : 'Welcome Back',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: WinzoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isSignUp
                              ? 'Enter a username and password to create your account'
                              : 'Sign in to access your wallet, coins, and rewards',
                          style: const TextStyle(
                            fontSize: 12,
                            color: WinzoColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: WinzoDimens.spaceLG),

                        // Error Banner if present
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(WinzoDimens.spaceMD),
                            decoration: BoxDecoration(
                              color: WinzoColors.error.withAlpha(25),
                              borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                              border: Border.all(color: WinzoColors.error.withAlpha(120)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: WinzoColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: WinzoColors.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: WinzoDimens.spaceMD),
                        ],

                        // Username or Email Field
                        Text(
                          _isSignUp ? 'Sender Username' : 'Username or Email',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: WinzoColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(
                            color: WinzoColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter username (e.g. a, b, or sender1)',
                            hintStyle: const TextStyle(color: WinzoColors.textMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.person_rounded, color: WinzoColors.primaryLight, size: 20),
                            filled: true,
                            fillColor: WinzoColors.bgElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                              borderSide: const BorderSide(color: WinzoColors.borderSubtle),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                              borderSide: const BorderSide(color: WinzoColors.primary, width: 1.5),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Please enter a username or email';
                            if (val.trim().length < 2) return 'Username must be at least 2 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: WinzoDimens.spaceMD),

                        // Username Field (Sign Up mode only)
                        if (_isSignUp) ...[
                          const Text(
                            'Email Address (Optional)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: WinzoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _usernameController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              color: WinzoColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Optional email (e.g. user@gmail.com)',
                              hintStyle: const TextStyle(color: WinzoColors.textMuted, fontSize: 13),
                              prefixIcon: const Icon(Icons.email_rounded, color: WinzoColors.primaryLight, size: 20),
                              filled: true,
                              fillColor: WinzoColors.bgElevated,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                                borderSide: const BorderSide(color: WinzoColors.borderSubtle),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                                borderSide: const BorderSide(color: WinzoColors.primary, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: WinzoDimens.spaceMD),
                        ],

                        // Password Field
                        Text(
                          _isSignUp ? 'Password' : 'Password (optional for offline / quick start)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: WinzoColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            color: WinzoColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: _isSignUp ? 'Enter password (min. 4 characters)' : 'Leave empty for instant offline start',
                            hintStyle: const TextStyle(color: WinzoColors.textMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.lock_rounded, color: WinzoColors.primaryLight, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: WinzoColors.textMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: WinzoColors.bgElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                              borderSide: const BorderSide(color: WinzoColors.borderSubtle),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                              borderSide: const BorderSide(color: WinzoColors.primary, width: 1.5),
                            ),
                          ),
                          validator: (val) {
                            if (_isSignUp && val != null && val.isNotEmpty && val.length < 4) {
                              return 'Password must be at least 4 characters';
                            }
                            return null;
                          },
                        ),

                        // Confirm Password Field (Sign Up mode only)
                        if (_isSignUp) ...[
                          const SizedBox(height: WinzoDimens.spaceMD),
                          const Text(
                            'Confirm Password',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: WinzoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: const TextStyle(
                              color: WinzoColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Re-enter your password',
                              hintStyle: const TextStyle(color: WinzoColors.textMuted, fontSize: 13),
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: WinzoColors.accent, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: WinzoColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                              filled: true,
                              fillColor: WinzoColors.bgElevated,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                                borderSide: const BorderSide(color: WinzoColors.borderSubtle),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                                borderSide: const BorderSide(color: WinzoColors.accent, width: 1.5),
                              ),
                            ),
                            validator: (val) {
                              if (_isSignUp) {
                                if (val == null || val.isEmpty) return 'Please confirm your password';
                                if (val != _passwordController.text) return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],

                        const SizedBox(height: WinzoDimens.spaceXL),

                        // Action Button
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [WinzoColors.primary, WinzoColors.accent],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                            boxShadow: [
                              BoxShadow(
                                color: WinzoColors.primary.withAlpha(100),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                              onTap: _isLoading ? null : _submit,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _isSignUp ? Icons.person_add_rounded : Icons.login_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _isSignUp ? 'Create Account' : 'Enter App',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Network status notice
                        if (!_isOnline)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B0000),
                              borderRadius: BorderRadius.circular(WinzoDimens.radiusSM),
                              border: Border.all(color: WinzoColors.error.withAlpha(120)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.wifi_off_rounded, color: WinzoColors.error, size: 22),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'No Internet Connection',
                                        style: TextStyle(color: WinzoColors.error, fontSize: 13, fontWeight: FontWeight.w800),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Please turn on Wi-Fi or mobile data to continue.',
                                        style: TextStyle(color: WinzoColors.textMuted, fontSize: 11.5, height: 1.35),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: WinzoColors.bgElevated,
                              borderRadius: BorderRadius.circular(WinzoDimens.radiusSM),
                              border: Border.all(color: WinzoColors.borderSubtle),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.wifi_rounded, color: WinzoColors.success, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Connected — ready to sync your progress.',
                                    style: TextStyle(color: WinzoColors.textMuted, fontSize: 11.5, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: WinzoDimens.spaceLG),

                  // Highlights Card: 1L Coins = ₹25,000 Real Cash
                  Container(
                    padding: const EdgeInsets.all(WinzoDimens.spaceMD),
                    decoration: BoxDecoration(
                      color: WinzoColors.bgSurface.withAlpha(180),
                      borderRadius: BorderRadius.circular(WinzoDimens.radiusLG),
                      border: Border.all(color: WinzoColors.accent.withAlpha(60)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: _LoginHighlight(
                            icon: Icons.monetization_on_rounded,
                            color: WinzoColors.accent,
                            title: '₹25,000 Reward',
                            subtitle: '1L Coins = ₹25k',
                          ),
                        ),
                        _LoginDivider(),
                        Expanded(
                          child: _LoginHighlight(
                            icon: Icons.ondemand_video_rounded,
                            color: WinzoColors.primaryLight,
                            title: '5 Daily Videos',
                            subtitle: 'Up to +500 🪙',
                          ),
                        ),
                        _LoginDivider(),
                        Expanded(
                          child: _LoginHighlight(
                            icon: Icons.flash_on_rounded,
                            color: WinzoColors.success,
                            title: 'Instant Payout',
                            subtitle: 'Paytm / PhonePe',
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
      ),
    ),
  );
  }
}

class _LoginHighlight extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _LoginHighlight({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: WinzoColors.textPrimary,
          ),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9.5,
            color: WinzoColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _LoginDivider extends StatelessWidget {
  const _LoginDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: WinzoColors.borderSubtle,
    );
  }
}
