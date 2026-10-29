import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../games/memory_match/memory_match_module.dart';
import 'game_module.dart';

/// 游戏清单条目：大厅「我的游戏 / 游戏商店」的数据源。
class GameDescriptor {
  const GameDescriptor({
    required this.id,
    required this.name,
    required this.minAge,
    required this.packSizeBytes,
    required this.tileColor,
    this.iconAsset,
    this.fallbackIcon,
    this.builtIn = false,
    this.moduleBuilder,
  });

  /// 唯一标识
  final String id;

  /// 名称
  final String name;

  /// 适龄下限
  final int minAge;

  /// 素材包大小（字节）；内置游戏为 0
  final int packSizeBytes;

  /// 大厅宫格底色（马卡龙瓷砖色板）
  final Color tileColor;

  /// 宫格大图标素材
  final String? iconAsset;

  /// 尚无美术素材时使用的占位图标
  final IconData? fallbackIcon;

  /// 是否内置（内置游戏无需下载，M2 起其余游戏走素材包解锁）
  final bool builtIn;

  /// 创建游戏实例；商店占位条目为 null
  final GameModule Function()? moduleBuilder;

  bool get isPlayable => moduleBuilder != null;

  /// 素材包大小文案
  String get packSizeLabel {
    if (builtIn) return '内置';
    final double mb = packSizeBytes / 1024 / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// 适龄文案
  String get ageLabel => '$minAge 岁+';

  GameModule? createModule() => moduleBuilder?.call();
}

/// 全局游戏清单（计划书 §3.1 共 19 款，M1 起逐批接入）。
class GameRegistry {
  const GameRegistry._();

  /// 内置验证游戏：翻牌记忆
  static const GameDescriptor memoryMatch = GameDescriptor(
    id: 'memory_match',
    name: '翻牌记忆',
    minAge: 3,
    packSizeBytes: 0,
    tileColor: AppColors.tileLavender,
    iconAsset: 'assets/shared/character-library/animal_05_fox.png',
    builtIn: true,
    moduleBuilder: MemoryMatchModule.new,
  );

  /// 商店占位：打地鼠（M4 内容①）
  static const GameDescriptor whackMole = GameDescriptor(
    id: 'whack_mole',
    name: '打地鼠',
    minAge: 3,
    packSizeBytes: 6 * 1024 * 1024,
    tileColor: AppColors.tileSakura,
    fallbackIcon: Icons.gps_fixed_rounded,
  );

  /// 商店占位：宝宝爱拼图（M4 内容①）
  static const GameDescriptor jigsaw = GameDescriptor(
    id: 'jigsaw',
    name: '宝宝爱拼图',
    minAge: 3,
    packSizeBytes: 8 * 1024 * 1024,
    tileColor: AppColors.tileMint,
    fallbackIcon: Icons.extension_rounded,
  );

  static const List<GameDescriptor> all = <GameDescriptor>[
    memoryMatch,
    whackMole,
    jigsaw,
  ];

  static GameDescriptor? byId(String id) {
    for (final GameDescriptor descriptor in all) {
      if (descriptor.id == id) return descriptor;
    }
    return null;
  }
}
