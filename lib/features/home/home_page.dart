import 'package:flutter/material.dart';

import '../../core/storage/progress_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/round_icon_button.dart';
import '../../features/download/download_sheet.dart';
import '../../game_engine/game_registry.dart';
import '../parent/parent_center_page.dart';
import '../parent/parent_gate.dart';
import 'game_tile_card.dart';

/// 游戏大厅（UI 规范 §7：深紫渐变底 +「我的游戏」在前 +「游戏商店」在后 +
/// 家长中心入口置于次要位置并带 🔒）。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kChildBackgroundGradient),
        child: SafeArea(
          child: ValueListenableBuilder<int>(
            valueListenable: ProgressStore.instance.revision,
            builder: (BuildContext context, int revision, Widget? child) {
              return _buildContent(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final List<GameDescriptor> myGames = <GameDescriptor>[];
    final List<GameDescriptor> storeGames = <GameDescriptor>[];
    for (final GameDescriptor descriptor in GameRegistry.all) {
      // M3 家长隐藏：被隐藏的游戏大厅完全不再展示（我的游戏与商店均不出现）
      if (ProgressStore.instance.isHidden(descriptor.id)) continue;
      final bool unlocked = descriptor.builtIn ||
          ProgressStore.instance.progressOf(descriptor.id).unlocked;
      if (unlocked) {
        myGames.add(descriptor);
      } else {
        storeGames.add(descriptor);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        _buildHeader(),
        const SizedBox(height: AppSpacing.xl),
        _buildSectionTitle('我的游戏', myGames.length),
        const SizedBox(height: AppSpacing.md),
        if (myGames.isEmpty)
          _buildEmptyState()
        else
          _buildMyGamesGrid(myGames),
        const SizedBox(height: AppSpacing.xxl),
        _buildSectionTitle('游戏商店', storeGames.length),
        const SizedBox(height: AppSpacing.md),
        _buildStoreGrid(storeGames),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '童趣游戏盒',
                style: AppTypography.title.copyWith(
                  color: AppColors.brandOnPurple,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '和爸爸妈妈一起玩的小游戏',
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandOnPurple,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        RoundIconButton(
          icon: Icons.lock_rounded,
          semanticLabel: '家长中心',
          onPressed: _openParentCenter,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: AppTypography.heading.copyWith(color: AppColors.brandOnPurple),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.brandDeep,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Text(
            '$count',
            style: AppTypography.mini.copyWith(color: AppColors.brandOnPurple),
          ),
        ),
      ],
    );
  }

  Widget _buildMyGamesGrid(List<GameDescriptor> games) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        final double cardHeight = cardWidth * 1.45;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: games.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: cardWidth / cardHeight,
          ),
          itemBuilder: (BuildContext context, int index) {
            final GameDescriptor descriptor = games[index];
            return MyGameCard(
              descriptor: descriptor,
              progress: ProgressStore.instance.progressOf(descriptor.id),
              onTap: () => _openGame(descriptor),
            );
          },
        );
      },
    );
  }

  Widget _buildStoreGrid(List<GameDescriptor> games) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        final double cardHeight = cardWidth * 1.28;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: games.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: cardWidth / cardHeight,
          ),
          itemBuilder: (BuildContext context, int index) {
            final GameDescriptor descriptor = games[index];
            return StoreGameCard(
              descriptor: descriptor,
              onTap: () {
                showDownloadSheet(
                  context,
                  descriptor,
                  onPlay: () => _openGame(descriptor),
                );
              },
            );
          },
        );
      },
    );
  }

  /// 空状态（UI 规范 §7：吉祥物 + 提示 + 主按钮跳商店）
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.creamBg,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        children: <Widget>[
          Image.asset(
            'assets/shared/ui/mascot_fox.png',
            width: 96,
            height: 96,
            fit: BoxFit.contain,
            errorBuilder: (BuildContext context, Object error, StackTrace? s) {
              return const Icon(
                Icons.pets_rounded,
                size: 64,
                color: AppColors.creamText,
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '还没有游戏，去商店看看吧',
            style: AppTypography.heading.copyWith(color: AppColors.creamText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: '去商店',
            size: AppButtonSize.medium,
            expand: false,
            onPressed: () {
              // 商店在同页下方，滚动过去即可
              showAppToast(context, '商店就在下面哦');
            },
          ),
        ],
      ),
    );
  }

  void _openGame(GameDescriptor descriptor) {
    if (descriptor.comingSoon) {
      showAppToast(context, '还在开发中，敬请期待～');
      return;
    }
    Navigator.of(context).pushNamed('/game/${descriptor.id}');
  }

  /// 家长中心入口：先过家长门（算术题 / 长按 3 秒随机轮换），通过后才进入
  Future<void> _openParentCenter() async {
    final bool passed = await showParentGate(context);
    if (!passed || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const ParentCenterPage(),
      ),
    );
  }
}
