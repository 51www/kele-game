import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// 全局主题：只引用 [AppTokens] 中的 Token（UI 规范 §8.0）。
class AppTheme {
  const AppTheme._();

  static ThemeData child() {
    final ColorScheme scheme = const ColorScheme.light(
      primary: AppColors.btnPrimary,
      onPrimary: AppColors.brandOnPurple,
      secondary: AppColors.brandDeep,
      onSecondary: AppColors.brandOnPurple,
      surface: AppColors.panelBg,
      onSurface: AppColors.text1,
      error: AppColors.error,
      onError: AppColors.brandOnPurple,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      scaffoldBackgroundColor: AppColors.bgPrimaryStart,
      textTheme: const TextTheme(
        displayLarge: AppTypography.display,
        headlineMedium: AppTypography.title,
        titleMedium: AppTypography.heading,
        bodyMedium: AppTypography.body,
        labelSmall: AppTypography.mini,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  /// 家长中心主题：浅底奶油页（UI 规范 §7 家长中心分区）
  static ThemeData parent() {
    return child().copyWith(
      scaffoldBackgroundColor: AppColors.pageBg,
      textTheme: const TextTheme(
        displayLarge: AppTypography.display,
        headlineMedium: AppTypography.title,
        titleMedium: AppTypography.heading,
        bodyMedium: AppTypography.caption,
        labelSmall: AppTypography.mini,
      ),
    );
  }
}

/// 儿童区背景渐变（UI 规范 §1.1 `bg.primary`：#6C5CE7 → #8E7CF3 垂直渐变）
const LinearGradient kChildBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[AppColors.bgPrimaryStart, AppColors.bgPrimaryEnd],
);
