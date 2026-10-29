import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tongqu_gamebox/main.dart';

void main() {
  testWidgets('M0 demo 能正常启动并渲染', (WidgetTester tester) async {
    // 构建并渲染 App（游戏循环常驻，不能用 pumpAndSettle）。
    await tester.pumpWidget(const TongquApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 标题栏文本应存在（验证 MaterialApp 已挂载）。
    expect(find.byType(MaterialApp), findsOneWidget);
    // 游戏画布 GameWidget（泛型类型）应被挂载。
    expect(find.byWidgetPredicate((w) => w is GameWidget), findsOneWidget);
  });
}
