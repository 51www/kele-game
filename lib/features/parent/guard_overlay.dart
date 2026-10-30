import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import 'parental_guard.dart';

/// 护眼覆盖层宿主：挂在 MaterialApp.builder 上，位于所有页面（含游戏）之上。
///
/// - [GuardPhase.resting]：强制休息页（眼保健操倒计时，无任何跳过出口）；
/// - [GuardPhase.dailyLocked]：「明天见」锁屏页（到次日自动解除）。
class GuardOverlayHost extends StatelessWidget {
  const GuardOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GuardPhase>(
      valueListenable: ParentalGuard.instance.phase,
      // Navigator（MaterialApp.builder 的 child）作为 child 传入，不随守卫状态重建
      child: child,
      builder: (BuildContext context, GuardPhase phase, Widget? navigator) {
        final Widget content = switch (phase) {
          GuardPhase.resting => const _RestOverlay(),
          GuardPhase.dailyLocked => const _DailyLockOverlay(),
          GuardPhase.playing => const SizedBox.shrink(),
        };
        return Stack(
          children: <Widget>[
            navigator ?? const SizedBox.shrink(),
            // 覆盖层完全遮蔽下层并吞掉所有指针事件（不可穿透、不可跳过）
            if (phase != GuardPhase.playing)
              Positioned.fill(child: ExcludeSemantics(child: content)),
          ],
        );
      },
    );
  }
}

/// 强制休息页（眼保健操 30 秒，不可跳过）
class _RestOverlay extends StatefulWidget {
  const _RestOverlay();

  @override
  State<_RestOverlay> createState() => _RestOverlayState();
}

class _RestOverlayState extends State<_RestOverlay> {
  static const List<String> _steps = <String>[
    '轻轻眨眨眼，放松一下',
    '看看窗外最远的地方',
    '闭上眼睛休息一会儿',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.creamBg,
      child: SafeArea(
        child: Center(
          child: ValueListenableBuilder<int>(
            valueListenable: ParentalGuard.instance.revision,
            builder: (BuildContext context, int _, Widget? _) {
              final int left = ParentalGuard.instance.restSecondsLeft;
              final String step = _steps[
                  ((ParentalGuard.restDurationSeconds - left) ~/ 10)
                      .clamp(0, _steps.length - 1)];
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    'assets/shared/ui/mascot_fox.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (BuildContext c, Object e, StackTrace? s) {
                      return const Icon(
                        Icons.visibility_rounded,
                        size: 96,
                        color: AppColors.creamText,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    '小眼睛休息一下',
                    style: AppTypography.title.copyWith(
                      color: AppColors.creamText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '跟着小狐狸做眼保健操',
                    style: AppTypography.body.copyWith(
                      color: AppColors.creamText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    '$left',
                    style: AppTypography.display.copyWith(
                      color: AppColors.brandDeep,
                      fontSize: 56,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '休息结束前不能继续玩哦',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.creamText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.panelBg,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      step,
                      style: AppTypography.bodyBold.copyWith(
                        color: AppColors.creamText,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 「明天见」锁屏页（每日时长用尽，至次日自动解除）
class _DailyLockOverlay extends StatefulWidget {
  const _DailyLockOverlay();

  @override
  State<_DailyLockOverlay> createState() => _DailyLockOverlayState();
}

class _DailyLockOverlayState extends State<_DailyLockOverlay> {
  @override
  Widget build(BuildContext context) {
    final ParentalGuard guard = ParentalGuard.instance;
    final DateTime now = DateTime.now();
    final String dateText =
        '${now.year} 年 ${now.month} 月 ${now.day} 日';
    return Material(
      color: AppColors.brandDeep,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.nights_stay_rounded,
                size: 96,
                color: AppColors.star,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '明天见！',
                style: AppTypography.display.copyWith(
                  color: AppColors.brandOnPurple,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '今天玩游戏的时间用完啦\n早点休息，明天再来玩吧',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.brandOnPurple,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                dateText,
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandOnPurple,
                ),
              ),
              if (guard.demoMode) ...<Widget>[
                const SizedBox(height: AppSpacing.xxl),
                TextButton(
                  onPressed: () async {
                    await guard.resetToday();
                    if (context.mounted) {
                      setState(() {/* 演示专用：回到 playing 由守卫驱动 */});
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandOnPurple,
                    textStyle: AppTypography.caption,
                    minimumSize: const Size(0, kParentTapTarget),
                  ),
                  child: const Text('（演示）重置今日时长'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 隐藏 / 删除游戏的确认弹窗（家长门通过后调用，构成「二次确认」）。
Future<bool> showGameActionConfirmDialog(
  BuildContext context, {
  required String gameName,
  required String title,
  required String body,
  required String confirmLabel,
  bool danger = false,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: AppColors.brandDeep.withValues(alpha: 0.55),
    builder: (BuildContext context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.panelBg,
          borderRadius: BorderRadius.circular(AppRadii.max),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              danger
                  ? Icons.warning_amber_rounded
                  : Icons.visibility_off_rounded,
              size: 48,
              color: danger ? AppColors.error : AppColors.text2,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.title.copyWith(color: AppColors.text1),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: AppTypography.body.copyWith(color: AppColors.text2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: confirmLabel,
              type: danger ? AppButtonType.danger : AppButtonType.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: '取消',
              type: AppButtonType.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
