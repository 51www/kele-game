import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../core/widgets/app_button.dart';
import 'game_module.dart';

/// 统一结算弹窗出口动作（UI 规范 §6.3：两个大主按钮「再玩一次 / 回大厅」）
enum GameResultAction { replay, home }

/// 统一结算弹窗（计划书 §4.3 强制规则 1：所有游戏共用，禁止自造结算页）。
///
/// 视觉：白面板 + `radius.max` + 顶部三颗星星（`motion.celebrate` 落下）+ 分数 + 两个大按钮。
Future<GameResultAction> showGameResultDialog(
  BuildContext context,
  GameResult result,
) async {
  final GameResultAction? action = await showDialog<GameResultAction>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.brandDeep.withValues(alpha: 0.55),
    builder: (BuildContext context) => _ResultDialog(result: result),
  );
  return action ?? GameResultAction.home;
}

/// 返回二次确认弹窗（计划书 §4.3 强制规则 2：游戏内返回必须二次确认）。
///
/// 「继续玩」为主按钮，「退出」为次按钮（UI 规范 §6.3：主次分明，防误触哭闹）。
Future<bool> showExitConfirmDialog(BuildContext context) async {
  final bool? exit = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: AppColors.brandDeep.withValues(alpha: 0.55),
    builder: (BuildContext context) => const _ExitConfirmDialog(),
  );
  return exit ?? false;
}

/// 弹窗统一底板（白面板 + `radius.max` + `shadow.card`）
class _AppDialogPanel extends StatelessWidget {
  const _AppDialogPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.panelBg,
          borderRadius: BorderRadius.circular(AppRadii.max),
          boxShadow: AppShadows.card,
        ),
        child: child,
      ),
    );
  }
}

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({required this.result});

  final GameResult result;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.celebrate,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.result.stars >= 3) return '太棒啦！';
    if (widget.result.stars == 2) return '真不错！';
    return '继续加油！';
  }

  String get _durationText {
    final int seconds = widget.result.duration.inSeconds;
    final String mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final String ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  List<String> get _metricParts {
    final List<String> parts = <String>['用时 $_durationText'];
    final Object? steps = widget.result.metrics['steps'];
    if (steps != null) parts.add('$steps 步');
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: _AppDialogPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 星星（motion.celebrate 依次落下）
            SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(3, (int index) {
                  final Animation<double> animation = CurvedAnimation(
                    parent: _controller,
                    curve: Interval(
                      index * 0.18,
                      0.6 + index * 0.18,
                      curve: Curves.easeOutBack,
                    ),
                  );
                  final bool got = index < widget.result.stars;
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (BuildContext context, Widget? child) {
                      return Transform.scale(
                        scale: animation.value,
                        child: child,
                      );
                    },
                    child: Icon(
                      Icons.star_rounded,
                      size: 48,
                      color: got ? AppColors.star : AppColors.disabled,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _title,
              style: AppTypography.title.copyWith(color: AppColors.text1),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${widget.result.score} 分',
              style: AppTypography.display.copyWith(color: AppColors.brandDeep),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _metricParts.join(' · '),
              style: AppTypography.body.copyWith(color: AppColors.text2),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: '再玩一次',
              icon: Icons.refresh_rounded,
              onPressed: () => Navigator.of(context).pop(GameResultAction.replay),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: '回大厅',
              type: AppButtonType.secondary,
              onPressed: () => Navigator.of(context).pop(GameResultAction.home),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExitConfirmDialog extends StatelessWidget {
  const _ExitConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: _AppDialogPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '要退出游戏吗？',
              style: AppTypography.title.copyWith(color: AppColors.text1),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '退出后这一局的成绩不会保存哦',
              style: AppTypography.body.copyWith(color: AppColors.text2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: '继续玩',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: '退出',
              type: AppButtonType.secondary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
