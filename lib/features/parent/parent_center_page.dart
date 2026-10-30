import 'package:flutter/material.dart';

import '../../core/storage/progress_store.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/round_icon_button.dart';
import '../../game_engine/game_registry.dart';
import '../download/download_sheet.dart';
import 'guard_overlay.dart';
import 'parent_gate.dart';
import 'parental_guard.dart';

/// 家长中心（里程碑 M3：全部儿童保护规则生效）。
///
/// 视觉分区（UI 规范 §7）：家长中心 = 降饱和奶油底（neutral.pageBg）+ 白卡 +
/// 深紫字，无吉祥物、无动画装饰，信息用 `font.caption` 密排——
/// 与儿童区（深紫渐变 + 高饱和糖果色）明确区分，告知孩子"这不是你玩的地方"。
///
/// 所有写操作（进入本页、隐藏、删除）均先过家长门（算术题 / 长按 3 秒随机轮换）。
class ParentCenterPage extends StatefulWidget {
  const ParentCenterPage({super.key});

  @override
  State<ParentCenterPage> createState() => _ParentCenterPageState();
}

class _ParentCenterPageState extends State<ParentCenterPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: ParentalGuard.instance.revision,
          builder: (BuildContext context, int _, Widget? _) {
            return ValueListenableBuilder<int>(
              valueListenable: ProgressStore.instance.revision,
              builder: (BuildContext context, int _, Widget? _) {
                return _buildContent(context);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        0,
        AppSpacing.pageHorizontal,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        _buildHeader(),
        const SizedBox(height: AppSpacing.lg),
        _buildEyeCard(),
        const SizedBox(height: AppSpacing.lg),
        _buildManageCard(),
        const SizedBox(height: AppSpacing.lg),
        _buildSoundCard(),
        const SizedBox(height: AppSpacing.lg),
        _buildGuardDebugCard(),
        const SizedBox(height: AppSpacing.lg),
        _buildDownloadDebugCard(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.md),
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
    );
  }

  // ── 护眼与每日时长 ─────────────────────────────────────────────────────

  Widget _buildEyeCard() {
    final ParentalGuard guard = ParentalGuard.instance;
    final int limit = guard.dailyLimitMinutes;
    final int usedMinutes = guard.dailySeconds ~/ 60;
    final int continuousMinutes = guard.continuousSeconds ~/ 60;
    return Container(
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
            '护眼与每日时长',
            style: AppTypography.heading.copyWith(color: AppColors.text1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '连续玩 20 分钟会强制休息 30 秒（不可跳过）；'
            '每天玩满上限后锁屏至第二天。',
            style: AppTypography.caption.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '今日已玩 $usedMinutes 分钟 · 连续 $continuousMinutes 分钟 · 上限 $limit 分钟',
            style: AppTypography.captionBold.copyWith(color: AppColors.text1),
          ),
          const SizedBox(height: AppSpacing.sm),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.brandDeep,
              inactiveTrackColor: AppColors.divider,
              thumbColor: AppColors.brandDeep,
              overlayColor: AppColors.brandDeep.withValues(alpha: 0.12),
              trackHeight: 6,
            ),
            child: Slider(
              min: ParentalGuard.minDailyLimitMinutes.toDouble(),
              max: ParentalGuard.maxDailyLimitMinutes.toDouble(),
              divisions: (ParentalGuard.maxDailyLimitMinutes -
                      ParentalGuard.minDailyLimitMinutes) ~/
                  10,
              value: limit.toDouble(),
              label: '$limit 分钟',
              onChanged: (double value) {
                ParentalGuard.instance.setDailyLimit(value.round());
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${ParentalGuard.minDailyLimitMinutes} 分钟',
                style: AppTypography.mini.copyWith(color: AppColors.text2),
              ),
              Text(
                '${ParentalGuard.maxDailyLimitMinutes} 分钟',
                style: AppTypography.mini.copyWith(color: AppColors.text2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 游戏管理（隐藏 / 删除）────────────────────────────────────────────

  Widget _buildManageCard() {
    final List<GameDescriptor> games = GameRegistry.all;
    return Container(
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
            '游戏管理',
            style: AppTypography.heading.copyWith(color: AppColors.text1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '隐藏后大厅不再展示该游戏；删除会清空下载解锁与全部进度。'
            '两个操作都需要先通过家长门。',
            style: AppTypography.caption.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final GameDescriptor descriptor in games)
            _buildGameRow(descriptor),
        ],
      ),
    );
  }

  Widget _buildGameRow(GameDescriptor descriptor) {
    final bool hidden = ProgressStore.instance.isHidden(descriptor.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: descriptor.tileColor,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(
              descriptor.fallbackIcon ?? Icons.toys_rounded,
              size: 22,
              color: AppColors.panelBg,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        descriptor.name,
                        style: AppTypography.captionBold
                            .copyWith(color: AppColors.text1),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hidden) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Text(
                          '已隐藏',
                          style: AppTypography.mini
                              .copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${descriptor.ageLabel} · ${descriptor.packSizeLabel}',
                  style: AppTypography.caption.copyWith(color: AppColors.text2),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          RoundIconButton(
            size: kParentTapTarget,
            icon: hidden
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            semanticLabel: hidden ? '恢复显示' : '隐藏游戏',
            onPressed: () => _toggleHide(descriptor),
          ),
          const SizedBox(width: AppSpacing.sm),
          RoundIconButton(
            size: kParentTapTarget,
            icon: Icons.delete_outline_rounded,
            semanticLabel: '删除游戏',
            onPressed: () => _deleteGame(descriptor),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleHide(GameDescriptor descriptor) async {
    final bool hidden = ProgressStore.instance.isHidden(descriptor.id);
    // 隐藏/恢复均先过家长门（里程碑 M3 验收标准）
    if (!await showParentGate(context)) return;
    if (!mounted) return;
    if (!hidden) {
      final bool confirmed = await showGameActionConfirmDialog(
        context,
        gameName: descriptor.name,
        title: '隐藏「${descriptor.name}」？',
        body: '隐藏后大厅不再展示这个游戏，随时可以在这里恢复显示。',
        confirmLabel: '隐藏',
      );
      if (!confirmed || !mounted) return;
    }
    await ProgressStore.instance.setHidden(descriptor.id, !hidden);
    if (!mounted) return;
    showAppToast(context, hidden ? '已恢复显示' : '已隐藏「${descriptor.name}」');
  }

  Future<void> _deleteGame(GameDescriptor descriptor) async {
    // 家长门 → 危险确认 → 二次确认（里程碑 M3 验收标准）
    if (!await showParentGate(context)) return;
    if (!mounted) return;
    final bool first = await showGameActionConfirmDialog(
      context,
      gameName: descriptor.name,
      title: '删除「${descriptor.name}」？',
      body: '将清空下载的素材包解锁状态与全部游戏进度。',
      confirmLabel: '删除',
      danger: true,
    );
    if (!first || !mounted) return;
    final bool second = await showGameActionConfirmDialog(
      context,
      gameName: descriptor.name,
      title: '确定要删除吗？',
      body: '删除后需要重新下载解锁，星星和最高分都会清空，无法恢复。',
      confirmLabel: '确认删除',
      danger: true,
    );
    if (!second || !mounted) return;
    await ProgressStore.instance.deleteGame(descriptor.id);
    if (!mounted) return;
    showAppToast(context, '已删除「${descriptor.name}」');
  }

  // ── 全局音量 ──────────────────────────────────────────────────────────

  Widget _buildSoundCard() {
    final bool muted = ProgressStore.instance.soundMuted;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '游戏音效',
                  style: AppTypography.heading.copyWith(color: AppColors.text1),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '关闭后全部游戏静音（大厅右上的圆钮也可随时切换）',
                  style: AppTypography.caption.copyWith(color: AppColors.text2),
                ),
              ],
            ),
          ),
          Switch(
            value: !muted,
            activeThumbColor: AppColors.brandDeep,
            onChanged: (bool on) {
              ProgressStore.instance.setSoundMuted(!on);
            },
          ),
        ],
      ),
    );
  }

  // ── 验收调试（M3）─────────────────────────────────────────────────────

  Widget _buildGuardDebugCard() {
    final ParentalGuard guard = ParentalGuard.instance;
    return Container(
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
            '护眼验收调试（M3）',
            style: AppTypography.heading.copyWith(color: AppColors.text1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '开启演示节奏后：连续 20 秒触发休息（真实休息 30 秒不可跳过）、'
            '每日累计 60 秒锁屏「明天见」。仅用于验收，正式版不提供。',
            style: AppTypography.caption.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: guard.demoMode ? '演示节奏：已开启' : '开启演示节奏',
                  type: guard.demoMode
                      ? AppButtonType.secondary
                      : AppButtonType.primary,
                  icon: Icons.speed_rounded,
                  onPressed: () async {
                    await ParentalGuard.instance.setDemoMode(!guard.demoMode);
                    if (!mounted) return;
                    showAppToast(
                      context,
                      guard.demoMode
                          ? '已开启演示节奏（重启页面也生效）'
                          : '已恢复真实节奏',
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: '重置今日护眼',
                  type: AppButtonType.secondary,
                  icon: Icons.restart_alt_rounded,
                  onPressed: () async {
                    await ParentalGuard.instance.resetToday();
                    if (!mounted) return;
                    showAppToast(context, '今日使用与连续计时已清零');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 下载调试（M2 保留；现已在家长门之后，儿童不可触达）─────────────────

  Widget _buildDownloadDebugCard() {
    return Container(
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
            '下载调试（M2 验收）',
            style: AppTypography.heading.copyWith(color: AppColors.text1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '开启后，下载确认面板会出现「模拟校验失败」入口，'
            '用于验收 MD5 校验失败 → 本地导入引导的兜底链路。',
            style: AppTypography.caption.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: DownloadDebug.corruptTestEnabled
                  ? '已开启模拟校验失败'
                  : '开启下载调试',
              type: DownloadDebug.corruptTestEnabled
                  ? AppButtonType.secondary
                  : AppButtonType.primary,
              icon: Icons.bug_report_rounded,
              onPressed: () {
                setState(() {
                  DownloadDebug.corruptTestEnabled = true;
                });
                showAppToast(context, '已开启，可在下载面板里模拟校验失败');
              },
            ),
          ),
        ],
      ),
    );
  }
}
