import 'dart:collection';

/// 延迟监控指标
class LatencyMetrics {
  /// 首次推理延迟（冷启动）
  final Duration? coldStartLatency;

  /// 最近推理延迟
  final Duration lastLatency;

  /// 平均推理延迟
  final Duration averageLatency;

  /// 总推理次数
  final int inferenceCount;

  /// 最小延迟
  final Duration minLatency;

  /// 最大延迟
  final Duration maxLatency;

  const LatencyMetrics({
    this.coldStartLatency,
    required this.lastLatency,
    required this.averageLatency,
    required this.inferenceCount,
    required this.minLatency,
    required this.maxLatency,
  });

  /// 空指标
  static const empty = LatencyMetrics(
    coldStartLatency: null,
    lastLatency: Duration.zero,
    averageLatency: Duration.zero,
    inferenceCount: 0,
    minLatency: Duration.zero,
    maxLatency: Duration.zero,
  );

  /// 转换为 Map 用于 statusMap
  Map<String, dynamic> toMap() {
    return {
      'coldStartLatencyMs': coldStartLatency?.inMicroseconds ?? 0,
      'lastLatencyMs': lastLatency.inMicroseconds,
      'averageLatencyMs': averageLatency.inMicroseconds,
      'inferenceCount': inferenceCount,
      'minLatencyMs': minLatency.inMicroseconds,
      'maxLatencyMs': maxLatency.inMicroseconds,
    };
  }

  @override
  String toString() =>
      'LatencyMetrics(count: $inferenceCount, avg: ${averageLatency.inMilliseconds}ms, '
      'last: ${lastLatency.inMilliseconds}ms, min: ${minLatency.inMilliseconds}ms, '
      'max: ${maxLatency.inMilliseconds}ms)';
}

/// 延迟跟踪器
/// 使用滑动窗口跟踪推理延迟
class LatencyTracker {
  /// 滑动窗口大小
  static const int windowSize = 100;

  /// 记录延迟的滑动窗口
  final Queue<int> _latencyWindow = Queue<int>();

  /// 是否已完成冷启动（首次推理）
  bool _coldStartRecorded = false;

  /// 首次推理延迟
  int? _coldStartMicros;

  /// 延迟计数器（用于计算平均）
  int _totalMicros = 0;
  int _count = 0;

  /// 最小延迟（微秒）
  int _minMicros = -1;

  /// 最大延迟（微秒）
  int _maxMicros = 0;

  /// 记录一次推理的延迟
  void record(int latencyMicros) {
    // 记录冷启动
    if (!_coldStartRecorded) {
      _coldStartRecorded = true;
      _coldStartMicros = latencyMicros;
    }

    // 更新统计
    _totalMicros += latencyMicros;
    _count++;
    if (_minMicros < 0 || latencyMicros < _minMicros) {
      _minMicros = latencyMicros;
    }
    if (latencyMicros > _maxMicros) {
      _maxMicros = latencyMicros;
    }

    // 维护滑动窗口
    if (_latencyWindow.length >= windowSize) {
      _totalMicros -= _latencyWindow.removeFirst();
    }
    _latencyWindow.addLast(latencyMicros);
  }

  /// 获取当前指标
  LatencyMetrics get metrics {
    if (_count == 0) {
      return LatencyMetrics.empty;
    }

    final avgMicros = _totalMicros ~/ _latencyWindow.length;

    return LatencyMetrics(
      coldStartLatency: _coldStartMicros != null
          ? Duration(microseconds: _coldStartMicros!)
          : null,
      lastLatency: Duration(
          microseconds: _latencyWindow.isNotEmpty ? _latencyWindow.last : 0),
      averageLatency: Duration(microseconds: avgMicros),
      inferenceCount: _count,
      minLatency: Duration(microseconds: _minMicros),
      maxLatency: Duration(microseconds: _maxMicros),
    );
  }

  /// 重置所有指标
  void reset() {
    _latencyWindow.clear();
    _coldStartRecorded = false;
    _coldStartMicros = null;
    _totalMicros = 0;
    _count = 0;
    _minMicros = -1;
    _maxMicros = 0;
  }
}
