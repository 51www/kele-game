import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/storage/progress_store.dart';
import '../../game_engine/game_registry.dart';
import 'download_models.dart';

/// 队列条目。
class _QueueItem {
  const _QueueItem(this.descriptor, this.sourcesOverride);
  final GameDescriptor descriptor;
  final List<PackSource>? sourcesOverride;
}

/// 下载管理器（M2：M-Down 模块，B-1 素材包解锁）。
///
/// 硬约束（开发里程碑文档 M2 验收标准）：
/// - **单队列**：同时仅 1 个活动下载，其余排队，绝不并发；
/// - **三级源回退**：局域网 → 静态托管 → 本地素材包；
/// - **MD5 校验**：下载后校验完整性，失败引导「本地导入」；
/// - **离线可用**：本地素材包/本地导入无需联网，断网也能解锁。
class DownloadManager {
  DownloadManager._();

  static final DownloadManager instance = DownloadManager._();

  /// 局域网源基础地址（家长在家庭 NAS / 旧电脑上配置；默认空 = 不可用）
  String lanBaseUrl = '';

  /// 静态托管直链基础地址（对象存储 / GitHub Pages；默认空 = 不可用）
  String cdnBaseUrl = '';

  final Map<String, DownloadProgress> _states = <String, DownloadProgress>{};
  final StreamController<DownloadProgress> _global =
      StreamController<DownloadProgress>.broadcast();
  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);
  final List<_QueueItem> _queue = <_QueueItem>[];
  final Set<String> _cancelled = <String>{};
  String? _activeId;

  /// 是否正在下载（活动任务存在）
  bool get hasActive => _activeId != null;

  /// 当前活动下载的游戏 id
  String? get activeId => _activeId;

  /// 某游戏当前下载进度（无则返回 null）
  DownloadProgress? stateOf(String gameId) => _states[gameId];

  /// 订阅某游戏的下载进度流（立即下发当前值，随后增量更新）
  Stream<DownloadProgress> watch(String gameId) {
    final DownloadProgress? current = _states[gameId];
    final Stream<DownloadProgress> filtered =
        _global.stream.where((DownloadProgress p) => p.gameId == gameId);
    if (current == null) return filtered;
    return Stream<DownloadProgress>.fromIterable(<DownloadProgress>[current])
        .asyncExpand((_) => filtered);
  }

  /// 入队下载（自动选择三级源）。
  void enqueue(GameDescriptor descriptor) =>
      _enqueue(descriptor, sourcesOverride: null);

  /// 入队并强制仅用「本地素材包」源（用于「本地导入」重试）。
  void enqueueLocalImport(GameDescriptor descriptor) =>
      _enqueue(descriptor, sourcesOverride: const <PackSource>[PackSource.local]);

  /// 调试：模拟一次「损坏的网络下载」以验证 MD5 校验失败分支。
  void enqueueCorruptTest(GameDescriptor descriptor) => _enqueue(
        descriptor,
        sourcesOverride: const <PackSource>[
          PackSource.simulated,
          PackSource.local,
        ],
      );

  void _enqueue(
    GameDescriptor descriptor, {
    required List<PackSource>? sourcesOverride,
  }) {
    final String id = descriptor.id;
    if (ProgressStore.instance.progressOf(id).unlocked) return;
    if (_activeId == id) return;
    if (_queue.any((_QueueItem q) => q.descriptor.id == id)) return;
    _cancelled.remove(id);
    _queue.add(_QueueItem(descriptor, sourcesOverride));
    _pump();
  }

  /// 取消某游戏的下载（活动任务会在下一个检查点安全退出）
  void cancel(String gameId) {
    _queue.removeWhere((_QueueItem q) => q.descriptor.id == gameId);
    if (_activeId == gameId) {
      _cancelled.add(gameId);
    } else {
      _states.remove(gameId);
    }
  }

  void _pump() {
    if (_activeId != null) {
      _refreshQueuePositions();
      return;
    }
    if (_queue.isEmpty) return;
    final _QueueItem item = _queue.removeAt(0);
    _activeId = item.descriptor.id;
    _refreshQueuePositions();
    _process(item);
  }

  void _refreshQueuePositions() {
    for (int i = 0; i < _queue.length; i++) {
      final _QueueItem item = _queue[i];
      emit(
        item.descriptor.id,
        DownloadProgress(
          gameId: item.descriptor.id,
          phase: DownloadPhase.queued,
          queueIndex: i + 1,
          message: '已加入下载队列，排队中（第 ${i + 1} 位）',
        ),
      );
    }
  }

  void _dequeue(String gameId) {
    _cancelled.remove(gameId);
    if (_activeId == gameId) _activeId = null;
    _pump();
  }

  void emit(String gameId, DownloadProgress p) {
    _states[gameId] = p;
    if (!_global.isClosed) _global.add(p);
    changeNotifier.value++;
  }

  Future<PackManifest> _loadManifest(String gameId) async {
    final String data =
        await rootBundle.loadString('assets/packs/$gameId/manifest.json');
    return PackManifest.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<void> _process(_QueueItem item) async {
    final GameDescriptor descriptor = item.descriptor;
    final String gameId = descriptor.id;
    if (_cancelled.contains(gameId)) {
      _dequeue(gameId);
      return;
    }
    final PackManifest manifest;
    try {
      manifest = await _loadManifest(gameId);
    } catch (error) {
      emit(
        gameId,
        DownloadProgress(
          gameId: gameId,
          phase: DownloadPhase.failed,
          errorCode: 'NETWORK',
          canLocalImport: true,
          message: '素材包清单读取失败，请尝试本地导入',
        ),
      );
      _dequeue(gameId);
      return;
    }

    final List<PackSource> sources = item.sourcesOverride ??
        const <PackSource>[
          PackSource.lan,
          PackSource.cdn,
          PackSource.local,
        ];

    Uint8List? bytes;
    PackSource? usedSource;
    final bool corrupt = item.sourcesOverride != null &&
        item.sourcesOverride!.contains(PackSource.simulated);

    for (final PackSource src in sources) {
      if (_cancelled.contains(gameId)) {
        emit(
          gameId,
          DownloadProgress(
            gameId: gameId,
            phase: DownloadPhase.cancelled,
            message: '已取消下载',
          ),
        );
        _dequeue(gameId);
        return;
      }
      emit(
        gameId,
        DownloadProgress(
          gameId: gameId,
          phase: DownloadPhase.connecting,
          source: src,
          message: '正在连接 ${src.label}…',
          progress: 0,
        ),
      );
      final Uint8List? b = await _runSource(
        src,
        manifest,
        corrupt && src == PackSource.simulated,
        (DownloadProgress p) => emit(gameId, p),
      );
      if (b != null) {
        bytes = b;
        usedSource = src;
        break;
      }
      emit(
        gameId,
        DownloadProgress(
          gameId: gameId,
          phase: DownloadPhase.connecting,
          source: src,
          message: '${src.label} 暂不可用，尝试下一个下载源…',
          progress: 0,
        ),
      );
    }

    if (bytes == null) {
      emit(
        gameId,
        DownloadProgress(
          gameId: gameId,
          phase: DownloadPhase.failed,
          errorCode: 'NETWORK',
          canLocalImport: true,
          message: '所有下载源均暂不可用，请改用「本地导入」',
        ),
      );
      _dequeue(gameId);
      return;
    }

    if (_cancelled.contains(gameId)) {
      emit(
        gameId,
        DownloadProgress(
          gameId: gameId,
          phase: DownloadPhase.cancelled,
          message: '已取消下载',
        ),
      );
      _dequeue(gameId);
      return;
    }

    emit(
      gameId,
      DownloadProgress(
        gameId: gameId,
        phase: DownloadPhase.verifying,
        source: usedSource,
        progress: 1,
        message: '正在校验素材包完整性…',
      ),
    );

    final String got = crypto.md5.convert(bytes).toString();
    if (got != manifest.md5) {
      emit(
        gameId,
        DownloadProgress(
          gameId: gameId,
          phase: DownloadPhase.failed,
          errorCode: 'MD5',
          source: usedSource,
          canLocalImport: true,
          message: '素材包校验失败（可能下载不完整或已损坏），请尝试本地导入',
        ),
      );
      _dequeue(gameId);
      return;
    }

    await ProgressStore.instance.markUnlocked(gameId);
    emit(
      gameId,
      DownloadProgress(
        gameId: gameId,
        phase: DownloadPhase.unlocked,
        source: usedSource,
        progress: 1,
        message: '解锁成功！',
      ),
    );
    _dequeue(gameId);
  }

  Future<Uint8List?> _runSource(
    PackSource src,
    PackManifest manifest,
    bool corrupt,
    void Function(DownloadProgress) emit,
  ) async {
    switch (src) {
      case PackSource.lan:
      case PackSource.cdn:
        return _runNetwork(src, manifest, emit);
      case PackSource.local:
        return _runLocal(manifest, emit);
      case PackSource.simulated:
        return _runSimulated(manifest, emit);
    }
  }

  Future<Uint8List?> _runNetwork(
    PackSource src,
    PackManifest manifest,
    void Function(DownloadProgress) emit,
  ) async {
    final String url = src == PackSource.lan ? lanBaseUrl : cdnBaseUrl;
    if (url.isEmpty) return null; // 未配置 → 该源不可用，回退下一源
    emit(
      DownloadProgress(
        gameId: manifest.gameId,
        phase: DownloadPhase.connecting,
        source: src,
        message: '正在从 ${src.label} 下载…',
      ),
    );
    try {
      final http.Response resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final Uint8List body = resp.bodyBytes;
      await _pace(
        body.length,
        (double p, int br) => emit(
          DownloadProgress(
            gameId: manifest.gameId,
            phase: DownloadPhase.downloading,
            source: src,
            progress: p,
            bytesReceived: br,
            totalBytes: body.length,
            message: '正在从 ${src.label} 下载…',
          ),
        ),
      );
      return body;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _runLocal(
    PackManifest manifest,
    void Function(DownloadProgress) emit,
  ) async {
    emit(
      DownloadProgress(
        gameId: manifest.gameId,
        phase: DownloadPhase.connecting,
        source: PackSource.local,
        message: '正在读取本地素材包…',
      ),
    );
    final List<int> all = <int>[];
    for (final String file in manifest.files) {
      final ByteData data = await rootBundle.load(file);
      all.addAll(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    // 占位游戏素材清单为空，用声明的展示大小模拟进度
    final int total =
        all.isEmpty ? math.max(manifest.sizeBytes, 1) : all.length;
    await _pace(
      total,
      (double p, int br) => emit(
        DownloadProgress(
          gameId: manifest.gameId,
          phase: DownloadPhase.downloading,
          source: PackSource.local,
          progress: p,
          bytesReceived: br,
          totalBytes: total,
          message: '正在从 本地素材包 获取…',
        ),
      ),
    );
    return Uint8List.fromList(all);
  }

  Future<Uint8List?> _runSimulated(
    PackManifest manifest,
    void Function(DownloadProgress) emit,
  ) async {
    emit(
      DownloadProgress(
        gameId: manifest.gameId,
        phase: DownloadPhase.connecting,
        source: PackSource.simulated,
        message: '正在从 模拟下载源 下载…',
      ),
    );
    final int size = math.max(manifest.sizeBytes, 300 * 1024);
    final Uint8List bytes = Uint8List(size);
    // 与真实内容无关的伪随机填充，必然使 MD5 校验失败
    for (int i = 0; i < size; i++) {
      bytes[i] = (i * 31 + 7) & 0xFF;
    }
    await _pace(
      size,
      (double p, int br) => emit(
        DownloadProgress(
          gameId: manifest.gameId,
          phase: DownloadPhase.downloading,
          source: PackSource.simulated,
          progress: p,
          bytesReceived: br,
          totalBytes: size,
          message: '正在从 模拟下载源 下载…',
        ),
      ),
    );
    return bytes;
  }

  /// 把 0→1 的进度分成若干步并加入人为延迟，制造可观察的下载动画。
  Future<void> _pace(int total, void Function(double p, int br) tick) async {
    const int steps = 60;
    for (int i = 1; i <= steps; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final double p = i / steps;
      tick(p, (total * p).round());
    }
  }
}
