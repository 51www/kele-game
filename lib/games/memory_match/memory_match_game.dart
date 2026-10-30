import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/audio/sound_manager.dart';
import '../../core/theme/app_tokens.dart';
import '../../game_engine/game_module.dart';

/// 翻牌记忆的难度档（玩法设计文档：2×3 → 3×4 → 4×4 → 6×6）。
///
/// M1 内置 12 张角色卡（6 对），因此提供到 3×4。
class MemoryLevel {
  const MemoryLevel({
    required this.columns,
    required this.rows,
    required this.label,
  });

  final int columns;
  final int rows;
  final String label;

  int get cardCount => columns * rows;
  int get pairs => cardCount ~/ 2;
}

const List<MemoryLevel> kMemoryLevels = <MemoryLevel>[
  MemoryLevel(columns: 2, rows: 3, label: '2×3'),
  MemoryLevel(columns: 2, rows: 4, label: '2×4'),
  MemoryLevel(columns: 3, rows: 4, label: '3×4'),
];

/// 一局结算所需的统计数据
class MemoryMatchStats {
  const MemoryMatchStats({
    required this.steps,
    required this.duration,
    required this.pairs,
  });

  final int steps;
  final Duration duration;
  final int pairs;
}

/// 翻牌记忆（Flame 实现）。
///
/// 核心循环（玩法设计文档）：翻第一张 → 翻第二张 → 比较 → 配对（保持翻开）
/// / 不配对（短暂展示后盖回）→ 继续。
class MemoryMatchGame extends FlameGame with TapCallbacks {
  MemoryMatchGame({
    required this.onComplete,
    required this.onStep,
  });

  /// 全部配对完成时回调
  final void Function(MemoryMatchStats stats) onComplete;

  /// 步数变化时回调（用于 HUD）
  final void Function(int steps) onStep;

  static const double _gap = AppSpacing.md;
  static const double _padding = AppSpacing.md;

  /// 卡背颜色循环取自马卡龙瓷砖色板（UI 规范 §1.2：仅用于游戏元素）
  static const List<Color> _backColors = <Color>[
    AppColors.tileLavender,
    AppColors.tileMint,
    AppColors.tileSky,
    AppColors.tileSakura,
    AppColors.tilePeach,
    AppColors.tileLemon,
  ];

  GameConfig _config = const GameConfig();
  List<Sprite> _sprites = <Sprite>[];
  int _levelIndex = 0;
  bool _configured = false;

  final List<MemoryCard> _cards = <MemoryCard>[];
  int _steps = 0;
  int _matchedPairs = 0;
  int _firstIndex = -1;
  int _secondIndex = -1;
  bool _finished = false;
  double _elapsed = 0;

  /// 状态机：0 等待点击 / 1 已翻第一张 / 2 两张已翻开待比较 / 3 不配对待盖回
  int _phase = 0;
  double _phaseTimer = 0;

  /// 翻开第二张后停留多久再判定（让孩子看清这一对）
  static const double _compareDelay = 0.55;

  @override
  Color backgroundColor() => AppColors.panelBg;

