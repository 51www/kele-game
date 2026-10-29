import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 圆形图标按钮（UI 规范 §6.1「图标圆钮」：紫底 + 白图标 + 圆形 + `shadow.rim`）。
///
/// 用于游戏内的返回 / 暂停 / 声音按钮，触控热区 ≥56px（AGENT.md §1.1）。
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = kChildTapTarget,
    this.backgroundColor = AppColors.brandDeep,
    this.foregroundColor = AppColors.brandOnPurple,
    this.rimColor = AppColors.brandDeep,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color rimColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? backgroundColor : AppColors.disabled,
            shape: BoxShape.circle,
            boxShadow: AppShadows.rim(rimColor, offset: AppShadows.rimThin),
          ),
          child: Icon(
            icon,
            size: size * 0.5,
            color: enabled ? foregroundColor : AppColors.brandOnPurple,
          ),
        ),
      ),
    );
  }
}
