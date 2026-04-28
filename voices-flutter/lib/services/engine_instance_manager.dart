import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/engine_definition.dart';
import '../models/engine_instance.dart';

/// 引擎实例管理器
class EngineInstanceManager {
  static final EngineInstanceManager _instance =
      EngineInstanceManager._internal();
  factory EngineInstanceManager() => _instance;
  EngineInstanceManager._internal();

  final _uuid = const Uuid();
  final Map<String, EngineInstance> _instances = {};
  String? _activeInstanceId;

  /// 创建引擎实例
  Future<EngineInstance> createInstance({
    required EngineDefinition engine,
    String? version,
  }) async {
    final id = _uuid.v4();
    final instance = EngineInstance(
      id: id,
      engineId: engine.id,
      version: version ?? engine.version,
    );

    _instances[id] = instance;
    await _saveInstances();
    return instance;
  }

  /// 删除引擎实例
  Future<void> deleteInstance(String id) async {
    if (_activeInstanceId == id) {
      _activeInstanceId = null;
    }
    _instances.remove(id);
    await _saveInstances();
  }

  /// 更新实例状态
  Future<void> updateInstanceState(
    String id, {
    String? version,
    EngineInstanceState? state,
    double? downloadProgress,
    String? localPath,
    String? errorMessage,
  }) async {
    final instance = _instances[id];
    if (instance != null) {
      _instances[id] = instance.copyWith(
        version: version,
        state: state,
        downloadProgress: downloadProgress,
        localPath: localPath,
        errorMessage: errorMessage,
      );
      await _saveInstances();
    }
  }

  /// 获取实例
  EngineInstance? getInstance(String id) => _instances[id];

  /// 列出所有实例
  List<EngineInstance> listInstances() => _instances.values.toList();

  /// 获取当前活跃实例
  EngineInstance? getActiveInstance() {
    if (_activeInstanceId == null) return null;
    return _instances[_activeInstanceId];
  }

  /// 设置当前活跃实例
  Future<void> setActiveInstance(String id) async {
    if (_instances.containsKey(id)) {
      _activeInstanceId = id;
      await _saveInstances();
    }
  }

  /// 加载实例（从本地存储）
  Future<void> loadInstances() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('engine_instances');
    if (data != null) {
      final list = jsonDecode(data) as List;
      for (final item in list) {
        final instance = EngineInstance.fromJson(item);
        _instances[instance.id] = instance;
      }
      _activeInstanceId = prefs.getString('active_instance_id');
    }
  }

  /// 保存实例到本地存储
  Future<void> _saveInstances() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _instances.values.map((i) => i.toJson()).toList();
    await prefs.setString('engine_instances', jsonEncode(list));
    if (_activeInstanceId != null) {
      await prefs.setString('active_instance_id', _activeInstanceId!);
    } else {
      await prefs.remove('active_instance_id');
    }
  }
}
