/// 引擎分类
enum EngineCategory {
  offline, // 离线模型
  api, // 在线API
}

/// 引擎实例状态
enum EngineInstanceState {
  notDownloaded, // 未下载
  downloading, // 下载中
  downloaded, // 已下载
  loading, // 加载中
  ready, // 可用
  error, // 错误
}

/// 引擎定义 - 引擎的抽象描述
class EngineDefinition {
  final String id;
  final String name;
  final String description;
  final EngineCategory category;
  final String version;
  final List<String> languages;
  final bool isFree;
  final int sizeMB;
  final String? downloadUrl;
  final String? checksum;

  const EngineDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.version,
    required this.languages,
    required this.isFree,
    this.sizeMB = 0,
    this.downloadUrl,
    this.checksum,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category.name,
    'version': version,
    'languages': languages,
    'isFree': isFree,
    'sizeMB': sizeMB,
    'downloadUrl': downloadUrl,
    'checksum': checksum,
  };

  factory EngineDefinition.fromJson(Map<String, dynamic> json) => EngineDefinition(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    category: EngineCategory.values.firstWhere(
      (e) => e.name == json['category'],
      orElse: () => EngineCategory.offline,
    ),
    version: json['version'],
    languages: List<String>.from(json['languages']),
    isFree: json['isFree'] ?? true,
    sizeMB: json['sizeMB'] ?? 0,
    downloadUrl: json['downloadUrl'],
    checksum: json['checksum'],
  );
}
