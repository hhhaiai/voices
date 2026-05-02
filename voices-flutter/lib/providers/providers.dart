import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/engine_definition.dart';
import '../models/engine_instance.dart';
import '../services/transcription_service.dart';
import '../services/engine_instance_manager.dart';
import '../services/model_download_manager.dart';
import '../models/model_registry.dart';

/// 模型下载管理器 Provider
final modelDownloadManagerProvider = Provider<ModelDownloadManager>((ref) {
  return ModelDownloadManager();
});

/// 已下载的引擎列表 - 内置模型默认已下载
final downloadedEnginesProvider = Provider<Map<String, bool>>((ref) {
  return {
    'whisper': true,
    'vosk': true,
    'sensevoice_onnx': true,
  };
});

/// 已下载模型列表（来自本地 models 目录）
final downloadedModelsListProvider =
    FutureProvider<List<ModelDownloadInfo>>((ref) async {
  final manager = ref.watch(modelDownloadManagerProvider);
  return manager.getDownloadedModels();
});

enum ModelDownloadStatus {
  idle,
  downloading,
  success,
  error,
}

class ModelDownloadItemState {
  final ModelDownloadStatus status;
  final double progress;
  final String? errorMessage;

  const ModelDownloadItemState({
    this.status = ModelDownloadStatus.idle,
    this.progress = 0.0,
    this.errorMessage,
  });

  ModelDownloadItemState copyWith({
    ModelDownloadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return ModelDownloadItemState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
    );
  }
}

class ModelDownloadState {
  final Map<String, ModelDownloadItemState> items;

  const ModelDownloadState({this.items = const {}});

  ModelDownloadItemState itemFor(String engineId, String version) {
    return items[_key(engineId, version)] ?? const ModelDownloadItemState();
  }

  ModelDownloadState put(
    String engineId,
    String version,
    ModelDownloadItemState value,
  ) {
    final next = Map<String, ModelDownloadItemState>.from(items)
      ..[_key(engineId, version)] = value;
    return ModelDownloadState(items: next);
  }

  ModelDownloadState remove(String engineId, String version) {
    final next = Map<String, ModelDownloadItemState>.from(items)
      ..remove(_key(engineId, version));
    return ModelDownloadState(items: next);
  }

  static String _key(String engineId, String version) => '$engineId::$version';
}

final modelDownloadStateProvider =
    StateNotifierProvider<ModelDownloadNotifier, ModelDownloadState>((ref) {
  return ModelDownloadNotifier(ref);
});

class ModelDownloadNotifier extends StateNotifier<ModelDownloadState> {
  final Ref _ref;

  ModelDownloadNotifier(this._ref) : super(const ModelDownloadState());

  Future<void> downloadModel({
    required EngineDefinition engine,
    required DownloadableModelDefinition model,
  }) async {
    state = state.put(
      engine.id,
      model.version,
      const ModelDownloadItemState(
        status: ModelDownloadStatus.downloading,
        progress: 0.0,
      ),
    );

    final manager = _ref.read(modelDownloadManagerProvider);

    try {
      await manager.downloadModel(
        engine: engine,
        version: model.version,
        downloadUrl: model.downloadUrl,
        extraDownloadUrls: model.extraDownloadUrls,
        allowedHosts: model.allowedHosts,
        expectedSha256: model.sha256,
        onProgress: (progress) {
          state = state.put(
            engine.id,
            model.version,
            ModelDownloadItemState(
              status: ModelDownloadStatus.downloading,
              progress: progress,
            ),
          );
        },
      );

      state = state.put(
        engine.id,
        model.version,
        const ModelDownloadItemState(
          status: ModelDownloadStatus.success,
          progress: 1.0,
        ),
      );
      _ref.invalidate(downloadedModelsListProvider);
    } catch (e) {
      state = state.put(
        engine.id,
        model.version,
        ModelDownloadItemState(
          status: ModelDownloadStatus.error,
          progress: 0.0,
          errorMessage: e.toString(),
        ),
      );
      _ref.invalidate(downloadedModelsListProvider);
      rethrow;
    }
  }

