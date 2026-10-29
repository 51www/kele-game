import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tongqu_gamebox/core/storage/progress_store.dart';
import 'package:tongqu_gamebox/features/home/home_page.dart';
import 'package:tongqu_gamebox/game_engine/game_module.dart';
import 'package:tongqu_gamebox/game_engine/game_registry.dart';
import 'package:tongqu_gamebox/game_engine/score_system.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressStore.instance.init();
  });

  /// 手机竖屏基准视口（AGENT.md §1.1：360×800）
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('大厅渲染「我的游戏 / 游戏商店」与家长中心入口',
      (WidgetTester tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump();

    expect(find.text('童趣游戏盒'), findsOneWidget);
    expect(find.text('我的游戏'), findsOneWidget);
    expect(find.text('翻牌记忆'), findsOneWidget);

    // 商店在同页下方，需要滚动才可见
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pump();
    expect(find.text('游戏商店'), findsOneWidget);
    expect(find.text('打地鼠'), findsOneWidget);
    expect(find.text('宝宝爱拼图'), findsOneWidget);
  });

  testWidgets('点击商店卡片给出提示而不是进入游戏',
      (WidgetTester tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pump();

    await tester.tap(find.text('打地鼠'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('马上就来啦'), findsOneWidget);
  });

  test('统一计分：按步数评星并计算分数', () {
    // 完美步数 = 对子数；≤ 对子数×2−2 三星
    expect(ScoreSystem.starsFor((int steps) => steps <= 4 ? 3 : 1, 4), 3);
    expect(ScoreSystem.starsFor((int steps) => steps <= 4 ? 3 : 1, 5), 1);

    final int score = ScoreSystem.computeScore(
      baseScore: 300,
      steps: 3,
      perfectSteps: 3,
      duration: Duration(seconds: 10),
    );
    // 300 分基准 + 50 分用时奖励（上限 60，实际 50）
    expect(score, 350);
  });

  test('M-Store：结算成绩写入后可回显最高分与星级', () async {
    await ProgressStore.instance.saveResult(
      gameId: 'memory_match',
      score: 320,
      stars: 2,
    );
    await ProgressStore.instance.saveResult(
      gameId: 'memory_match',
      score: 280,
      stars: 3,
    );

    final progress = ProgressStore.instance.progressOf('memory_match');
    expect(progress.bestScore, 320);
    expect(progress.bestStars, 3);
    expect(progress.lastScore, 280);
    expect(progress.plays, 2);
    expect(progress.unlocked, isTrue);
  });

  test('游戏清单：内置翻牌记忆可创建，其余为商店占位', () {
    expect(GameRegistry.byId('memory_match'), isNotNull);
    expect(GameRegistry.memoryMatch.builtIn, isTrue);
    expect(GameRegistry.memoryMatch.isPlayable, isTrue);
    expect(GameRegistry.byId('not_exist'), isNull);
    expect(GameRegistry.whackMole.isPlayable, isFalse);
    expect(const GameConfig().pairDelayMs, 1500);
  });
}