  /// 注入难度与素材；已挂载时立即重开一局（对应「再玩一次」）。
  void configure({
    required GameConfig config,
    required List<Sprite> sprites,
    int levelIndex = 0,
  }) {
    _config = config;
    _sprites = sprites;
    _levelIndex = levelIndex.clamp(0, kMemoryLevels.length - 1);
    _configured = true;
    if (isLoaded) {
      _buildBoard();
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (_configured) {
      _buildBoard();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout();
  }

  MemoryLevel get _level => kMemoryLevels[_levelIndex];

  /// 重建棋盘：Fisher-Yates 洗牌（`List.shuffle` 即 Fisher-Yates 实现）
  void _buildBoard() {
    clearBoard();

    final int pairs = _level.pairs;
    final List<int> deck = <int>[
      for (int i = 0; i < pairs; i++) i,
      for (int i = 0; i < pairs; i++) i,
    ];
    deck.shuffle(math.Random());

    for (int i = 0; i < deck.length; i++) {
      final MemoryCard card = MemoryCard(
        pairId: deck[i],
        sprite: _sprites[deck[i]],
        backColor: _backColors[i % _backColors.length],
      );
      _cards.add(card);
      add(card);
    }

    _steps = 0;
    _matchedPairs = 0;
    _firstIndex = -1;
    _secondIndex = -1;
    _phase = 0;
    _phaseTimer = 0;
    _finished = false;
    _elapsed = 0;
    onStep(0);
    _layout();
  }

  /// 清空棋盘（释放卡牌组件）
  void clearBoard() {
    for (final MemoryCard card in _cards) {
      card.removeFromParent();
    }
    _cards.clear();
  }

  /// 按画布尺寸重排卡牌（手机竖屏 360dp 基准，UI 规范 §8.6）
  void _layout() {
    if (size.x <= 0 || size.y <= 0 || _cards.isEmpty) return;
    final double availW = size.x - _padding * 2;
    final double availH = size.y - _padding * 2;
    final double cardW =
        (availW - _gap * (_level.columns - 1)) / _level.columns;
    final double cardH = math.min(
      cardW * 1.12,
      (availH - _gap * (_level.rows - 1)) / _level.rows,
    );
    final double boardW = cardW * _level.columns + _gap * (_level.columns - 1);
    final double boardH = cardH * _level.rows + _gap * (_level.rows - 1);
    final double startX = (size.x - boardW) / 2;
    final double startY = (size.y - boardH) / 2;

    for (int i = 0; i < _cards.length; i++) {
      final int col = i % _level.columns;
      final int row = i ~/ _level.columns;
      final MemoryCard card = _cards[i];
      card.size = Vector2(cardW, cardH);
      card.position = Vector2(
        startX + col * (cardW + _gap),
        startY + row * (cardH + _gap),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;
    _elapsed += dt;

    if (_phase == 2) {
      _phaseTimer += dt;
      if (_phaseTimer >= _compareDelay) {
        _resolvePair();
      }
    } else if (_phase == 3) {
      _phaseTimer += dt;
      if (_phaseTimer >= _config.pairDelayMs / 1000) {
        _cards[_firstIndex].hide();
        _cards[_secondIndex].hide();
        _firstIndex = -1;
        _secondIndex = -1;
        _phase = 0;
      }
    }
  }

  void _resolvePair() {
    final MemoryCard first = _cards[_firstIndex];
    final MemoryCard second = _cards[_secondIndex];
    if (first.pairId == second.pairId) {
      first.markMatched();
      second.markMatched();
      _matchedPairs++;
      _firstIndex = -1;
      _secondIndex = -1;
      _phase = 0;
      if (_matchedPairs >= _level.pairs) {
        _finish();
      } else {
        SoundManager.instance.match();
      }
    } else {
      SoundManager.instance.wrong();
      _phase = 3;
      _phaseTimer = 0;
    }
  }

  void _finish() {
    _finished = true;
    SoundManager.instance.win();
    onComplete(
      MemoryMatchStats(
        steps: _steps,
        duration: Duration(milliseconds: (_elapsed * 1000).round()),
        pairs: _matchedPairs,
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (_finished) return;
    // 防连点锁：比较中 / 待盖回阶段不接受输入；
    // 「等待点击」与「已翻第一张」阶段可以点击（构成一次双翻）
    if (_phase != 0 && _phase != 1) return;

    final Vector2 point = event.localPosition;
    final Offset offset = Offset(point.x, point.y);
    int hit = -1;
    for (int i = 0; i < _cards.length; i++) {
      final MemoryCard card = _cards[i];
      final Rect rect = Rect.fromLTWH(
        card.position.x,
        card.position.y,
        card.size.x,
        card.size.y,
      );
      if (rect.contains(offset)) {
        hit = i;
        break;
      }
    }
    if (hit < 0) return;
    final MemoryCard card = _cards[hit];
    if (card.matched || card.revealed) return;

    card.show();
    SoundManager.instance.flip();
    if (_firstIndex < 0) {
      _firstIndex = hit;
      _phase = 1;
    } else {
      _secondIndex = hit;
      _steps++;
      onStep(_steps);
      _phase = 2;
      _phaseTimer = 0;
    }
  }
}

/// 单张卡牌（背面 / 正面翻转 + 配对成功庆祝）
class MemoryCard extends PositionComponent {
  MemoryCard({
    required this.pairId,
    required this.sprite,
    required this.backColor,
  }) : super(anchor: Anchor.topLeft);

  final int pairId;
  final Sprite sprite;
  final Color backColor;

  bool revealed = false;
  bool matched = false;

  double _flip = 0;
  double _target = 0;
  double _pulse = 0;

  void show() {
    revealed = true;
    _target = 1;
  }

  void hide() {
    revealed = false;
    _target = 0;
  }

  void markMatched() {
    matched = true;
    revealed = true;
    _target = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final double speed = dt * 6.5;
    if (_flip < _target) {
      _flip = math.min(1, _flip + speed);
    } else if (_flip > _target) {
      _flip = math.max(0, _flip - speed);
    }
    if (matched) {
      _pulse += dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final Rect rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final bool front = _flip >= 0.5;
    final double flipScale =
        front ? (_flip - 0.5) * 2 : (1 - _flip * 2);
    final double pulse =
        matched ? 1 + 0.05 * math.sin(_pulse * 6) : 1.0;

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(pulse, pulse);
    canvas.scale(flipScale.clamp(0.0, 1.0), 1.0);
    canvas.translate(-size.x / 2, -size.y / 2);

    final RRect background = RRect.fromRectAndRadius(
      rect.deflate(1),
      const Radius.circular(AppRadii.md),
    );

    if (front) {
      canvas.drawRRect(background, Paint()..color = AppColors.panelBg);
      final double side = math.min(size.x, size.y) - AppSpacing.md;
      final double dx = (size.x - side) / 2;
      final double dy = (size.y - side) / 2;
      sprite.render(
        canvas,
        position: Vector2(dx, dy),
        size: Vector2(side, side),
        anchor: Anchor.topLeft,
      );
    } else {
      canvas.drawRRect(background, Paint()..color = backColor);
      final double radius = math.min(size.x, size.y) * 0.24;
      canvas.drawPath(
        _starPath(Offset(size.x / 2, size.y / 2), radius),
        Paint()..color = AppColors.panelBg.withValues(alpha: 0.85),
      );
    }

    canvas.restore();
  }

  /// 五角星路径（卡背图案，避免引入额外贴图）
  static Path _starPath(Offset center, double radius) {
    final Path path = Path();
    for (int i = 0; i < 10; i++) {
      final double r = i.isEven ? radius : radius * 0.42;
      final double angle = -math.pi / 2 + i * math.pi / 5;
      final Offset point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }
}
