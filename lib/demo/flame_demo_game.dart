import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// M0 环境验证用最小 Flame demo：
/// 一个"受控方块"会跟随手指 / 鼠标移动，左上角实时显示帧率（FPS）。
///
/// 布局遵循 AGENT.md §1.1「手机优先」：以竖屏手机（360dp 宽）为基准，
/// 窄屏下 FPS 与提示文案分层排布，互不遮挡；方块始终被约束在画布内。
///
/// 触控注意：拖拽跟随目标必须取 `DragUpdateEvent.localStartPosition`
/// （= Flutter 的 globalPosition，已包含本帧 delta）。
/// **不要用 `localEndPosition`**：Flame 的 DragUpdateEvent 把
/// `deviceEndPosition` 定义为 `globalPosition + delta`，而 Flutter 的
/// globalPosition 本身已含该 delta，直接用会**重复计入一帧位移**，
/// 导致拖拽目标比手指实际位置偏移（移动端尤其明显）。
class FlameDemoGame extends FlameGame with TapCallbacks, DragCallbacks {
  // 奶油底，贴合《童趣游戏盒》儿童化配色
  @override
  Color backgroundColor() => const Color(0xFFFFF3E0);

  final MovingSquare _square = MovingSquare(position: Vector2.zero());
  final FpsDisplay _fps = FpsDisplay();
  final TextComponent _hint = TextComponent(
    text: '拖动方块跟着手指走 · M0',
    textRenderer: TextPaint(
      style: const TextStyle(
        color: Color(0xFF5D4037),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    anchor: Anchor.topCenter,
  );

  final Vector2 _target = Vector2.zero();
  bool _dragging = false;
  bool _interacted = false;
  double _elapsed = 0;
  bool _ready = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(_square);
    add(_fps);
    add(_hint);
    _ready = true;
    _layout(size);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_ready) return; // onLoad 未完成时交给 _layout 处理
    debugPrint('[M0] canvas size = $size');
    _fps.position = Vector2(16, 16);
    _hint.position = Vector2(size.x / 2, 58);
    if (!_interacted) {
      _target.setFrom(size / 2);
      _square.position.setFrom(size / 2);
    }
  }

  void _layout(Vector2 s) {
    if (s.x <= 0 || s.y <= 0) return;
    _target.setFrom(s / 2);
    _square.position.setFrom(s / 2);
    _fps.position = Vector2(16, 16);
    _hint.position = Vector2(s.x / 2, 58);
  }

  /// 把方块约束在画布内，避免窄屏或快速拖拽时滑出可视区域。
  void _keepInCanvas() {
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;
    const m = MovingSquare.boxSize / 2 + 8;
    final x = w <= m * 2 ? w / 2 : _square.position.x.clamp(m, w - m);
    final y = h <= m * 2 ? h / 2 : _square.position.y.clamp(m, h - m);
    _square.position.setValues(x, y);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _interacted = true;
    _dragging = true;
    _target.setFrom(event.localPosition);
    debugPrint('[M0] tapDown at=${event.localPosition}');
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _interacted = true;
    _dragging = true;
    _target.setFrom(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    // 取起始位置而非结束位置：localEndPosition 会重复计入一帧 delta
    _target.setFrom(event.localStartPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _dragging = false;
    debugPrint('[M0] dragEnd target=$_target pos=${_square.position}');
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragging = false;
  }

  @override
  void onTapUp(TapUpEvent event) {
    _dragging = false;
    debugPrint('[M0] tapUp target=$_target pos=${_square.position}');
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_dragging) {
      _square.position.lerp(_target, 0.2);
    } else {
      // 空闲时上下轻微浮动，保证画面持续运动以观察帧率
      _square.position
        ..setFrom(_target)
        ..y += math.sin(_elapsed * 2) * 18;
    }
    _keepInCanvas();
    _square.spin = _elapsed * (_dragging ? 3.0 : 1.0);
  }
}

/// 受控方块：橙色外框 + 蓝色内核，内核持续旋转以体现画面在动。
class MovingSquare extends PositionComponent {
  static const double boxSize = 96.0;

  MovingSquare({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(boxSize),
          anchor: Anchor.center,
        );

  late final RectangleComponent _inner;
  double spin = 0.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // 注意：子组件的 position 相对父组件的**左上角**，不是父组件的锚点，
    // 因此这里要加上半个尺寸才能让方块居中于 MovingSquare 内部。
    final body = RectangleComponent(
      size: Vector2.all(boxSize),
      paint: Paint()..color = const Color(0xFFFFB74D),
      anchor: Anchor.center,
      position: Vector2(boxSize / 2, boxSize / 2),
    );
    _inner = RectangleComponent(
      size: Vector2.all(boxSize * 0.45),
      paint: Paint()..color = const Color(0xFF4FC3F7),
      anchor: Anchor.center,
      position: Vector2(boxSize / 2, boxSize / 2),
    );
    body.add(_inner);
    add(body);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _inner.angle = spin;
  }
}

/// 左上角实时帧率显示，每 0.5s 刷新一次。
class FpsDisplay extends TextComponent {
  FpsDisplay()
      : super(
          text: 'FPS: --',
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0xFFE65100),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          anchor: Anchor.topLeft,
        );

  int _frames = 0;
  double _window = 0;

  @override
  void update(double dt) {
    _frames++;
    _window += dt;
    if (_window >= 0.5) {
      final fps = _frames / _window;
      text = 'FPS: ${fps.toStringAsFixed(0)}';
      _frames = 0;
      _window = 0;
    }
  }
}
