import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_progress.dart';

/// M-Store 进度存储（计划书 §4.4）：SharedPreferences + 每游戏一个 json。
///
/// 任何写入都会递增 [revision]，大厅通过监听它实现「结算后回显分数/星级」。
class ProgressStore {
  ProgressStore._();

  static final ProgressStore instance = ProgressStore._();

  static const String _progressPrefix = 'progress_';
  static const String _soundMutedKey = 'settings_sound_muted';

  late final SharedPreferences _prefs;

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    _ready = true;
  }

  bool get isReady => _ready;

  GameProgress progressOf(String gameId) {
    if (!_ready) return GameProgress(gameId: gameId);
    final String? raw = _prefs.getString('$_progressPrefix$gameId');
    if (raw == null || raw.isEmpty) return GameProgress(gameId: gameId);
    try {
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      return GameProgress.fromJson(gameId, json);
    } catch (_) {
      // 存档损坏时回退为「未玩过」，不阻断游戏流程（UI 规范 §8.5.3：给恢复路径）
      return GameProgress(gameId: gameId);
    }
  }

  /// 写入一局成绩，返回合并后的最新进度。
  Future<GameProgress> saveResult({
    required String gameId,
    required int score,
    required int stars,
  }) async {
    final GameProgress old = progressOf(gameId);
    final GameProgress next = GameProgress(
      gameId: gameId,
      unlocked: true,
      bestScore: score > old.bestScore ? score : old.bestScore,
      bestStars: stars > old.bestStars ? stars : old.bestStars,
      lastScore: score,
      lastStars: stars,
      plays: old.plays + 1,
      updatedAt: DateTime.now(),
    );
    await _prefs.setString(
      '$_progressPrefix$gameId',
      jsonEncode(next.toJson()),
    );
    revision.value++;
    return next;
  }

  /// 标记某游戏已解锁（M2 下载系统接入后由下载完成回调调用）。
  Future<void> markUnlocked(String gameId) async {
    final GameProgress old = progressOf(gameId);
    await _prefs.setString(
      '$_progressPrefix$gameId',
      jsonEncode(
        GameProgress(
          gameId: gameId,
          unlocked: true,
          bestScore: old.bestScore,
          bestStars: old.bestStars,
          lastScore: old.lastScore,
          lastStars: old.lastStars,
          plays: old.plays,
          updatedAt: old.updatedAt,
        ).toJson(),
      ),
    );
    revision.value++;
  }

  /// 全局静音开关（M3 家长中心与音效包接入后由家长控制）。
  bool get soundMuted => _ready && _prefs.getBool(_soundMutedKey) == true;

  Future<void> setSoundMuted(bool muted) async {
    if (!_ready) return;
    await _prefs.setBool(_soundMutedKey, muted);
    revision.value++;
  }
}
