import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 全局唯一的 Toast 实现（UI 规范 §6.4：深紫底白字 + `radius.pill`）。
void showAppToast(BuildContext context, String message, {bool isError = false}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(milliseconds: 2200),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.brandDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: isError ? AppColors.errorSoft : AppColors.brandOnPurple,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.brandOnPurple),
            ),
          ),
        ],
      ),
    ),
  );
}
