import 'package:flutter/foundation.dart';

/// 单款游戏的本地进度记录（计划书 §4.4：每游戏一个 json）。
@immutable
class GameProgress {
  const GameProgress({
    required this.gameId,
    this.unlocked = false,
    this.bestScore = 0,
    this.bestStars = 0,
    this.lastScore = 0,
    this.lastStars = 0,
    this.plays = 0,
    this.updatedAt,
  });

  /// 游戏唯一 id
  final String gameId;

  /// 是否已解锁（内置游戏恒为 true；素材包游戏由 M2 下载系统写入）
  final bool unlocked;

  /// 历史最高分
  final int bestScore;

  /// 历史最高星级（0~3）
  final int bestStars;

  /// 最近一局得分
  final int lastScore;

  /// 最近一局星级
  final int lastStars;

  /// 累计游玩局数
  final int plays;

  /// 最近一次更新时间
  final DateTime? updatedAt;

  /// 是否玩过
  bool get hasPlayed => plays > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'unlocked': unlocked,
        'bestScore': bestScore,
        'bestStars': bestStars,
        'lastScore': lastScore,
        'lastStars': lastStars,
        'plays': plays,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };

  static GameProgress fromJson(String gameId, Map<String, dynamic> json) {
    return GameProgress(
      gameId: gameId,
      unlocked: json['unlocked'] == true,
      bestScore: (json['bestScore'] as num?)?.toInt() ?? 0,
      bestStars: (json['bestStars'] as num?)?.toInt() ?? 0,
      lastScore: (json['lastScore'] as num?)?.toInt() ?? 0,
      lastStars: (json['lastStars'] as num?)?.toInt() ?? 0,
      plays: (json['plays'] as num?)?.toInt() ?? 0,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (json['updatedAt'] as num).toInt(),
            ),
    );
  }
}
