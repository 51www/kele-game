import 'dart:async';

import 'package:flutter/material.dart';

import '../core/audio/sound_manager.dart';
import '../core/storage/progress_store.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_toast.dart';
import '../core/widgets/round_icon_button.dart';
import '../features/parent/parental_guard.dart';
import 'game_module.dart';
import 'result_dialog.dart';
import 'score_system.dart';

/// 统一游戏外壳（计划书 §4.3：所有游戏共用的返回 / 暂停 / 结算外壳）。
///
/// 职责：
/// - 左上返回圆钮 → **二次确认弹窗**（防误触哭闹）；
/// - 右上暂停 / 声音圆钮；
/// - 监听 `module.resultStream` → **统一结算弹窗**；
/// - 白面板承载游戏画布，画布与 UI 分层（UI 规范 §8.6.4）。
class GameScaffold extends StatefulWidget {
  const GameScaffold({
    super.key,
    required this.module,
    required this.config,
  });

  final GameModule module;
  final GameConfig config;

  @override
  State<GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends State<GameScaffold> {
  StreamSubscription<GameResult>? _subscription;

  bool _ready = false;
  bool _initFailed = false;
  bool _paused = false;
  bool _settling = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.module.resultStream.listen(_handleResult);
    // M3 护眼：护眼休息 / 每日锁屏时由守卫统一冻结 / 恢复游戏（计划书 §4.3 规则 3）
    ParentalGuard.instance.onFreezeGame = _freezeByGuard;
    ParentalGuard.instance.onResumeGame = _resumeByGuard;
    _prepare();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    widget.module.dispose();
    ParentalGuard.instance.onFreezeGame = null;
    ParentalGuard.instance.onResumeGame = null;
    super.dispose();
  }

  void _freezeByGuard() {
    if (!_paused) {
      widget.module.pause();
    }
  }

  void _resumeByGuard() {
    // 仅当不是用户手动暂停时自动恢复
    if (!_paused) {
      widget.module.resume();
    }
  }

  Future<void> _prepare() async {
    setState(() {
      _initFailed = false;
    });
    try {
      await widget.module.init(widget.config);
    } catch (error) {
      debugPrint('[GameScaffold] 游戏初始化失败：$error');
      if (!mounted) return;
      setState(() {
        _initFailed = true;
        _ready = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _ready = true;
    });
  }

  Future<void> _handleResult(GameResult result) async {
    if (_settling) return;
    _settling = true;
    await ScoreSystem.commit(result);
    if (!mounted) {
      _settling = false;
      return;
    }
    final GameResultAction action = await showGameResultDialog(context, result);
    if (!mounted) {
      _settling = false;
      return;
    }
    if (action == GameResultAction.replay) {
      await _prepare();
    } else {
      Navigator.of(context).pop();
    }
    _settling = false;
  }

  Future<void> _handleBack() async {
    final bool exit = await showExitConfirmDialog(context);
    if (exit && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
    });
    if (_paused) {
      widget.module.pause();
    } else {
      widget.module.resume();
    }
  }

  void _toggleSound() {
    final bool muted = !ProgressStore.instance.soundMuted;
    ProgressStore.instance.setSoundMuted(muted);
    // 取消静音后立即给一声反馈，让孩子确认声音已开启
    if (!muted) {
      SoundManager.instance.click();
    }
    showAppToast(
      context,
      muted ? '已静音' : '声音已开启',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: kChildBackgroundGradient),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                _buildTopBar(),
                Expanded(child: _buildGameArea()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            semanticLabel: '返回大厅',
            onPressed: _handleBack,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              widget.module.name,
              style: AppTypography.title.copyWith(color: AppColors.brandOnPurple),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          RoundIconButton(
            icon: ProgressStore.instance.soundMuted
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            semanticLabel: '声音开关',
            onPressed: _toggleSound,
          ),
          const SizedBox(width: AppSpacing.sm),
          RoundIconButton(
            icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            semanticLabel: '暂停',
            onPressed: _togglePause,
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    if (_initFailed) {
      return _buildErrorState();
    }
    if (!_ready) {
      return _buildLoadingState();
    }
    final Widget? hud = widget.module.buildHud(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.panelBg,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  if (hud != null)
                    Padding(
                      // 底部必须预留厚底边（`shadow.rim` 画在布局盒之外）的高度，
                      // 否则紧随其后的画布会在 Column 中更晚绘制、把这圈底边整片盖掉，
                      // 视觉上表现为 HUD 控件下边缘被切平。
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: hud,
                    ),
                  Expanded(
                    child: widget.module.buildGamePage(context),
                  ),
                ],
              ),
              if (_paused) _buildPauseOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(color: AppColors.brandOnPurple),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '游戏加载中…',
            style: AppTypography.body.copyWith(color: AppColors.brandOnPurple),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.panelBg,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.sentiment_dissatisfied_rounded,
                size: 48,
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '游戏没能打开',
                style: AppTypography.heading.copyWith(color: AppColors.text1),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '请再试一次，如果还是不行就回到大厅吧',
                style: AppTypography.caption.copyWith(color: AppColors.text2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: '再试一次',
                size: AppButtonSize.medium,
                onPressed: _prepare,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: '回大厅',
                type: AppButtonType.secondary,
                size: AppButtonSize.medium,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppColors.panelBg.withValues(alpha: 0.92),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.pause_circle_filled_rounded,
              size: 64,
              color: AppColors.brandDeep,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '游戏已暂停',
              style: AppTypography.title.copyWith(color: AppColors.text1),
            ),
            const SizedBox(height: AppSpacing.xl),
            // 与结算弹窗按钮同口径：撑满宽度，两侧留 AppSpacing.xl 空白
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: AppButton(
                label: '继续游戏',
                size: AppButtonSize.medium,
                onPressed: _togglePause,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
