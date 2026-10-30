import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_toast.dart';

/// 家长门（计划书 §4.4）：进入家长中心与「隐藏 / 删除游戏」操作时触发。
///
/// 两种验证方式**每次随机轮换**，防止儿童（或家长肌肉记忆）背题绕过：
/// - 两位数算术题（13+8 这类），答错自动换题；
/// - 长按 3 秒（松手即重置）。
///
/// 用法：`if (!await showParentGate(context)) return;`
Future<bool> showParentGate(BuildContext context) async {
  final bool? passed = await showDialog<bool>(
    context: context,
    // 允许点遮罩关闭（门的意义是拦住儿童，不是把人困住）；关闭视为未通过
    barrierDismissible: true,
    barrierColor: AppColors.brandDeep.withValues(alpha: 0.55),
    builder: (BuildContext context) => const ParentGateDialog(),
  );
  return passed ?? false;
}

enum _GateMode { math, hold }

/// 验收辅助：URL 显式携带 `?gate=math|hold` 时固定验证方式（仅浏览器验收脚本使用），
/// 未携带时保持随机轮换（默认行为，防背题）。
_GateMode _initialMode() {
  final String? forced = Uri.base.queryParameters['gate'];
  if (forced == 'math') return _GateMode.math;
  if (forced == 'hold') return _GateMode.hold;
  return _nextMode();
}

_GateMode _nextMode() {
  final Random random = Random();
  // 随机轮换：约各占一半，且避免与默认视觉预期形成固定顺序
  return random.nextBool() ? _GateMode.math : _GateMode.hold;
}

class ParentGateDialog extends StatefulWidget {
  const ParentGateDialog({super.key});

  @override
  State<ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<ParentGateDialog> {
  late _GateMode _mode;
  late int _a;
  late int _b;
  late bool _plus;
  String _input = '';

  @override
  void initState() {
    super.initState();
    _mode = _initialMode();
    _newQuestion();
  }

  void _newQuestion() {
    final Random random = Random();
    _a = 10 + random.nextInt(90); // 两位数
    _b = 2 + random.nextInt(18); // 保证不超两位结果
    _plus = random.nextBool();
    if (!_plus && _b > _a) {
      final int tmp = _a;
      _a = _b;
      _b = tmp;
    }
    _input = '';
  }

  int get _answer => _plus ? _a + _b : _a - _b;

  String get _questionText => _plus ? '$_a + $_b' : '$_a − $_b';

  void _switchMode() {
    setState(() {
      _mode = _nextMode();
      if (_mode == _GateMode.math) _newQuestion();
    });
  }

  void _pressDigit(int digit) {
    if (_input.length >= 3) return;
    setState(() => _input = '$_input$digit');
  }

  void _pressBackspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _submit() {
    if (_input.isEmpty) return;
    if (int.parse(_input) == _answer) {
      Navigator.of(context).pop(true);
      return;
    }
    // 答错：提示 + 随机换题（防止试错绕过）
    showAppToast(context, '答案不对，再想一想～', isError: true);
    setState(() => _newQuestion());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.panelBg,
          borderRadius: BorderRadius.circular(AppRadii.max),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '请家长验证',
              style: AppTypography.title.copyWith(color: AppColors.text1),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '这是给爸爸妈妈的专属区域哦',
              style: AppTypography.caption.copyWith(color: AppColors.text2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_mode == _GateMode.math)
              _MathGate(
                questionText: _questionText,
                input: _input,
                onDigit: _pressDigit,
                onBackspace: _pressBackspace,
                onSubmit: _submit,
                onShuffle: () => setState(_newQuestion),
              )
            else
              _HoldGate(
                onPassed: () => Navigator.of(context).pop(true),
                onSwitchMode: _switchMode,
              ),
            if (_mode == _GateMode.math) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: _switchMode,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.text2,
                  textStyle: AppTypography.caption,
                  minimumSize: const Size(0, kParentTapTarget),
                ),
                child: const Text('换成长按 3 秒验证'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 算术题验证：题目 + 数字键盘
class _MathGate extends StatelessWidget {
  const _MathGate({
    required this.questionText,
    required this.input,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    required this.onShuffle,
  });

  final String questionText;
  final String input;
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Column(
            children: <Widget>[
              Text(
                '$questionText = ?',
                style: AppTypography.display.copyWith(color: AppColors.text1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                input.isEmpty ? '请在下面输入答案' : '你输入了：$input',
                style: AppTypography.caption.copyWith(color: AppColors.text2),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Keypad(
          onDigit: onDigit,
          onBackspace: onBackspace,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: '确认',
          size: AppButtonSize.medium,
          onPressed: input.isEmpty ? null : onSubmit,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: onShuffle,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.text2,
            textStyle: AppTypography.caption,
            minimumSize: const Size(0, kParentTapTarget),
          ),
          child: const Text('换一题'),
        ),
      ],
    );
  }
}

/// 数字键盘（3×4：1~9 / 换题占位 / 0 / 退格）
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <List<String?>>[
        <String?>['1', '2', '3'],
        <String?>['4', '5', '6'],
        <String?>['7', '8', '9'],
        <String?>[null, '0', '⌫'],
      ]
          .map((List<String?> row) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: row.map((String? key) {
                    if (key == null) {
                      return const Expanded(child: SizedBox(height: 52));
                    }
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        child: _KeyCap(
                          label: key,
                          onTap: key == '⌫' ? onBackspace : () => onDigit(int.parse(key)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ))
          .toList(),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pageBg,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.heading.copyWith(color: AppColors.text1),
          ),
        ),
      ),
    );
  }
}

/// 长按 3 秒验证：环形进度 + 大圆钮，松手即重置
class _HoldGate extends StatefulWidget {
  const _HoldGate({
    required this.onPassed,
    required this.onSwitchMode,
  });

  final VoidCallback onPassed;
  final VoidCallback onSwitchMode;

  @override
  State<_HoldGate> createState() => _HoldGateState();
}

class _HoldGateState extends State<_HoldGate> {
  static const Duration _holdDuration = Duration(seconds: 3);

  Timer? _timer;
  double _progress = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startHold() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (Timer timer) {
      setState(() {
        _progress = (_progress + 50 / _holdDuration.inMilliseconds).clamp(0.0, 1.0);
      });
      if (_progress >= 1) {
        timer.cancel();
        widget.onPassed();
      }
    });
  }

  void _cancelHold() {
    _timer?.cancel();
    if (_progress > 0) {
      setState(() => _progress = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onLongPressStart: (_) => _startHold(),
          onLongPressEnd: (_) => _cancelHold(),
          onLongPressCancel: _cancelHold,
          child: SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: _progress <= 0 ? null : _progress,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    color: AppColors.brandDeep,
                    backgroundColor: AppColors.divider,
                  ),
                ),
                Container(
                  width: 120,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.pageBg,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _progress <= 0
                        ? '长按 3 秒'
                        : '${(_progress * 100).round()}%',
                    style: AppTypography.heading.copyWith(
                      color: AppColors.text1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '按住圆形按钮不放，坚持 3 秒',
          style: AppTypography.caption.copyWith(color: AppColors.text2),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: widget.onSwitchMode,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.text2,
            textStyle: AppTypography.caption,
            minimumSize: const Size(0, kParentTapTarget),
          ),
          child: const Text('换成算术题验证'),
        ),
      ],
    );
  }
}
