import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

class AdCreative {
  final String title;
  final String sponsor;
  final String category;
  final String emoji;
  final String videoUrl;
  final String actionLabel;

  const AdCreative({
    required this.title,
    required this.sponsor,
    required this.category,
    required this.emoji,
    required this.videoUrl,
    this.actionLabel = 'Install Now',
  });
}

const List<AdCreative> _kAdCreatives = [
  AdCreative(
    title: 'Firestorm: Bigger Blazes',
    sponsor: 'Blaze Studio Games',
    category: 'Action & Adventure',
    emoji: '🔥',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    actionLabel: 'Play Free',
  ),
  AdCreative(
    title: 'Mystery Runner: Epic Escape',
    sponsor: 'Apex Interactive',
    category: 'Arcade & Racing',
    emoji: '🏃',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    actionLabel: 'Get Game',
  ),
  AdCreative(
    title: 'Party Royale: Bigger Fun',
    sponsor: 'JoyWorks Gaming',
    category: 'Multiplayer Party',
    emoji: '🎉',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    actionLabel: 'Join Battle',
  ),
  AdCreative(
    title: 'Joy Blazes: Fantasy Realm',
    sponsor: 'Mythic Entertainment',
    category: 'Fantasy RPG',
    emoji: '⚔️',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyBlazes.mp4',
    actionLabel: 'Play Now',
  ),
  AdCreative(
    title: 'Meltdown 2099: Cyber Siege',
    sponsor: 'Orbital Strike Studios',
    category: 'Sci-Fi Strategy',
    emoji: '🚀',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
    actionLabel: 'Download',
  ),
];

/// Premium, full-featured Video Advertisement Dialog.
/// Plays a randomly chosen video ad, tracks countdown, and grants rewards upon completion.
class AdVideoDialog extends StatefulWidget {
  final int rewardAmount;
  final int? videoIndex;

  const AdVideoDialog({
    super.key,
    this.rewardAmount = 50,
    this.videoIndex,
  });

  /// Helper to launch the ad modal and return true if reward was earned.
  static Future<bool> show(BuildContext context, {int rewardAmount = 50, int? videoIndex}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdVideoDialog(rewardAmount: rewardAmount, videoIndex: videoIndex),
    );
    return result ?? false;
  }

  @override
  State<AdVideoDialog> createState() => _AdVideoDialogState();
}

class _AdVideoDialogState extends State<AdVideoDialog> with SingleTickerProviderStateMixin {
  late final AdCreative _ad;
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = false;
  bool _rewardGranted = false;

