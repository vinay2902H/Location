import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only reward data service.
/// All data is persisted on the device via SharedPreferences.
/// No network / remote DB is used.
class WithdrawalRecord {
  final String id;
  final String method; // 'paytm', 'phonepe', 'google_pay'
  final String methodName;
  final String mobileNumber;
  final int coins;
  final int amountInr;
  final DateTime timestamp;
  final String status; // 'Processing', 'Success'

  const WithdrawalRecord({
    required this.id,
    required this.method,
    required this.methodName,
    required this.mobileNumber,
    required this.coins,
    required this.amountInr,
    required this.timestamp,
    this.status = 'Processing',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': method,
    'methodName': methodName,
    'mobileNumber': mobileNumber,
    'coins': coins,
    'amountInr': amountInr,
    'timestamp': timestamp.toIso8601String(),
    'status': status,
  };

  factory WithdrawalRecord.fromJson(Map<String, dynamic> json) => WithdrawalRecord(
    id: json['id'] as String,
    method: json['method'] as String,
    methodName: json['methodName'] as String,
    mobileNumber: json['mobileNumber'] as String,
    coins: json['coins'] as int,
    amountInr: json['amountInr'] as int,
    timestamp: DateTime.parse(json['timestamp'] as String),
    status: json['status'] as String? ?? 'Processing',
  );
}

/// Local-only reward data service.
/// All data is persisted on the device via SharedPreferences.
/// No network / remote DB is used.
class RewardService extends ChangeNotifier {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final RewardService _instance = RewardService._internal();
  factory RewardService() => _instance;
  RewardService._internal();

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const _kCoinBalance      = 'ww_coin_balance';
  static const _kLastCheckInDate  = 'ww_last_checkin_date';   // 'yyyy-MM-dd'
  static const _kCheckInHistory   = 'ww_checkin_history';     // JSON list<bool> len=7
  static const _kCheckInStreak    = 'ww_checkin_streak';
  static const _kTaskProgress     = 'ww_task_progress';       // JSON map<id, int>
  static const _kTotalEarned      = 'ww_total_earned';
  static const _kWeeklyEarned     = 'ww_weekly_earned';
  static const _kWeekStart        = 'ww_week_start';          // 'yyyy-MM-dd' of Mon
  static const _kLastAdWatchDate  = 'ww_last_ad_watch_date';  // 'yyyy-MM-dd'
  static const _kDailyVideosWatched = 'ww_daily_videos_watched';
  static const _kWithdrawals      = 'ww_withdrawals';         // JSON list

  // ── Constants ─────────────────────────────────────────────────────────────
  static const int withdrawalCoinsRequired = 100000; // 1 Lakh (1L) coins
  static const int withdrawalAmountInr     = 25000;  // ₹25,000 (25k) INR for 1L coins
  static const int maxDailyVideos          = 5;      // 5 videos daily (4 more added)

  // ── In-memory state ───────────────────────────────────────────────────────
  int _coinBalance         = 0;
  int _checkInStreak       = 0;
  int _totalEarned         = 0;
  int _weeklyEarned        = 0;
  int _dailyVideosWatched  = 0;

  /// 7-element list; index 0 = Day 1 of the current 7-day cycle.
  /// Resets every Monday.
  List<bool> _checkInHistory = List.filled(7, false);

  /// Task progress: maps task-id → completed count
  Map<String, int> _taskProgress = {};

  List<WithdrawalRecord> _withdrawals = [];

  String? _lastCheckInDate;
  String? _lastAdWatchDate;
  bool    _isLoaded = false;

  // ── Public getters ────────────────────────────────────────────────────────
  int                     get coinBalance         => _coinBalance;
  int                     get checkInStreak       => _checkInStreak;
  int                     get totalEarned         => _totalEarned;
  int                     get weeklyEarned        => _weeklyEarned;
  int                     get dailyVideosWatched  => _dailyVideosWatched;
  int                     get remainingDailyVideos => (maxDailyVideos - _dailyVideosWatched).clamp(0, maxDailyVideos);
  int                     get maxDailyVideosCount => maxDailyVideos;
  List<bool>              get checkInHistory      => List.unmodifiable(_checkInHistory);
  List<WithdrawalRecord>  get withdrawals         => List.unmodifiable(_withdrawals);
  bool                    get isLoaded            => _isLoaded;
  String?                 get lastAdWatchDate     => _lastAdWatchDate;

  /// Returns true if today has already been claimed for daily check-in.
  bool get todayCheckedIn {
    final today = _dateKey(DateTime.now());
    return _lastCheckInDate == today;
  }

  /// Returns true if user can watch more daily videos today (up to 5 videos).
  bool get canWatchAdToday {
    return _dailyVideosWatched < maxDailyVideos;
  }

