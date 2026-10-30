import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_toast.dart';
import '../../game_engine/game_registry.dart';
import '../download/download_manager.dart';
import '../download/download_models.dart';
import '../download/unlock_animation.dart';

/// 下载调试开关（M2 验证用）。
///
/// 正常发布版应由 M3 家长门门控；当前里程碑家长中心尚未落地家长门，
/// 故以显式开关暴露「模拟校验失败」调试入口，仅用于验收 MD5 失败分支。
class DownloadDebug {
  DownloadDebug._();

  static bool corruptTestEnabled = false;
}

/// 下载解锁流程底部面板（UI 规范 §7：下载确认 → 进度条 → 星星解锁动画 → 进入游戏）。
///
/// 状态机覆盖：`confirm`(确认) → `queued`(排队) → `connecting/downloading/verifying`(进行)
/// → `unlocked`(解锁动画) / `failed`(失败引导本地导入)。
Future<T?> showDownloadSheet<T>(
  BuildContext context,
  GameDescriptor descriptor, {
  required VoidCallback onPlay,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _DownloadSheetContent(
      descriptor: descriptor,
      onPlay: onPlay,
    ),
  );
}

class _DownloadSheetContent extends StatefulWidget {
  const _DownloadSheetContent({
    required this.descriptor,
    required this.onPlay,
  });

  final GameDescriptor descriptor;
  final VoidCallback onPlay;

  @override
  State<_DownloadSheetContent> createState() => _DownloadSheetContentState();
}

class _DownloadSheetContentState extends State<_DownloadSheetContent> {
  DownloadProgress? _state;
  bool _started = false;
  StreamSubscription<DownloadProgress>? _sub;