  static const int _requiredWatchSeconds = 120; // 2 minutes watch required
  int _secondsRemaining = _requiredWatchSeconds;
  int _secondsWatched = 0;
  Timer? _countdownTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    // Select creative based on video index if provided, or pick random
    if (widget.videoIndex != null) {
      _ad = _kAdCreatives[widget.videoIndex! % _kAdCreatives.length];
    } else {
      final rnd = Random();
      _ad = _kAdCreatives[rnd.nextInt(_kAdCreatives.length)];
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
    _initializeVideo();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsWatched++;
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        }
        if (_secondsRemaining == 0 && !_rewardGranted) {
          _rewardGranted = true;
        }
      });
    });
  }

  Future<void> _initializeVideo() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(_ad.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);
      await controller.play();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('[AdVideoDialog] Video failed to load: $e. Falling back to animated ad.');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _trySkip() {
    if (_rewardGranted) {
      Navigator.of(context).pop(true);
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WinzoColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Video Early?',
            style: TextStyle(fontWeight: FontWeight.bold, color: WinzoColors.textPrimary)),
        content: Text(
          'You need to watch the full 2-minute video to claim your +${widget.rewardAmount} 🪙 coins reward!\n\nRemaining: ${_formatTime(_secondsRemaining)}.',
          style: const TextStyle(color: WinzoColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // dismiss confirm
              Navigator.of(context).pop(false); // leave without reward
            },
            child: const Text('Exit (No Reward)', style: TextStyle(color: WinzoColors.error)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WinzoColors.accent),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Watching'),
          ),
        ],
      ),
    );
  }

  void _claimRewardAndExit() {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WinzoDimens.radiusXL),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: WinzoColors.bgDeep,
            borderRadius: BorderRadius.circular(WinzoDimens.radiusXL),
            border: Border.all(
              color: _rewardGranted ? WinzoColors.accent : WinzoColors.borderSubtle,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _rewardGranted ? WinzoColors.accent.withAlpha(50) : Colors.black54,
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // ── Header Bar ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: WinzoColors.bgSurface,
                  border: Border(bottom: BorderSide(color: WinzoColors.borderSubtle)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: WinzoColors.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.videoIndex != null
                            ? 'VIDEO ${(widget.videoIndex! % 5) + 1}/5'
                            : 'AD',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _ad.sponsor,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WinzoColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Countdown or Reward Badge
                    if (_rewardGranted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: WinzoColors.success.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: WinzoColors.success),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('✓', style: TextStyle(color: WinzoColors.success, fontWeight: FontWeight.bold, fontSize: 11)),
                            SizedBox(width: 4),
                            Text('Reward Ready', style: TextStyle(color: WinzoColors.success, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: WinzoColors.bgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: WinzoColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 12, color: WinzoColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              'Reward in ${_formatTime(_secondsRemaining)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: WinzoColors.accent),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 6),
                    // Sound toggle
                    if (_isInitialized)
                      GestureDetector(
                        onTap: _toggleMute,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: WinzoColors.bgElevated,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            size: 16,
                            color: WinzoColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Video Stage / Fallback ───────────────────────────────────
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isInitialized && _controller != null)
                        VideoPlayer(_controller!)
                      else if (_hasError)
                        _buildFallbackAdView()
                      else
                        _buildLoadingAdView(),

                      // Top gradient overlay
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black.withAlpha(160), Colors.transparent],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),

                      // Exit / Close button (Top Right)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: _trySkip,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(160),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withAlpha(80),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _rewardGranted ? 'Claim & Close ✕' : 'Exit ✕',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Progress bar at the bottom of the video
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: (_secondsWatched / _requiredWatchSeconds).clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _rewardGranted ? WinzoColors.success : WinzoColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Sponsor Info & CTA ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(WinzoDimens.spaceMD),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [WinzoColors.primary, WinzoColors.accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: WinzoColors.primary.withAlpha(80),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(_ad.emoji, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ad.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: WinzoColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_ad.category} • Free to Play',
                                style: const TextStyle(fontSize: 11, color: WinzoColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: WinzoColors.accent.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: WinzoColors.accent.withAlpha(60)),
                          ),
                          child: Text(
                            '+${widget.rewardAmount} 🪙',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: WinzoColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: WinzoDimens.spaceMD),

                    // Main Action / Claim Button
                    if (_rewardGranted)
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: WinzoColors.accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.black),
                            label: Text(
                              'Claim +${widget.rewardAmount} Coins 🎉',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                            onPressed: _claimRewardAndExit,
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: WinzoColors.borderSubtle),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                                ),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Opening ${_ad.title}...'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Text(
                                _ad.actionLabel,
                                style: const TextStyle(color: WinzoColors.textPrimary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: WinzoColors.bgElevated,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(WinzoDimens.radiusMD),
                                ),
                              ),
                              onPressed: null,
                              child: Text(
                                'Reward in ${_formatTime(_secondsRemaining)}',
                                style: const TextStyle(
                                  color: WinzoColors.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
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
);
}

  Widget _buildLoadingAdView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: WinzoColors.accent),
        ),
        const SizedBox(height: 12),
        Text(
          'Streaming ${_ad.title}...',
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildFallbackAdView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF160830), Color(0xFF0F1E4A), Color(0xFF04102A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_ad.emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 6),
          Text(
            _ad.title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Interactive Sponsored Demo',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
