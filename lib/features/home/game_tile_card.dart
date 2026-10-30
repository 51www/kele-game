import 'package:flutter/material.dart';

import '../../core/storage/game_progress.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/stars_row.dart';
import '../../features/download/download_manager.dart';
import '../../features/download/download_models.dart';
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
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      descriptor.name,
                      style:
                          AppTypography.heading.copyWith(color: AppColors.text1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (descriptor.comingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Text(
                        '即将上架',
                        style: AppTypography.mini
                            .copyWith(color: AppColors.text2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              StarsRow(filled: progress.bestStars, size: 18),
              const SizedBox(height: AppSpacing.xs),
              Text(
                progress.hasPlayed ? '最高 ${progress.bestScore} 分' : '还没有玩过',
                style:
                    AppTypography.caption.copyWith(color: AppColors.text2),
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
///
/// 点击打开下载解锁流程；若当前正在下载该游戏，叠加进度条反馈（单队列进度可见）。
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
    return StreamBuilder<DownloadProgress>(
      stream: DownloadManager.instance.watch(descriptor.id),
      builder: (BuildContext context, AsyncSnapshot<DownloadProgress> snapshot) {
        final DownloadProgress? state = snapshot.data;
        final bool active = state?.isActive ?? false;
        return Semantics(
          button: true,
          label: '${descriptor.name} 下载',
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: <Widget>[
                Container(
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
                          _GameIcon(
                            descriptor: descriptor,
                            containerColor: descriptor.tileColor,
                          ),
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
                                style: AppTypography.mini
                                    .copyWith(color: AppColors.brandOnPurple),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        descriptor.name,
                        style: AppTypography.heading
                            .copyWith(color: AppColors.text1),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.download_rounded,
                            size: 16,
                            color: AppColors.brandDeep,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              '点击下载 · ${descriptor.ageLabel}',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.text2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (active)
                  Positioned.fill(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.panelBg,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _MiniProgress(progress: state!.progress),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            state.phase == DownloadPhase.queued
                                ? (state.queueIndex != null
                                    ? '排队中（第 ${state.queueIndex} 位）'
                                    : '排队中')
                                : '${(state.progress * 100).round()}%',
                            style: AppTypography.bodyBold
                                .copyWith(color: AppColors.text1),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 宫格大图标（≥96px，面性图标 / 透明底角色图）
class _GameIcon extends StatelessWidget {
  const _GameIcon({
    required this.descriptor,
    this.containerColor,
  });

  final GameDescriptor descriptor;

  /// 图标容器底色；缺省为面板白（我的游戏卡与卡底同色时改传瓷砖色）
  final Color? containerColor;

  @override
  Widget build(BuildContext context) {
    final Color boxColor = containerColor ?? AppColors.panelBg;
    final String? asset = descriptor.iconAsset;
    if (asset != null) {
      return Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Image.asset(
          asset,
          width: 88,
          height: 88,
          fit: BoxFit.contain,
          errorBuilder: (BuildContext context, Object error, StackTrace? _) {
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
        color: boxColor,
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

/// 商店卡下载进度迷你条（柠檬黄填充 + 白底轨道）
class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0, 1),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.tileLemon,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
      ),
    );
  }
}