  Future<void> deleteDownloadedModel({
    required String engineId,
    required String version,
  }) async {
    final manager = _ref.read(modelDownloadManagerProvider);
    await manager.deleteModel(engineId, version);
    state = state.remove(engineId, version);
    _ref.invalidate(downloadedModelsListProvider);
  }

  void clearState({required String engineId, required String version}) {
    state = state.remove(engineId, version);
  }
}

/// 引擎列表 Provider
final engineListProvider = Provider<List<EngineDefinition>>((ref) {
  return const [
    EngineDefinition(
      id: 'whisper',
      name: 'Whisper Tiny (内置)',
      description: '内置 Whisper tiny 量化模型，离线转写优先推荐',
      category: EngineCategory.offline,
      version: '1.0.0',
      languages: ['zh', 'en', 'ja', 'ko', 'es', 'fr', 'de'],
      isFree: true,
      sizeMB: 75,
    ),
    EngineDefinition(
      id: 'vosk',
      name: 'Vosk (内置)',
      description: '内置离线语音识别模型，直接在手机本地运行',
      category: EngineCategory.offline,
      version: '1.0.0',
      languages: ['zh-cn', 'en-us'],
      isFree: true,
      sizeMB: 50,
    ),
    EngineDefinition(
      id: 'sensevoice_onnx',
      name: 'SenseVoice ONNX',
      description: 'SenseVoice ONNX 引擎（需配置本地模型路径）',
      category: EngineCategory.offline,
      version: '1.0.0',
      languages: ['zh', 'en', 'ja', 'ko', 'yue'],
      isFree: true,
      sizeMB: 230,
    ),
    EngineDefinition(
      id: 'apple_speech',
      name: 'Apple Speech',
      description: '苹果系统内置语音识别（仅支持文件转写，iOS/macOS）',
      category: EngineCategory.offline,
      version: '1.0.0',
      languages: ['zh', 'en'],
      isFree: true,
      sizeMB: 0,
    ),
  ];
});

/// 引擎实例管理器 Provider
final engineInstanceManagerProvider = Provider<EngineInstanceManager>((ref) {
  return EngineInstanceManager();
});

/// 当前活跃引擎实例 Provider
final activeInstanceProvider =
    StateNotifierProvider<ActiveInstanceNotifier, EngineInstance?>((ref) {
  final manager = ref.watch(engineInstanceManagerProvider);
  return ActiveInstanceNotifier(manager);
});

/// 活跃引擎状态管理
class ActiveInstanceNotifier extends StateNotifier<EngineInstance?> {
  final EngineInstanceManager _manager;

  ActiveInstanceNotifier(this._manager) : super(null) {
    _initializeBuiltinEngines();
  }

