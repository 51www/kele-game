import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 星级展示（全局唯一实现，UI 规范 §8.0.3）。
///
/// 统一使用面性图标 `Icons.star_rounded`（UI 规范 §6.5：图标只、面性），
/// 未获得的星级用 `neutral.disabled` 表达层级，不引入第二种图标风格。
class StarsRow extends StatelessWidget {
  const StarsRow({
    super.key,
    required this.filled,
    this.total = 3,
    this.size = 20,
  });

  /// 已获得的星数
  final int filled;

  /// 总星数
  final int total;

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(total, (int index) {
        final bool got = index < filled;
        return Icon(
          Icons.star_rounded,
          size: size,
          color: got ? AppColors.star : AppColors.disabled,
        );
      }),
    );
  }
}
