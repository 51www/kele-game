import 'package:flutter/foundation.dart';

/// 下载源（M2 三级源回退：家庭局域网 → 静态托管 → 本地素材包）。
///
/// 设计要点（计划书 §4.1 / 开发里程碑文档 M2 步骤 4）：
/// - `lan` / `cdn` 为联网源，需家长配置的 HTTP 地址，且**要求仅 Wi-Fi 下使用**；
/// - `local` 为离线兜底（设备目录/已随 App 内置的素材包），无需联网，断网可用；
/// - `simulated` 仅用于调试，模拟「一次损坏的网络下载」以验证 MD5 校验失败分支。
enum PackSource {
  lan('lan', '家庭局域网'),
  cdn('cdn', '静态托管'),
  local('local', '本地素材包'),
  simulated('simulated', '模拟下载源');

  const PackSource(this.id, this.label);

  final String id;
  final String label;

  /// 是否为需要联网的源（用于 Wi-Fi 策略判定）。
  bool get isNetwork =>
      this == PackSource.lan ||
      this == PackSource.cdn ||
      this == PackSource.simulated;
}

/// 下载阶段（开发里程碑文档 M2 验收标准对应）。
enum DownloadPhase {
  /// 排队中（单队列，同时仅 1 个活动下载）
  queued,

  /// 正在连接某个下载源
  connecting,

  /// 下载中（有进度）
  downloading,

  /// MD5 完整性校验中
  verifying,

  /// 解锁成功
  unlocked,

  /// 失败（网络不可用 / MD5 校验失败）
  failed,

  /// 用户取消
  cancelled;
}

/// 单次下载的进度快照（不可变，经 [DownloadManager] 流下发到 UI）。
@immutable
class DownloadProgress {
  const DownloadProgress({
    required this.gameId,
    required this.phase,
    this.progress = 0,
    this.source,
    this.message = '',
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.errorCode,
    this.canLocalImport = false,
    this.queueIndex,
  });

  final String gameId;
  final DownloadPhase phase;

  /// 0~1 下载进度（校验/排队阶段为 0 或 1 的语义值）
  final double progress;

  /// 当前正在使用（或最后使用）的下载源
  final PackSource? source;

  /// 给用户的友好提示
  final String message;

  final int bytesReceived;
  final int totalBytes;

  /// 失败原因码：`NETWORK`（所有源不可用）/ `MD5`（校验失败）/ `CANCELLED`
  final String? errorCode;

  /// 是否可引导「本地导入」重试
  final bool canLocalImport;

  /// 队列位置（从 1 起），仅 [DownloadPhase.queued] 有意义
  final int? queueIndex;

  DownloadProgress copyWith({
    DownloadPhase? phase,
    double? progress,
    PackSource? source,
    String? message,
    int? bytesReceived,
    int? totalBytes,
    String? errorCode,
    bool? canLocalImport,
    int? queueIndex,
  }) {
    return DownloadProgress(
      gameId: gameId,
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      source: source ?? this.source,
      message: message ?? this.message,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      totalBytes: totalBytes ?? this.totalBytes,
      errorCode: errorCode ?? this.errorCode,
      canLocalImport: canLocalImport ?? this.canLocalImport,
      queueIndex: queueIndex ?? this.queueIndex,
    );
  }

  /// 是否处于进行中（占用队列）
  bool get isActive =>
      phase == DownloadPhase.queued ||
      phase == DownloadPhase.connecting ||
      phase == DownloadPhase.downloading ||
      phase == DownloadPhase.verifying;

  /// 是否已结束（成功/失败/取消）
  bool get isDone =>
      phase == DownloadPhase.unlocked ||
      phase == DownloadPhase.failed ||
      phase == DownloadPhase.cancelled;
}

/// 素材包清单（`assets/packs/<gameId>/manifest.json`）。
///
/// `md5` 为 `files` 列表按字典序拼接后的字节流摘要，下载完成后用于完整性校验；
/// `sizeBytes` 为声明包大小，用于商店展示与下载进度模拟。
@immutable
class PackManifest {
  const PackManifest({
    required this.gameId,
    required this.displayName,
    required this.minAge,
    required this.sizeBytes,
    required this.fileCount,
    required this.md5,
    required this.files,
  });

  factory PackManifest.fromJson(Map<String, dynamic> json) {
    return PackManifest(
      gameId: json['gameId'] as String,
      displayName: json['displayName'] as String? ?? json['gameId'] as String,
      minAge: (json['minAge'] as num? ?? 3).toInt(),
      sizeBytes: (json['sizeBytes'] as num? ?? 0).toInt(),
      fileCount: (json['fileCount'] as num? ?? 0).toInt(),
      md5: (json['md5'] as String? ?? ''),
      files: (json['files'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e as String)
          .toList(),
    );
  }

  final String gameId;
  final String displayName;
  final int minAge;
  final int sizeBytes;
  final int fileCount;
  final String md5;
  final List<String> files;

  /// 声明大小的友好文案
  String get sizeLabel {
    final double mb = sizeBytes / 1024 / 1024;
    if (mb <= 0) return '<0.1 MB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'gameId': gameId,
        'displayName': displayName,
        'minAge': minAge,
        'sizeBytes': sizeBytes,
        'fileCount': fileCount,
        'md5': md5,
        'files': files,
      };
}
