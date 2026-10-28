import 'package:flutter/foundation.dart';

/// 计时埋点（M0，性能定位用，不改任何行为）。
///
/// 只在 debug 或显式打开时输出；release 包里 `enabled` 为 false，
/// 调用处只剩一次布尔判断，不会影响用户可见行为。
///
/// 用法：
/// ```dart
/// final t = PerfLog.start('Read.loadChapter');
/// ... await work ...
/// t.done('idx=3');
/// ```
class PerfLog {
  PerfLog._(this.tag) : _sw = Stopwatch()..start();

  /// `--dart-define=LANGHUAN_PERF=1` 可在 release 里也打开（排查真机问题用）。
  static const bool enabled =
      kDebugMode || bool.fromEnvironment('LANGHUAN_PERF');

  final String tag;
  final Stopwatch _sw;

  static PerfLog start(String tag) => PerfLog._(tag);

  /// 结束并打印 `[Perf] tag 123ms | detail`。
  void done([String detail = '']) {
    if (!enabled) return;
    _sw.stop();
    debugPrint(
      '[Perf] $tag ${_sw.elapsedMilliseconds}ms'
      '${detail.isEmpty ? '' : ' | $detail'}',
    );
  }
}
