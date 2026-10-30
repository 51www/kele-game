import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// M-Parent 儿童保护守卫（计划书 §4.4 + 开发里程碑文档 M3）：
///
/// - **护眼计时**：连续玩 20 分钟 → 强制休息动画（眼保健操 30 秒，不可跳过）；
/// - **每日时长**：家长可设 20~120 分钟（默认 40），到点锁屏显示「明天见」页至次日；
/// - 休息 / 锁屏期间由 [onFreezeGame]/[onResumeGame] 钩子冻结 / 恢复正在进行的游戏
///   （GameScaffold 注册，计划书 §4.3 规则 3：护眼暂停由游戏层统一拦截）。
///
/// 计时口径：应用前台每秒计 1 次「使用时长」，休息期间不计入。
/// 「连续时长」仅在内存中累计（休息结束归零）；「每日时长」按天持久化。
///
/// 验收演示（[demoMode]）：家长中心「验收调试」开启后，连续阈值缩短为 20 秒、
/// 每日上限缩短为 60 秒；休息时长仍为真实 30 秒（保持「不可跳过」验收口径）。
class ParentalGuard {
  ParentalGuard._();

  static final ParentalGuard instance = ParentalGuard._();

  // ── 固定规则（计划书 §4.4）────────────────────────────────────────────
  /// 连续使用阈值（分钟）：到点触发强制休息
  static const int restIntervalMinutes = 20;

  /// 强制休息时长（秒）：眼保健操，不可跳过
  static const int restDurationSeconds = 30;

  static const int defaultDailyLimitMinutes = 40;
  static const int minDailyLimitMinutes = 20;
  static const int maxDailyLimitMinutes = 120;

  // ── 验收演示节奏（demoMode 开启时生效）────────────────────────────────
  static const int demoContinuousSeconds = 20;
  static const int demoDailyLimitSeconds = 60;

  // ── 状态 ─────────────────────────────────────────────────────────────
  final ValueNotifier<GuardPhase> phase = ValueNotifier<GuardPhase>(
    GuardPhase.playing,
  );

  /// UI 刷新信号（每秒自增；护眼卡片据此回显今日/连续时长）
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// 游戏层冻结钩子（GameScaffold 注册；同一时刻至多一局游戏在前台）
  VoidCallback? onFreezeGame;
  VoidCallback? onResumeGame;

  bool _ready = false;
  Timer? _timer;
  SharedPreferences? _prefs;

  int _continuousSeconds = 0;
  int _dailySeconds = 0;
  int _restSecondsLeft = 0;
  DateTime _day = DateTime.now();
  bool _demoMode = false;

  bool get isReady => _ready;

  /// 验收演示节奏开关（持久化）
  bool get demoMode => _demoMode;

  /// 连续使用秒数（本次会话内）
  int get continuousSeconds => _continuousSeconds;

  /// 今日已使用秒数
  int get dailySeconds => _dailySeconds;

  /// 剩余休息秒数（休息中有效）
  int get restSecondsLeft => _restSecondsLeft;

  int get dailyLimitMinutes {
    final int stored = _prefs?.getInt(_dailyLimitKey) ?? 0;
    if (stored < minDailyLimitMinutes || stored > maxDailyLimitMinutes) {
      return defaultDailyLimitMinutes;
    }
    return stored;
  }

  static const String _dailyLimitKey = 'guard_daily_limit_minutes';
  static const String _dailySecondsKey = 'guard_daily_seconds';
  static const String _dailyDateKey = 'guard_daily_date';
  static const String _demoModeKey = 'guard_demo_mode';

