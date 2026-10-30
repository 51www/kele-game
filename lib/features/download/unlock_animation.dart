import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_tokens.dart';

/// 下载解锁星星动画（UI 规范 §6.4 / §5.2 `motion.celebrate`）。
///
/// 三颗 `semantic.star` 金星星依次落下，呼应统一结算弹窗的得星动效，
/// 制造「获得新游戏」的仪式感（计划书 §2 核心体验规则 2）。
class StarUnlockAnimation extends StatefulWidget {
  const StarUnlockAnimation({super.key, this.size = 56});

  final double size;

  @override
  State<StarUnlockAnimation> createState() => _StarUnlockAnimationState();
}

class _StarUnlockAnimationState extends State<StarUnlockAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.celebrate,
  );

  @override
  void initState() {
    super.initState();
    // 进入即播放一次
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(3, (int index) {
          final Animation<double> animation = CurvedAnimation(
            parent: _controller,
            curve: Interval(
              index * 0.18,
              0.6 + index * 0.18,
              curve: Curves.easeOutBack,
            ),
          );
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) =>
                Transform.scale(scale: animation.value, child: child),
            child: Icon(
              Icons.star_rounded,
              size: widget.size,
              color: AppColors.star,
            ),
          );
        }),
      ),
    );
  }
}
