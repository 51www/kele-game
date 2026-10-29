import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/round_icon_button.dart';

/// 家长中心占位页（里程碑 M1 仅交付入口；家长门、护眼、时长管理在 M3 落地）。
///
/// 视觉分区（UI 规范 §7）：家长中心 = 降饱和奶油底 + 白卡 + 深紫字，
/// 无吉祥物、无动画装饰，信息用 `font.caption` 密排。
class ParentCenterPage extends StatelessWidget {
  const ParentCenterPage({super.key});

  static const List<(String, String, String)> _features = <(
    String,
    String,
    String,
  )>[
    ('家长门', '两位数算术题 + 长按 3 秒，随机轮换', 'M3 开放'),
    ('护眼计时', '连续玩 20 分钟强制休息 30 秒', 'M3 开放'),
    ('每日时长', '默认 40 分钟，可调 20~120 分钟', 'M3 开放'),
    ('游戏隐藏', '睡前可以藏起兴奋类游戏', 'M3 开放'),
    ('游戏删除', '需家长门 + 二次确认', 'M3 开放'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    semanticLabel: '返回大厅',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '家长中心',
                    style: AppTypography.title.copyWith(color: AppColors.text1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  0,
                  AppSpacing.pageHorizontal,
                  AppSpacing.xxl,
                ),
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
                        Text(
                          '儿童保护设置',
                          style: AppTypography.heading.copyWith(
                            color: AppColors.text1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '下面这些功能会在下一个版本（M3 家长中心）里全部打开，'
                          '现在先带娃玩一局吧。',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.text2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        for (final (String title, String desc, String badge)
                            in _features)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        title,
                                        style: AppTypography.captionBold.copyWith(
                                          color: AppColors.text1,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        desc,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.text2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.divider,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.sm,
                                    ),
                                  ),
                                  child: Text(
                                    badge,
                                    style: AppTypography.mini.copyWith(
                                      color: AppColors.text2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              showAppToast(
                                context,
                                '家长门将在 M3 上线，敬请期待',
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.brandDeep,
                              textStyle: AppTypography.bodyBold,
                              minimumSize: const Size(0, kParentTapTarget),
                            ),
                            child: const Text('知道了'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
