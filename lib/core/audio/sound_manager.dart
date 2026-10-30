import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../storage/progress_store.dart';

/// 全局统一音效管理（计划书 §4.4：全局柔和音效包）。
///
/// 职责：
/// - 统一预加载 `assets/shared/audio/` 下的短音效（OGG）；
/// - 所有播放统一走 `ProgressStore.soundMuted` 静音开关
///   （游戏外壳按钮与家长中心共用同一开关）；
/// - 播放失败只降级为日志，不影响游戏逻辑。
///
/// 素材来源：Kenney Interface Sounds（CC0）。
class SoundManager {
  SoundManager._();

  static final SoundManager instance = SoundManager._();

  /// 与 pubspec.yaml 注册的共享音效目录保持一致
  static const String _prefix = 'assets/shared/audio/';

  static const List<String> _files = <String>[
    'click.ogg', // 通用按钮点击
    'flip.ogg', // 翻牌 / 轻操作
    'match.ogg', // 配对成功
    'wrong.ogg', // 未命中（温和）
    'win.ogg', // 过关 / 结算庆祝
  ];

  bool _initialized = false;

  /// 预加载全部音效；失败不阻塞启动（未加载完成时播放会按需加载）。
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    FlameAudio.updatePrefix(_prefix);
    try {
      await FlameAudio.audioCache.loadAll(_files);
    } catch (error) {
      debugPrint('[SoundManager] 音效预加载失败：$error');
    }
  }

  bool get _enabled => !ProgressStore.instance.soundMuted;

  Future<void> _play(String file, {double volume = 1.0}) async {
    if (!_enabled) return;
    try {
      await FlameAudio.play(file, volume: volume);
    } catch (error) {
      debugPrint('[SoundManager] 播放 $file 失败：$error');
    }
  }

  /// 通用按钮点击音
  void click() => _play('click.ogg', volume: 0.8);

  /// 翻牌 / 轻操作音
  void flip() => _play('flip.ogg');

  /// 配对成功音
  void match() => _play('match.ogg');

  /// 未命中提示音（温和，不刺耳）
  void wrong() => _play('wrong.ogg', volume: 0.6);

  /// 过关庆祝音
  void win() => _play('win.ogg');
}
