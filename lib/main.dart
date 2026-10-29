import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:tongqu_gamebox/demo/flame_demo_game.dart';

void main() {
  runApp(const TongquApp());
}

/// 《童趣游戏盒》M0 环境验证入口：
/// 全屏运行一个最小 Flame demo（受控方块 + 实时 FPS）。
class TongquApp extends StatelessWidget {
  const TongquApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '童趣游戏盒 · M0 环境验证',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFB74D)),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: GameWidget(game: FlameDemoGame()),
      ),
    );
  }
}
