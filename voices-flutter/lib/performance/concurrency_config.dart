/// 并发配置管理器
/// 支持动态调整线程数以优化性能
class ConcurrencyConfig {
  /// 默认线程数
  static const int defaultNumThreads = 2;

  /// 当前配置的线程数
  final int numThreads;

  /// 是否启用性能监控
  final bool enableMetrics;

  const ConcurrencyConfig({
    this.numThreads = defaultNumThreads,
    this.enableMetrics = false,
  });

  /// 根据设备性能自动选择线程数
  /// 目前返回默认值，未来可扩展为根据 CPU 核心数动态调整
  static ConcurrencyConfig auto() {
    return const ConcurrencyConfig(
      numThreads: defaultNumThreads,
      enableMetrics: true,
    );
  }

  /// 创建指定线程数的配置
  static ConcurrencyConfig withThreads(int threads) {
    return ConcurrencyConfig(
      numThreads: threads.clamp(1, 8),
      enableMetrics: false,
    );
  }

  /// 转换为 sherpa_onnx provider 字符串
  String toProvider() => 'cpu';

  ConcurrencyConfig copyWith({
    int? numThreads,
    bool? enableMetrics,
  }) {
    return ConcurrencyConfig(
      numThreads: numThreads ?? this.numThreads,
      enableMetrics: enableMetrics ?? this.enableMetrics,
    );
  }

  @override
  String toString() =>
      'ConcurrencyConfig(numThreads: $numThreads, enableMetrics: $enableMetrics)';
}
