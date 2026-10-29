import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/storage/progress_store.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_page.dart';
import 'game_engine/game_module.dart';
import 'game_engine/game_registry.dart';
import 'game_engine/game_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // M-Store：先加载本地进度，再渲染大厅（避免首帧闪烁）
  await ProgressStore.instance.init();
  runApp(const TongquApp());
}

/// 《童趣游戏盒》应用入口。
class TongquApp extends StatelessWidget {
  const TongquApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '童趣游戏盒',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.child(),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('zh', 'CN')],
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.home,
    );
  }
}

/// 全局路由（计划书 §4.2 工程结构：`lib/core` 负责路由）。
class AppRouter {
  const AppRouter._();

  static const String home = '/';
  static const String parent = '/parent';
  static const String gamePrefix = '/game/';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final String name = settings.name ?? home;
    if (name == home) {
      return MaterialPageRoute<void>(
        builder: (BuildContext context) => const HomePage(),
      );
    }
    if (name == parent) {
      return MaterialPageRoute<void>(
        builder: (BuildContext context) => const HomePage(),
      );
    }
    if (name.startsWith(gamePrefix)) {
      final String id = name.substring(gamePrefix.length);
      final GameDescriptor? descriptor = GameRegistry.byId(id);
      if (descriptor == null || !descriptor.isPlayable) {
        return MaterialPageRoute<void>(
          builder: (BuildContext context) => const HomePage(),
        );
      }
      // 模块实例在路由构建时创建一次，避免页面重建时重复 new
      final GameModule module = descriptor.createModule()!;
      return MaterialPageRoute<void>(
        builder: (BuildContext context) => GameScaffold(
          module: module,
          config: const GameConfig(),
        ),
      );
    }
    return null;
  }
}
