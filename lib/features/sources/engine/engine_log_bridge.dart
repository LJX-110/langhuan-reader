import 'dart:async';

import 'package:flutter/services.dart';

import 'package:langhuan/core/utils/app_log.dart';

/// 阅读内核原生日志 → 应用日志页。
///
/// 引擎侧 `EngineFacade.logSink` 经 EventChannel 批量转发；未监听时原生会
/// 暂存最近 200 行，开始监听后补发。日志只留在本机环形缓冲，不上传。
class EngineLogBridge {
  EngineLogBridge._();

  static const EventChannel _channel = EventChannel('langhuan/engine_log');

  static StreamSubscription<dynamic>? _sub;

  /// 幂等：应用启动时调用一次。
  static void start() {
    if (_sub != null) return;
    _sub = _channel.receiveBroadcastStream().listen(
      (line) {
        if (line is String && line.isNotEmpty) AppLog.i('Engine', line);
      },
      onError: (_) {
        // 桌面/测试环境没有原生实现时静默；不影响书源功能。
      },
    );
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