  Future<void> _initializeBuiltinEngines() async {
    try {
      await _manager.loadInstances();

      // 获取已有的活跃实例
      var activeInstance = _manager.getActiveInstance();

      // 迁移检查：如果当前引擎在当前平台没有内置模型，
      // 且没有已下载的模型，自动切换到平台默认引擎
      if (activeInstance != null) {
        final builtin = ModelRegistry.preferredBuiltinForEngine(
          activeInstance.engineId,
        );
        if (builtin == null) {
          final modelManager = ModelDownloadManager();
          final resolvedPath = await modelManager.resolveModelPath(
            activeInstance.engineId,
          );
          if (resolvedPath == null) {
            // 没有可用模型，清除旧实例，重新创建平台默认
            await _manager.deleteInstance(activeInstance.id);
            activeInstance = null;
          }
        }
      }

      if (activeInstance == null) {
        // 根据平台选择默认引擎：
        // - Android: Whisper（内置 GGML 模型，通过 native assets 加载）
        // - 其他平台: SenseVoice ONNX（内置 ONNX 模型，全平台可用）
        final isAndroid = Platform.isAndroid;
        final defaultEngineId = isAndroid ? 'whisper' : 'sensevoice_onnx';

        final engineDef = EngineDefinition(
          id: defaultEngineId,
          name: isAndroid ? 'Whisper Tiny' : 'SenseVoice ONNX',
          description: isAndroid
              ? '离线高精度语音识别模型'
              : 'SenseVoice 多语言语音识别模型（内置）',
          category: EngineCategory.offline,
          version: '1.0.0',
          languages: isAndroid
              ? ['zh', 'en', 'ja', 'ko', 'es', 'fr', 'de']
              : ['zh', 'en', 'ja', 'ko', 'yue'],
          isFree: true,
          sizeMB: isAndroid ? 75 : 230,
        );

        activeInstance = await _manager.createInstance(engine: engineDef);
        await _manager.updateInstanceState(
          activeInstance.id,
          version: engineDef.version,
          state: EngineInstanceState.downloaded,
          // Android whisper 使用 asset 别名，其他平台由 ModelDownloadManager 解析内置模型
          localPath: isAndroid ? 'whisper-tiny' : null,
        );
        await _manager.setActiveInstance(activeInstance.id);
      }

      state = _manager.getActiveInstance();
    } catch (e) {
      // 初始化失败不阻塞 UI，用户可在设置页手动选择引擎
      state = _manager.getActiveInstance();
    }
  }

  Future<void> setActiveInstance(EngineInstance instance) async {
    final previous = state;
    final resolvedInstance = _manager.getInstance(instance.id) ?? instance;
    await _manager.setActiveInstance(resolvedInstance.id);
    state = _manager.getActiveInstance() ?? resolvedInstance;

    // 加载引擎
    final transcriptionService = TranscriptionService();
    await transcriptionService.loadEngine(state!);
    if (transcriptionService.state == TranscriptionServiceState.error) {
      if (previous != null) {
        await _manager.setActiveInstance(previous.id);
        state = previous;
        await transcriptionService.loadEngine(previous);
      }
      // 没有 previous 时（首次启动），保留当前实例但不抛异常，
      // 用户可在设置页下载模型后重试
      if (previous != null) {
        throw Exception(transcriptionService.errorMessage ?? '模型加载失败');
      }
    }
  }
}

/// 转写服务 Provider
final transcriptionServiceProvider = Provider<TranscriptionService>((ref) {
  return TranscriptionService();
});

/// 转写状态 Provider
final transcriptionStateProvider =
    StateNotifierProvider<TranscriptionStateNotifier, TranscriptionState>(
        (ref) {
  return TranscriptionStateNotifier(ref);
});

/// 转写状态
class TranscriptionState {
  final bool isRecording;
  final bool isTranscribing;
  final String? resultText;
  final String? error;

  const TranscriptionState({
    this.isRecording = false,
    this.isTranscribing = false,
    this.resultText,
    this.error,
  });

  TranscriptionState copyWith({
    bool? isRecording,
    bool? isTranscribing,
    String? resultText,
    String? error,
  }) {
    return TranscriptionState(
      isRecording: isRecording ?? this.isRecording,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      resultText: resultText ?? this.resultText,
      error: error,
    );
  }
}

/// 转写状态管理
class TranscriptionStateNotifier extends StateNotifier<TranscriptionState> {
  TranscriptionStateNotifier(Ref ref) : super(const TranscriptionState());

  void setRecording(bool recording) {
    state = state.copyWith(isRecording: recording);
  }

  void setTranscribing(bool transcribing) {
    state = state.copyWith(isTranscribing: transcribing);
  }

  void setResult(String text) {
    state = state.copyWith(resultText: text, error: null);
  }

  void setError(String error) {
    state = state.copyWith(error: error, resultText: null);
  }

  void clear() {
    state = const TranscriptionState();
  }
}

/// 延迟指标 Provider
/// 监听转写状态变化，定期获取延迟指标
final latencyMetricsProvider = Provider<Map<String, dynamic>>((ref) {
  final service = ref.watch(transcriptionServiceProvider);
  return service.getLatencyMetrics();
});
