import 'dart:async';

import 'package:flutter/widgets.dart';

/// 难度 / 素材配置（计划书 §4.3：由家长中心下发，M1 提供最小实现）。
class GameConfig {
  const GameConfig({
    this.level = 0,
    this.pairDelayMs = 1500,
    this.showTimer = true,
  });

  /// 难度档位（0 起，由各游戏自行解释）
  final int level;

  /// 配对失败后盖回的延迟（儿童档 1.5s，玩法设计文档「翻牌记忆」开发核心）
  final int pairDelayMs;

  /// 是否显示计时
  final bool showTimer;

  GameConfig copyWith({int? level, int? pairDelayMs, bool? showTimer}) {
    return GameConfig(
      level: level ?? this.level,
      pairDelayMs: pairDelayMs ?? this.pairDelayMs,
      showTimer: showTimer ?? this.showTimer,
    );
  }
}

/// 统一结算数据（计划书 §4.3：分数 / 星星 / 用时）。
@immutable
class GameResult {
  const GameResult({
    required this.gameId,
    required this.score,
    required this.stars,
    required this.duration,
    this.metrics = const <String, dynamic>{},
  });

  final String gameId;

  /// 分数
  final int score;

  /// 星级（0~3）
  final int stars;

  /// 本局用时
  final Duration duration;

  /// 玩法相关的附加指标（步数、连击、正确率……），用于结算页展示
  final Map<String, dynamic> metrics;

  GameResult copyWith({int? score, int? stars}) {
    return GameResult(
      gameId: gameId,
      score: score ?? this.score,
      stars: stars ?? this.stars,
      duration: duration,
      metrics: metrics,
    );
  }
}

/// 统一游戏抽象接口（计划书 §4.3，M1 锁定）。
///
/// **硬契约**：所有游戏必须实现本接口并复用 `GameScaffold` 与统一结算弹窗，
/// 禁止自造外壳 / 结算页（AGENT.md §2 协作规则 2）。
abstract class GameModule {
  /// 唯一标识
  String get id;

  /// 名称
  String get name;

  /// 适龄下限
  int get minAge;

  /// 素材包大小（单位：字节；内置游戏为 0，M2 起由素材包清单提供）
  Size get packSize;

  /// 注入难度 / 素材路径；同时作为「再玩一次」的重置入口
  Future<void> init(GameConfig config);

  /// 构建游戏画面（由 `GameScaffold` 放入统一外壳）
  Widget buildGamePage(BuildContext context);

  /// 暂停（护眼计时 / 切后台由框架统一拦截，计划书 §4.3 规则 3）
  void pause();

  /// 恢复
  void resume();

  /// 释放资源
  void dispose();

  /// 统一结算上报（分数 / 星星 / 用时）
  Stream<GameResult> get resultStream;

  /// 可选：游戏专属 HUD（步数、难度切换等），由 `GameScaffold` 渲染在画布上方。
  ///
  /// 默认不显示；UI 规范 §8.6.4 要求游戏画布与 UI 层分离，故 HUD 不画进画布。
  Widget? buildHud(BuildContext context) => null;
}