  /// Index within the 7-day cycle for today (0–6).
  int get todayIndex {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return now.difference(DateTime(monday.year, monday.month, monday.day)).inDays.clamp(0, 6);
  }

  int getTaskProgress(String taskId) {
    if (taskId == 'checkin_3days') {
      return _checkInHistory.take(3).where((c) => c).length;
    }
    if (taskId == 'checkin_5days') {
      return _checkInHistory.take(5).where((c) => c).length;
    }
    return _taskProgress[taskId] ?? 0;
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // ── Roll over weekly data if a new Monday has started ───────────────────
    final weekStart = prefs.getString(_kWeekStart);
    final thisMonday = _thisMonday();
    if (weekStart != thisMonday) {
      // New week — reset check-in history and weekly earnings, keep balance
      _checkInHistory = List.filled(7, false);
      _weeklyEarned   = 0;
      await prefs.setString(_kWeekStart, thisMonday);
      await prefs.setString(_kCheckInHistory, jsonEncode(_checkInHistory));
      await prefs.setInt(_kWeeklyEarned, 0);
      _taskProgress.remove('checkin_3days');
      _taskProgress.remove('checkin_5days');
      await prefs.setString(_kTaskProgress, jsonEncode(_taskProgress));
    } else {
      // Restore saved history
      final raw = prefs.getString(_kCheckInHistory);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        _checkInHistory = decoded.map((e) => e as bool).toList();
        if (_checkInHistory.length != 7) _checkInHistory = List.filled(7, false);
      }
      _weeklyEarned = prefs.getInt(_kWeeklyEarned) ?? 0;
    }

    _coinBalance      = prefs.getInt(_kCoinBalance)     ?? 0;
    _checkInStreak    = prefs.getInt(_kCheckInStreak)   ?? 0;
    _totalEarned      = prefs.getInt(_kTotalEarned)     ?? 0;
    _lastCheckInDate  = prefs.getString(_kLastCheckInDate);
    final todayKey    = _dateKey(DateTime.now());
    _lastAdWatchDate  = prefs.getString(_kLastAdWatchDate);
    if (_lastAdWatchDate == todayKey) {
      _dailyVideosWatched = prefs.getInt(_kDailyVideosWatched) ?? 0;
    } else {
      _dailyVideosWatched = 0;
    }

    final taskRaw = prefs.getString(_kTaskProgress);
    if (taskRaw != null) {
      final decoded = jsonDecode(taskRaw) as Map<String, dynamic>;
      _taskProgress   = decoded.map((k, v) => MapEntry(k, v as int));
    }

    // Keep task progress in sync with checkin history
    final first3 = _checkInHistory.take(3).where((c) => c).length;
    if ((_taskProgress['checkin_3days'] ?? 0) < first3) {
      _taskProgress['checkin_3days'] = first3;
    }
    final first5 = _checkInHistory.take(5).where((c) => c).length;
    if ((_taskProgress['checkin_5days'] ?? 0) < first5) {
      _taskProgress['checkin_5days'] = first5;
    }

