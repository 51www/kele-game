import 'dart:async';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../game_engine/game_module.dart';
import '../../game_engine/score_system.dart';
import 'memory_match_game.dart';

/// 翻牌记忆的 `GameModule` 实现（里程碑 M1 内置验证游戏）。
///
/// 玩法与计分遵循《童趣游戏盒-游戏玩法设计文档》§2：
/// - 双翻状态机 + 防连点锁；
/// - 不配对时按儿童档延迟 1.5s 盖回；
/// - 按步数评星（完美步数 = 对子数）。
class MemoryMatchModule extends GameModule {
  MemoryMatchModule() {
    _game = MemoryMatchGame(
      onComplete: _handleComplete,
      onStep: _handleStep,
    );
  }

  /// 共享角色库中的 12 个萌系动物卡面（素材资源指南 §3.1）
  ///
  /// 路径为 pubspec 声明的完整资源键；Flame 的 `Images` 缓存默认带
  /// `assets/images/` 前缀，这里改用空前缀缓存，直接按完整资源键取图。
  static const List<String> kCharacterAssets = <String>[
    'assets/shared/character-library/animal_01_cat.png',
    'assets/shared/character-library/animal_02_dog.png',
    'assets/shared/character-library/animal_03_rabbit.png',
    'assets/shared/character-library/animal_04_panda.png',
    'assets/shared/character-library/animal_05_fox.png',
    'assets/shared/character-library/animal_06_unicorn.png',
    'assets/shared/character-library/animal_07_bear.png',
    'assets/shared/character-library/animal_08_penguin.png',
    'assets/shared/character-library/animal_09_frog.png',
    'assets/shared/character-library/animal_10_chick.png',
    'assets/shared/character-library/animal_11_pig.png',
    'assets/shared/character-library/animal_12_koala.png',
  ];

  /// 精灵缓存（空前缀 = 直接按资源键取图）
  final Images _spriteImages = Images(prefix: '');

  late final MemoryMatchGame _game;

  final StreamController<GameResult> _resultController =
      StreamController<GameResult>.broadcast();

  /// 步数（HUD 实时显示）
  final ValueNotifier<int> steps = ValueNotifier<int>(0);

  /// 当前难度档
  final ValueNotifier<int> levelIndex = ValueNotifier<int>(0);

  List<Sprite>? _spriteCache;

  @override
  String get id => 'memory_match';

  @override
  String get name => '翻牌记忆';

  @override
  int get minAge => 3;

  @override
  Size get packSize => const Size(0, 0);

  @override
  Stream<GameResult> get resultStream => _resultController.stream;

  @override
  Future<void> init(GameConfig config) async {
    _spriteCache ??= await Future.wait(
      kCharacterAssets.map(
        (String path) => Sprite.load(path, images: _spriteImages),
      ),
    );
    _game.configure(
      config: config,
      sprites: _spriteCache!,
      levelIndex: levelIndex.value,
    );
    steps.value = 0;
  }

  @override
  Widget buildGamePage(BuildContext context) => GameWidget(game: _game);

  @override
  Widget? buildHud(BuildContext context) {
    return _MemoryMatchHud(
      levelIndex: levelIndex,
      steps: steps,
      onLevelChanged: _changeLevel,
    );
  }

  void _changeLevel(int index) {
    if (index == levelIndex.value) return;
    levelIndex.value = index;
    steps.value = 0;
    _game.configure(
      config: const GameConfig(),
      sprites: _spriteCache ?? const <Sprite>[],
      levelIndex: index,
    );
  }

  void _handleStep(int value) {
    steps.value = value;
  }

  void _handleComplete(MemoryMatchStats stats) {
    final int pairs = kMemoryLevels[levelIndex.value].pairs;
    final int stars = ScoreSystem.starsFor(
      (int steps) => _starsFor(steps, pairs),
      stats.steps,
    );
    final int score = ScoreSystem.computeScore(
      baseScore: 100 * pairs,
      steps: stats.steps,
      perfectSteps: pairs,
      duration: stats.duration,
    );
    _resultController.add(
      GameResult(
        gameId: id,
        score: score,
        stars: stars,
        duration: stats.duration,
        metrics: <String, dynamic>{'steps': stats.steps},
      ),
    );
  }

  /// 步数评星：≤ 对子数×2−2 三星，≤ 对子数×3−2 两星，其余一星
  /// （对应玩法设计文档「4×4 下 ≤14 步三星」）。
  static int _starsFor(int steps, int pairs) {
    if (steps <= pairs * 2 - 2) return 3;
    if (steps <= pairs * 3 - 2) return 2;
    return 1;
  }

  @override
  void pause() {
    _game.pauseEngine();
  }

  @override
  void resume() {
    _game.resumeEngine();
  }

  @override
  void dispose() {
    _game.clearBoard();
    _resultController.close();
  }
}

/// 翻牌记忆 HUD：难度切换 + 步数（UI 规范 §8.6.4：画布与 UI 分层）
class _MemoryMatchHud extends StatelessWidget {
  const _MemoryMatchHud({
    required this.levelIndex,
    required this.steps,
    required this.onLevelChanged,
  });

  final ValueNotifier<int> levelIndex;
  final ValueNotifier<int> steps;
  final void Function(int index) onLevelChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < kMemoryLevels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ValueListenableBuilder<int>(
              valueListenable: levelIndex,
              builder: (BuildContext context, int value, Widget? child) {
                return _LevelChip(
                  label: kMemoryLevels[i].label,
                  selected: value == i,
                  onTap: () => onLevelChanged(i),
                );
              },
            ),
          ),
        const Spacer(),
        ValueListenableBuilder<int>(
          valueListenable: steps,
          builder: (BuildContext context, int value, Widget? child) {
            return Text(
              '步数 $value',
              style: AppTypography.bodyBold.copyWith(color: AppColors.text2),
            );
          },
        ),
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandDeep : AppColors.panelBg,
          borderRadius: BorderRadius.circular(AppRadii.md),
          // 未选中档位为白底，落在白色面板上必须靠描边勾出轮廓
          border: Border.all(
            color: selected ? AppColors.brandDeep : AppColors.btnSecondaryBorder,
            width: AppStrokes.outline,
          ),
          boxShadow: AppShadows.rim(
            selected ? AppColors.brandDeep : AppColors.btnSecondaryBorder,
            offset: AppShadows.rimThin,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodyBold.copyWith(
            color: selected ? AppColors.brandOnPurple : AppColors.text1,
          ),
        ),
      ),
    );
  }
}
