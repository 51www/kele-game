import 'package:flutter/material.dart';

import '../../core/storage/game_progress.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/stars_row.dart';
import '../../game_engine/game_registry.dart';

/// 大厅「我的游戏」卡片（UI 规范 §6.2：宫格底色 + 大图标 ≥96px + 游戏名）。
class MyGameCard extends StatelessWidget {
  const MyGameCard({
    super.key,
    required this.descriptor,
    required this.progress,
    required this.onTap,
  });

  final GameDescriptor descriptor;
  final GameProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: descriptor.name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: descriptor.tileColor,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _GameIcon(descriptor: descriptor),
              const SizedBox(height: AppSpacing.md),
              Text(
                descriptor.name,
                style: AppTypography.heading.copyWith(color: AppColors.text1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              StarsRow(filled: progress.bestStars, size: 18),
              const SizedBox(height: AppSpacing.xs),
              Text(
                progress.hasPlayed ? '最高 ${progress.bestScore} 分' : '还没有玩过',
                style: AppTypography.caption.copyWith(color: AppColors.text2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 大厅「游戏商店」卡片（UI 规范 §6.2：未下载时右上角显示大小标签）。
class StoreGameCard extends StatelessWidget {
  const StoreGameCard({
    super.key,
    required this.descriptor,
    required this.onTap,
  });

  final GameDescriptor descriptor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: descriptor.name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  _GameIcon(descriptor: descriptor),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandDeep,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Text(
                        descriptor.packSizeLabel,
                        style: AppTypography.mini.copyWith(
                          color: AppColors.brandOnPurple,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                descriptor.name,
                style: AppTypography.heading.copyWith(color: AppColors.text1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${descriptor.ageLabel} · 即将上架',
                style: AppTypography.caption.copyWith(color: AppColors.text2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 宫格大图标（≥96px，面性图标 / 透明底角色图）
class _GameIcon extends StatelessWidget {
  const _GameIcon({required this.descriptor});

  final GameDescriptor descriptor;

  @override
  Widget build(BuildContext context) {
    final String? asset = descriptor.iconAsset;
    if (asset != null) {
      return Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.panelBg,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Image.asset(
          asset,
          width: 88,
          height: 88,
          fit: BoxFit.contain,
          errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
            return Icon(
              descriptor.fallbackIcon ?? Icons.toys_rounded,
              size: 48,
              color: AppColors.text2,
            );
          },
        ),
      );
    }
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Icon(
        descriptor.fallbackIcon ?? Icons.toys_rounded,
        size: 48,
        color: AppColors.text2,
      ),
    );
  }
}