    final withRaw = prefs.getString(_kWithdrawals);
    if (withRaw != null) {
      try {
        final decoded = jsonDecode(withRaw) as List;
        _withdrawals = decoded
            .map((e) => WithdrawalRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('[RewardService] Error loading withdrawals: $e');
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  // ── Coin operations ───────────────────────────────────────────────────────
  Future<void> addCoins(int amount, {String reason = 'earn'}) async {
    _coinBalance  += amount;
    _totalEarned  += amount;
    _weeklyEarned += amount;
    await _persist();
    notifyListeners();
  }

  // ── Daily check-in ────────────────────────────────────────────────────────
  /// Claim the check-in for today.
  /// Returns the coin reward, or 0 if already claimed.
  Future<int> claimDailyCheckIn(int reward) async {
    if (todayCheckedIn) return 0;

    final idx = todayIndex;
    _checkInHistory[idx] = true;
    _lastCheckInDate      = _dateKey(DateTime.now());

    // Update streak
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    if (_lastCheckInDate == _dateKey(DateTime.now()) &&
        (_checkInStreak == 0 || _wasCheckedInOnDate(yesterday))) {
      _checkInStreak++;
    } else if (!_wasCheckedInOnDate(yesterday)) {
      _checkInStreak = 1;
    }

    await addCoins(reward, reason: 'daily_checkin');

    // ── First 3 & 5 Days Check-In Tasks Proper Logic ──
    // Only check-ins during the first 3 days (indices 0, 1, 2) count towards the 3-day task (1,000 coins)
    final first3DaysCount = _checkInHistory.take(3).where((c) => c).length;
    await setTaskProgress('checkin_3days', first3DaysCount, 3, reward: 1000);

    // Only check-ins during the first 5 days (indices 0, 1, 2, 3, 4) count towards the 5-day task (2,500 coins)
    final first5DaysCount = _checkInHistory.take(5).where((c) => c).length;
    await setTaskProgress('checkin_5days', first5DaysCount, 5, reward: 2500);

    await _persistCheckIn();
    return reward;
  }

  /// Returns true if the user had a check-in on the given date string.
  bool _wasCheckedInOnDate(String dateKey) {
    return _lastCheckInDate == dateKey;
  }

  // ── Task progress ─────────────────────────────────────────────────────────
  Future<bool> recordTaskProgress(String taskId, int target,
      {int increment = 1, int reward = 0}) async {
    final current = _taskProgress[taskId] ?? 0;
    if (current >= target) return false; // already done

    final next = (current + increment).clamp(0, target);
    _taskProgress[taskId] = next;

    final justCompleted = next >= target;
    if (justCompleted && reward > 0) {
      await addCoins(reward, reason: 'task_$taskId');
    } else {
      await _persistTaskProgress();
      notifyListeners();
    }
    return justCompleted;
  }

  Future<bool> setTaskProgress(String taskId, int value, int target,
      {int reward = 0}) async {
    final current = _taskProgress[taskId] ?? 0;
    if (current >= target) return false;

    final next = value.clamp(0, target);
    _taskProgress[taskId] = next;

    final justCompleted = next >= target;
    if (justCompleted && reward > 0) {
      await addCoins(reward, reason: 'task_$taskId');
    } else {
      await _persistTaskProgress();
      notifyListeners();
    }
    return justCompleted;
  }

  // ── Watch ad reward (up to 5 videos daily limit) ──────────────────────────
  Future<bool> claimWatchAdReward(int reward) async {
    if (!canWatchAdToday) return false;
    final today = _dateKey(DateTime.now());
    _dailyVideosWatched++;
    _lastAdWatchDate = today;
    await addCoins(reward, reason: 'watch_ad');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastAdWatchDate, today);
    await prefs.setInt(_kDailyVideosWatched, _dailyVideosWatched);
    notifyListeners();
    return true;
  }

  // ── Invite friend reward (5k coins) ──────────────────────────────────────
  Future<bool> completeInviteFriend() async {
    return await recordTaskProgress('invite_friend', 1, increment: 1, reward: 5000);
  }

  // ── Withdrawal (1,00,000 coins = ₹1,000) ──────────────────────────────────
  Future<bool> withdraw({
    required String method,
    required String methodName,
    required String mobileNumber,
    int coins = withdrawalCoinsRequired,
    int amountInr = withdrawalAmountInr,
  }) async {
    if (_coinBalance < coins) return false;

    _coinBalance -= coins;
    final record = WithdrawalRecord(
      id: 'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}',
      method: method,
      methodName: methodName,
      mobileNumber: mobileNumber,
      coins: coins,
      amountInr: amountInr,
      timestamp: DateTime.now(),
      status: 'Processing',
    );
    _withdrawals.insert(0, record);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCoinBalance, _coinBalance);
    await _persistWithdrawals(prefs: prefs);
    notifyListeners();
    return true;
  }

  // ── Persist helpers ───────────────────────────────────────────────────────
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCoinBalance,    _coinBalance);
    await prefs.setInt(_kTotalEarned,    _totalEarned);
    await prefs.setInt(_kWeeklyEarned,   _weeklyEarned);
    if (_lastAdWatchDate != null) {
      await prefs.setString(_kLastAdWatchDate, _lastAdWatchDate!);
    }
    await _persistCheckIn(prefs: prefs);
    await _persistTaskProgress(prefs: prefs);
    await _persistWithdrawals(prefs: prefs);
  }

  Future<void> _persistWithdrawals({SharedPreferences? prefs}) async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(
      _kWithdrawals,
      jsonEncode(_withdrawals.map((w) => w.toJson()).toList()),
    );
  }

  Future<void> _persistCheckIn({SharedPreferences? prefs}) async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(_kCheckInHistory, jsonEncode(_checkInHistory));
    await prefs.setInt(_kCheckInStreak, _checkInStreak);
    if (_lastCheckInDate != null) {
      await prefs.setString(_kLastCheckInDate, _lastCheckInDate!);
    }
  }

  Future<void> _persistTaskProgress({SharedPreferences? prefs}) async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(_kTaskProgress, jsonEncode(_taskProgress));
  }

  // ── Date helpers ──────────────────────────────────────────────────────────
  static String _dateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  static String _thisMonday() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return _dateKey(monday);
  }

  // ── Daily reward schedule (coins per day in the 7-day cycle - strictly increasing) ───
  static const List<int> dailyRewards = [25, 50, 100, 150, 200, 300, 500];
}
