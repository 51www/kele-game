import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 按钮类型（UI 规范 §6.1）
enum AppButtonType { primary, secondary, danger }

/// 按钮尺寸（UI 规范 §6.1：大 64 / 中 56 / 小 48）
enum AppButtonSize { large, medium, small }

/// 全局唯一的按钮实现（UI 规范 §8.0.2：同一语义组件全局只允许一种实现）。
///
/// 签名元素：**糖果厚底按钮**——按下时整体下沉 2px、厚底边同步压缩 2px（UI 规范 §5.2）。
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final IconData? icon;

  /// 是否撑满父容器宽度（弹窗内的大主按钮为 true）
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  double get _height {
    switch (widget.size) {
      case AppButtonSize.large:
        return 64;
      case AppButtonSize.medium:
        return 56;
      case AppButtonSize.small:
        return 48;
    }
  }

  Color get _background {
    switch (widget.type) {
      case AppButtonType.primary:
        return _pressed ? AppColors.btnPrimaryPressed : AppColors.btnPrimary;
      case AppButtonType.secondary:
        return AppColors.panelBg;
      case AppButtonType.danger:
        return AppColors.error;
    }
  }

  Color get _foreground {
    switch (widget.type) {
      case AppButtonType.primary:
      case AppButtonType.danger:
        return AppColors.brandOnPurple;
      case AppButtonType.secondary:
        return AppColors.text1;
    }
  }

  Color get _rim {
    switch (widget.type) {
      case AppButtonType.primary:
        return AppColors.btnPrimaryRim;
      case AppButtonType.secondary:
        return AppColors.btnSecondaryBorder;
      case AppButtonType.danger:
        return AppColors.btnDangerRim;
    }
  }

  /// 次按钮为白底，落在白色面板/弹窗上时上沿与两侧会融进背景，
  /// 故补一圈描边保证完整轮廓；主/危险按钮自身底色对比充分，不加描边。
  Border? get _border {
    if (widget.type != AppButtonType.secondary) return null;
    return Border.all(color: AppColors.btnSecondaryBorder, width: AppStrokes.outline);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final double sink = _pressed && enabled ? 2 : 0;

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.icon != null) ...<Widget>[
          Icon(widget.icon, size: 24, color: enabled ? _foreground : AppColors.brandOnPurple),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.heading.copyWith(
              color: enabled ? _foreground : AppColors.brandOnPurple,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, sink, 0),
          width: widget.expand ? double.infinity : null,
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? _background : AppColors.disabled,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: enabled ? _border : null,
            boxShadow: AppShadows.rim(_rim, offset: AppShadows.rimThick - sink),
          ),
          child: content,
        ),
      ),
    );
  }
}