  Future<void> start() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    _demoMode = _prefs!.getBool(_demoModeKey) ?? false;
    _loadDailyUsage();
    _ready = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _notifyPhase();
  }

  // ── 每日时长设置 ──────────────────────────────────────────────────────
  Future<void> setDailyLimit(int minutes) async {
    final int clamped = minutes.clamp(minDailyLimitMinutes, maxDailyLimitMinutes);
    await _prefs?.setInt(_dailyLimitKey, clamped);
    revision.value++;
    // 设置调小后若已超额，立即锁屏（规则生效优先于继续玩）
    _checkLimits();
  }

  /// 验收演示：切换演示节奏（20 秒连续阈值 / 60 秒每日上限）
  Future<void> setDemoMode(bool value) async {
    _demoMode = value;
    await _prefs?.setBool(_demoModeKey, value);
    revision.value++;
  }

  /// 验收演示：清零今日使用与连续计时（仅调试入口提供）
  Future<void> resetToday() async {
    _continuousSeconds = 0;
    _dailySeconds = 0;
    await _saveDailyUsage();
    if (phase.value != GuardPhase.playing) {
      _restSecondsLeft = 0;
      _notifyPhase();
      _resumeGameIfFrozen();
    }
    revision.value++;
  }

  // ── 每秒心跳 ─────────────────────────────────────────────────────────
  void _tick() {
    if (phase.value == GuardPhase.resting) {
      // 休息倒计时（不可跳过，无任何输入出口）
      _restSecondsLeft--;
      if (_restSecondsLeft <= 0) {
        _restSecondsLeft = 0;
        _continuousSeconds = 0;
        _notifyPhase();
        _resumeGameIfFrozen();
      }
      revision.value++;
      return;
    }
    if (phase.value == GuardPhase.dailyLocked) {
      // 锁屏至次日：跨天自动解除
      if (_isNewDay()) {
        _loadDailyUsage();
        _notifyPhase();
      }
      return;
    }

    if (_isNewDay()) {
      _loadDailyUsage();
    }
    _continuousSeconds++;
    _dailySeconds++;
    if (_dailySeconds % 5 == 0) {
      _saveDailyUsage();
    }
    revision.value++;
    _checkLimits();
  }

  void _checkLimits() {
    if (phase.value != GuardPhase.playing) return;
    if (_dailySeconds >= _effectiveDailyLimitSeconds()) {
      _saveDailyUsage();
      _notifyPhase();
      _freezeGameIfPlaying();
      return;
    }
    if (_continuousSeconds >= _effectiveContinuousSeconds()) {
      _restSecondsLeft = restDurationSeconds;
      _notifyPhase();
      _freezeGameIfPlaying();
    }
  }

  int _effectiveDailyLimitSeconds() =>
      _demoMode ? demoDailyLimitSeconds : dailyLimitMinutes * 60;

  int _effectiveContinuousSeconds() =>
      _demoMode ? demoContinuousSeconds : restIntervalMinutes * 60;

  bool _isNewDay() {
    final DateTime now = DateTime.now();
    final bool changed =
        now.year != _day.year || now.month != _day.month || now.day != _day.day;
    if (changed) _day = now;
    return changed;
  }

  void _loadDailyUsage() {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    _day = DateTime.now();
    final String key = _dateKey(_day);
    if (prefs.getString(_dailyDateKey) == key) {
      _dailySeconds = prefs.getInt(_dailySecondsKey) ?? 0;
    } else {
      _dailySeconds = 0;
      prefs.setString(_dailyDateKey, key);
      prefs.setInt(_dailySecondsKey, 0);
    }
  }

  Future<void> _saveDailyUsage() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_dailyDateKey, _dateKey(_day));
    await prefs.setInt(_dailySecondsKey, _dailySeconds);
  }

  String _dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}'
      '${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  // ── 游戏冻结 ─────────────────────────────────────────────────────────
  void _freezeGameIfPlaying() {
    if (onFreezeGame != null) onFreezeGame!();
  }

  void _resumeGameIfFrozen() {
    if (onResumeGame != null) onResumeGame!();
  }

  void _notifyPhase() {
    GuardPhase next = GuardPhase.playing;
    if (_dailySeconds >= _effectiveDailyLimitSeconds()) {
      next = GuardPhase.dailyLocked;
    } else if (_restSecondsLeft > 0) {
      next = GuardPhase.resting;
    }
    if (phase.value != next || next != GuardPhase.playing) {
      phase.value = next;
    }
  }

  @visibleForTesting
  void debugStartForTest() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }
}

/// 护眼守卫阶段
enum GuardPhase {
  /// 正常使用
  playing,

  /// 强制休息中（眼保健操，不可跳过）
  resting,

  /// 今日时长用尽（「明天见」锁屏至次日）
  dailyLocked,
}