  @override
  void initState() {
    super.initState();
    _state = DownloadManager.instance.stateOf(widget.descriptor.id);
    if (_state != null && _state!.isActive) _started = true;
    _sub = DownloadManager.instance
        .watch(widget.descriptor.id)
        .listen(_onProgress);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onProgress(DownloadProgress p) {
    if (!mounted) return;
    setState(() => _state = p);
  }

  void _startDownload({bool corruptTest = false}) {
    setState(() => _started = true);
    if (corruptTest) {
      DownloadManager.instance.enqueueCorruptTest(widget.descriptor);
    } else {
      DownloadManager.instance.enqueue(widget.descriptor);
    }
  }

  void _retry() {
    DownloadManager.instance.enqueue(widget.descriptor);
  }

  void _localImport() {
    DownloadManager.instance.enqueueLocalImport(widget.descriptor);
  }

  void _close() => Navigator.of(context).pop();

  void _play() {
    if (widget.descriptor.comingSoon) {
      // 先用仍挂载的 context 弹 toast，再关闭面板
      showAppToast(context, '还在开发中，敬请期待～');
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop();
    widget.onPlay();
  }

  @override
  Widget build(BuildContext context) {
    final DownloadProgress? state = _state;
    final bool active = state?.isActive ?? false;
    final bool unlocked = state?.phase == DownloadPhase.unlocked;
    final bool failed = state?.phase == DownloadPhase.failed;
    final bool queued = state?.phase == DownloadPhase.queued;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.panelBg,
          borderRadius: BorderRadius.circular(AppRadii.max),
          boxShadow: AppShadows.card,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildHeader(),
              const SizedBox(height: AppSpacing.lg),
              if (!_started || (state == null))
                _buildConfirm()
              else if (queued)
                _buildQueued(state)
              else if (active)
                _buildProgress(state)
              else if (unlocked)
                _buildUnlocked(state)
              else if (failed)
                _buildFailed(state)
              else
                _buildConfirm(),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        // 长按图标 = 调试快捷入口（需家长中心先开启下载调试）
        GestureDetector(
          onLongPress: () {
            if (DownloadDebug.corruptTestEnabled) {
              _startDownload(corruptTest: true);
            }
          },
          child: _GameIcon(descriptor: widget.descriptor),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.descriptor.name,
                style: AppTypography.title.copyWith(color: AppColors.text1),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${widget.descriptor.ageLabel} · ${_packSizeLabel()}',
                style: AppTypography.caption.copyWith(color: AppColors.text2),
              ),
            ],
          ),
        ),
        RoundCloseButton(onPressed: _close),
      ],
    );
  }

  String _packSizeLabel() {
    // 优先用素材包清单声明大小；占位游戏用描述符里的展示值
    return widget.descriptor.packSizeLabel;
  }

  Widget _buildConfirm() {
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.creamBg,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                Icons.cloud_download_rounded,
                size: 40,
                color: AppColors.creamText,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '下载后即可离线畅玩，断网也能玩',
                style: AppTypography.body.copyWith(color: AppColors.creamText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '建议在 Wi-Fi 下下载，或使用离线本地素材包',
                style: AppTypography.caption.copyWith(color: AppColors.creamText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: '下载',
          icon: Icons.download_rounded,
          size: AppButtonSize.medium,
          onPressed: () => _startDownload(),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: '稍后再说',
          type: AppButtonType.secondary,
          size: AppButtonSize.medium,
          onPressed: _close,
        ),
        if (DownloadDebug.corruptTestEnabled) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => _startDownload(corruptTest: true),
            child: Text(
              '（开发者测试）模拟一次校验失败的下载',
              style: AppTypography.caption.copyWith(color: AppColors.text2),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQueued(DownloadProgress state) {
    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        const CircularProgressIndicator(color: AppColors.brandDeep),
        const SizedBox(height: AppSpacing.lg),
        Text(
          state.message,
          style: AppTypography.body.copyWith(color: AppColors.text1),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: '取消',
          type: AppButtonType.secondary,
          size: AppButtonSize.medium,
          onPressed: () {
            DownloadManager.instance.cancel(widget.descriptor.id);
            _close();
          },
        ),
      ],
    );
  }

  Widget _buildProgress(DownloadProgress state) {
    final int percent = (state.progress * 100).round();
    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        _ProgressBar(progress: state.progress),
        const SizedBox(height: AppSpacing.md),
        Text(
          '$percent%',
          style: AppTypography.heading.copyWith(color: AppColors.text1),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          state.message,
          style: AppTypography.caption.copyWith(color: AppColors.text2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: '取消',
          type: AppButtonType.secondary,
          size: AppButtonSize.medium,
          onPressed: () {
            DownloadManager.instance.cancel(widget.descriptor.id);
            _close();
          },
        ),
      ],
    );
  }

  Widget _buildUnlocked(DownloadProgress state) {
    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        StarUnlockAnimation(size: 56),
        const SizedBox(height: AppSpacing.md),
        Text(
          '解锁成功！',
          style: AppTypography.title.copyWith(color: AppColors.text1),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          state.source != null ? '已通过${state.source!.label}获取' : '已解锁',
          style: AppTypography.caption.copyWith(color: AppColors.text2),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: '开始玩',
          icon: Icons.play_arrow_rounded,
          size: AppButtonSize.medium,
          onPressed: _play,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: '回大厅',
          type: AppButtonType.secondary,
          size: AppButtonSize.medium,
          onPressed: _close,
        ),
      ],
    );
  }

  Widget _buildFailed(DownloadProgress state) {
    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: AppColors.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '下载遇到问题',
          style: AppTypography.heading.copyWith(color: AppColors.text1),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          state.message,
          style: AppTypography.caption.copyWith(color: AppColors.text2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.canLocalImport)
          AppButton(
            label: '本地导入',
            icon: Icons.folder_open_rounded,
            size: AppButtonSize.medium,
            onPressed: _localImport,
          ),
        if (state.canLocalImport) const SizedBox(height: AppSpacing.md),
        AppButton(
          label: '重试',
          type: state.canLocalImport ? AppButtonType.secondary : AppButtonType.primary,
          size: AppButtonSize.medium,
          onPressed: _retry,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: '取消',
          type: AppButtonType.secondary,
          size: AppButtonSize.medium,
          onPressed: _close,
        ),
      ],
    );
  }
}

/// 胶囊进度条（UI 规范 §6.4：radius.pill + 柠檬黄填充 + 白底轨道）。
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0, 1),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.tileLemon,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
      ),
    );
  }
}

/// 表头小图标（复用大厅宫格图标风格）。
class _GameIcon extends StatelessWidget {
  const _GameIcon({required this.descriptor});
  final GameDescriptor descriptor;

  @override
  Widget build(BuildContext context) {
    final String? asset = descriptor.iconAsset;
    final Widget placeholder = Icon(
      descriptor.fallbackIcon ?? Icons.toys_rounded,
      size: 32,
      color: AppColors.text2,
    );
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: descriptor.tileColor,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: asset != null
          ? Image.asset(
              asset,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (BuildContext context, Object error, StackTrace? _) => placeholder,
            )
          : placeholder,
    );
  }
}

/// 圆形关闭按钮（复用厚底边图标钮风格）。
class RoundCloseButton extends StatelessWidget {
  const RoundCloseButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: kChildTapTarget,
        height: kChildTapTarget,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brandDeep,
          shape: BoxShape.circle,
          boxShadow: AppShadows.rim(AppColors.brandDeep, offset: AppShadows.rimThin),
        ),
        child: Icon(
          Icons.close_rounded,
          size: 28,
          color: AppColors.brandOnPurple,
        ),
      ),
    );
  }
}
