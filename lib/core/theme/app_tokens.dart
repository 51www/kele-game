/// 《童趣游戏盒》设计 Token —— 严格对应 `docs/UI 设计规范.md` §1~§5。
///
/// UI 规范 §8.0 总则：**任何视觉属性只允许引用本文件的 Token，禁止散落魔法值**。
/// 新增样式请先改 Token，再改组件。
library;

import 'package:flutter/widgets.dart';

/// §1 颜色 Token
class AppColors {
  const AppColors._();

  // §1.1 品牌 / 背景色（儿童区）
  static const Color bgPrimaryStart = Color(0xFF6C5CE7);
  static const Color bgPrimaryEnd = Color(0xFF8E7CF3);
  static const Color brandDeep = Color(0xFF4B3FBF);
  static const Color brandOnPurple = Color(0xFFFFFFFF);
  static const Color creamBg = Color(0xFFF7ECCB);
  static const Color creamText = Color(0xFF8B5E34);
  static const Color panelBg = Color(0xFFFFFFFF);

  // §1.2 马卡龙瓷砖色板（仅限游戏棋子 / 大厅宫格底色 / 装饰，禁止用作按钮或文字色）
  static const Color tileLavender = Color(0xFFB7AEF2);
  static const Color tileLemon = Color(0xFFF7D84A);
  static const Color tileSakura = Color(0xFFF5A8C7);
  static const Color tileMint = Color(0xFF7FD8A4);
  static const Color tileSky = Color(0xFF8FCBF0);
  static const Color tilePeach = Color(0xFFF5B08A);

  // §1.3 语义色（每种语义唯一，禁止挪作装饰）
  static const Color success = Color(0xFF58C27D);
  static const Color successSoft = Color(0xFFE3F6EB);
  static const Color warning = Color(0xFFFFA53B);
  static const Color warningSoft = Color(0xFFFFF1DC);
  static const Color error = Color(0xFFF0544F);
  static const Color errorSoft = Color(0xFFFDE7E6);
  static const Color info = Color(0xFF5AA7F0);
  static const Color infoSoft = Color(0xFFE5F1FD);
  static const Color star = Color(0xFFFFC93C);

  // §1.4 中性色（浅底页面用：家长中心）
  static const Color text1 = Color(0xFF3D3554);
  static const Color text2 = Color(0xFF8A84A3);
  static const Color disabled = Color(0xFFC0BCD4);
  static const Color divider = Color(0xFFECEAF4);
  static const Color pageBg = Color(0xFFFAF7F0);
  static const Color cardBg = Color(0xFFFFFFFF);

  // §1.5 主按钮色（糖果黄橙）
  static const Color btnPrimary = Color(0xFFFFB627);
  static const Color btnPrimaryRim = Color(0xFFE08E00);
  static const Color btnPrimaryPressed = Color(0xFFF0A31C);

  /// 次按钮轮廓色（描边与厚底边同色）。
  ///
  /// 次按钮是白底，落在白色面板/弹窗上时上沿与两侧会与背景融为一体，
  /// 仅靠 `shadow.rim` 只留下一条几乎看不见的浅色底边。故补一圈描边勾出完整轮廓，
  /// 且厚底边取同色，避免出现「深色描边 + 浅色光晕」的双层边。白底对比度 ≈2.9:1。
  static const Color btnSecondaryBorder = Color(0xFF9B93BC);

  static const Color btnDangerRim = Color(0xFFC43A36);
}

/// §2 间距 Token（4px 基数，7 档）
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// 页面水平安全边距（UI 规范 §2：统一 `space.xl`）
  static const double pageHorizontal = xl;
}

/// §3 字体 Token（字号 / 行高 / 字重三件套固定，字重只用 Regular + Bold）
class AppTypography {
  const AppTypography._();

  /// 内置中文字体族（assets/fonts/AppCjk-Regular.ttf，OFL）。
  /// 若字体资产缺失，Flutter 会回退到平台字体；`fontFamilyFallback` 覆盖 Android/iOS 系统中文字体。
  static const String fontFamily = 'AppCjk';
  static const List<String> fontFamilyFallback = <String>[
    'AppCjk',
    'PingFang SC',
    'Noto Sans CJK SC',
    'Microsoft YaHei',
    'sans-serif',
  ];

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle captionBold = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle mini = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w700,
  );
}

/// §4 圆角 Token（梯度：小 ≤ 中 ≤ 大 ≤ 最大）
class AppRadii {
  const AppRadii._();

  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double max = 32;
  static const double pill = 999;
}

/// §4.1 描边宽度 Token（UI 规范 §8.0：禁止散落魔法值）
class AppStrokes {
  const AppStrokes._();

  /// 组件轮廓描边（次按钮 / 白底上的分段控件）
  static const double outline = 2;
}

/// §5 阴影与动效 Token
class AppShadows {
  const AppShadows._();

  /// 小控件厚底边高度（分段控件 / 圆形图标钮）
  static const double rimThin = 3;

  /// 大按钮厚底边高度（UI 规范 §5.1：2~4px，按下时同步压缩）
  static const double rimThick = 4;

  /// §5.1 `shadow.rim`：厚底边（同色系加深），无模糊，用于所有可按压元素
  static List<BoxShadow> rim(Color rimColor, {double offset = rimThick}) => <BoxShadow>[
        BoxShadow(
          color: rimColor,
          offset: Offset(0, offset),
          blurRadius: 0,
        ),
      ];

  /// §5.1 `shadow.card`：`0 6 16 rgba(61,42,84,0.18)`
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x2E3D2A54),
      offset: Offset(0, 6),
      blurRadius: 16,
    ),
  ];
}

class AppMotion {
  const AppMotion._();

  /// §5.2 按压下沉 / 回弹
  static const Duration fast = Duration(milliseconds: 150);

  /// §5.2 弹窗出入、卡片出现
  static const Duration normal = Duration(milliseconds: 250);

  /// §5.2 解锁星星动画、结算星星落下
  static const Duration celebrate = Duration(milliseconds: 800);
}

/// 儿童可点元素最小热区（UI 规范 §2：≥56×56）
const double kChildTapTarget = 56;

/// 家长中心可点元素最小热区（UI 规范 §2：≥44×44）
const double kParentTapTarget = 44;
