import 'engine_definition.dart';

/// 引擎实例 - 用户配置的具体引擎
class EngineInstance {
  final String id;
  final String engineId;
  final String version;
  final EngineInstanceState state;
  final double downloadProgress;
  final DateTime? downloadedAt;
  final String? localPath;
  final String? errorMessage;

  const EngineInstance({
    required this.id,
    required this.engineId,
    required this.version,
    this.state = EngineInstanceState.notDownloaded,
    this.downloadProgress = 0.0,
    this.downloadedAt,
    this.localPath,
    this.errorMessage,
  });

  EngineInstance copyWith({
    String? id,
    String? engineId,
    String? version,
    EngineInstanceState? state,
    double? downloadProgress,
    DateTime? downloadedAt,
    String? localPath,
    String? errorMessage,
  }) {
    return EngineInstance(
      id: id ?? this.id,
      engineId: engineId ?? this.engineId,
      version: version ?? this.version,
      state: state ?? this.state,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      localPath: localPath ?? this.localPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'engineId': engineId,
    'version': version,
    'state': state.name,
    'downloadProgress': downloadProgress,
    'downloadedAt': downloadedAt?.toIso8601String(),
    'localPath': localPath,
    'errorMessage': errorMessage,
  };

  factory EngineInstance.fromJson(Map<String, dynamic> json) => EngineInstance(
    id: json['id'],
    engineId: json['engineId'],
    version: json['version'],
    state: EngineInstanceState.values.firstWhere(
      (e) => e.name == json['state'],
      orElse: () => EngineInstanceState.notDownloaded,
    ),
    downloadProgress: (json['downloadProgress'] ?? 0.0).toDouble(),
    downloadedAt: json['downloadedAt'] != null
        ? DateTime.parse(json['downloadedAt'])
        : null,
    localPath: json['localPath'],
    errorMessage: json['errorMessage'],
  );
}

/// 获取引擎定义的扩展方法
extension EngineInstanceExtension on EngineInstance {
  EngineDefinition? getDefinition(EngineDefinition? Function(String) getById) {
    return getById(engineId);
  }
}
