import '../core/storage/game_progress.dart';
import '../core/storage/progress_store.dart';
import 'game_module.dart';

/// 星级规则：由各游戏按自身玩法提供（玩法设计文档「计分/结算」）。
typedef StarRule = int Function(int metric);

/// 统一计分系统（里程碑 M1：`score_system`）。
///
/// 职责：
/// 1. 把「步数 / 用时」换算成统一分数；
/// 2. 把「星级」按各游戏的规则换算出来；
/// 3. 结算落库到 M-Store（分数 / 星级 / 最高纪录）。
class ScoreSystem {
  const ScoreSystem._();

  /// 按规则给出星级（1~3 颗）。
  static int starsFor(StarRule rule, int metric) {
    final int stars = rule(metric);
    if (stars < 1) return 1;
    if (stars > 3) return 3;
    return stars;
  }

  /// 统一分数公式：基础分 − 超额步数惩罚 + 用时奖励。
  ///
  /// - [baseScore]：满分基准（各游戏按难度档给出）
  /// - [steps]：实际步数
  /// - [perfectSteps]：理论最少步数
  /// - [duration]：本局用时
  static int computeScore({
    required int baseScore,
    required int steps,
    required int perfectSteps,
    required Duration duration,
    int stepPenalty = 20,
    int timeBonusCap = 60,
  }) {
    final int extraSteps = steps - perfectSteps;
    final int penalty = extraSteps > 0 ? stepPenalty * extraSteps : 0;
    final int bonus = timeBonusCap - duration.inSeconds;
    final int score = baseScore - penalty + (bonus > 0 ? bonus : 0);
    return score < 10 ? 10 : score;
  }

  /// 结算落库：把成绩写入 M-Store，返回合并后的进度记录。
  static Future<GameProgress> commit(GameResult result) {
    return ProgressStore.instance.saveResult(
      gameId: result.gameId,
      score: result.score,
      stars: result.stars,
    );
  }
}
