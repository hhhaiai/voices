import '../models/audio_input.dart';
import '../models/engine_definition.dart';
import '../models/engine_instance.dart';
import '../models/transcription_result.dart';
import '../engines/backend_resolver.dart';
import '../engines/base/engine_backend.dart';
import 'engine_instance_manager.dart';
import 'model_download_manager.dart';

/// 转写服务状态
enum TranscriptionServiceState {
  idle,
  loading,
  ready,
  transcribing,
  error,
}

/// 转写服务中心
/// 通过 BackendResolver 获取 EngineBackend，统一走 backend API
class TranscriptionService {
  static final TranscriptionService _instance =
      TranscriptionService._internal();
  factory TranscriptionService() => _instance;
  TranscriptionService._internal();

  final EngineInstanceManager _instanceManager = EngineInstanceManager();
  final ModelDownloadManager _modelManager = ModelDownloadManager();

  EngineBackend? _currentBackend;
  TranscriptionServiceState _state = TranscriptionServiceState.idle;
  String? _errorMessage;
  String? _currentModelPath;
  String? _currentEngineId;

  /// 当前服务状态
  TranscriptionServiceState get state => _state;

  /// 是否有引擎可用
  bool get isReady => _state == TranscriptionServiceState.ready;

  /// 错误信息
  String? get errorMessage => _errorMessage;

  /// 加载引擎
  Future<void> loadEngine(EngineInstance instance) async {
    try {
      final resolvedPath = instance.engineId == 'apple_speech'
          ? ''
          : await _modelManager.resolveModelPathWithAdapt(
              instance.engineId,
              preferredPath: instance.localPath,
            );
      if (resolvedPath == null) {
        throw Exception(
          '未找到 ${instance.engineId} 模型目录。请在设置页配置模型路径，'
          '或放到 app 文档目录/models/<engineId>。',
        );
      }

      if (_state == TranscriptionServiceState.ready &&
          _currentEngineId == instance.engineId &&
          _currentModelPath == resolvedPath) {
        return;
      }

      _state = TranscriptionServiceState.loading;
      _errorMessage = null;

      // 卸载当前引擎
      await unloadEngine();

      _currentModelPath = resolvedPath;
      _currentEngineId = instance.engineId;
      final loaded = await _loadEngineByType(
        engineId: instance.engineId,
        modelPath: resolvedPath,
      );

      if (loaded) {
        _state = TranscriptionServiceState.ready;

        // 更新实例状态
        await _instanceManager.updateInstanceState(
          instance.id,
          state: EngineInstanceState.ready,
          localPath: resolvedPath,
        );
      } else {
        final detail = _currentBackend?.lastError;
        if (detail != null && detail.isNotEmpty) {
          throw Exception(detail);
        }
        throw Exception('无法加载模型: $resolvedPath');
      }
    } catch (e) {
      _state = TranscriptionServiceState.error;
      _errorMessage = e.toString();

      // 更新实例状态
      await _instanceManager.updateInstanceState(
        instance.id,
        state: EngineInstanceState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 卸载当前引擎
  Future<void> unloadEngine() async {
    final backend = _currentBackend;
    _currentBackend = null;
    if (backend != null) {
      // 先 await unload() 确保异步资源释放
      await backend.unload();
      // 再调用 dispose() 释放同步资源（如 StreamController）
      backend.dispose();
    }
    _state = TranscriptionServiceState.idle;
    _currentModelPath = null;
    _currentEngineId = null;
    _errorMessage = null;
  }

  /// 转写音频
  Future<TranscriptionResult> transcribe(
    AudioInput audio, {
    bool enablePunctuation = true,
  }) async {
    // 如果引擎未加载，先尝试加载
    if (_state != TranscriptionServiceState.ready &&
        _currentModelPath != null) {
      final loaded = await _loadEngineByType(
        engineId: _currentEngineId ?? 'whisper',
        modelPath: _currentModelPath!,
      );
      if (loaded) {
        _state = TranscriptionServiceState.ready;
      } else {
        _state = TranscriptionServiceState.error;
        final detail = _currentBackend?.lastError;
        _errorMessage = (detail != null && detail.isNotEmpty)
            ? detail
            : '模型加载失败: $_currentModelPath';
      }
    }

    if (_state == TranscriptionServiceState.ready &&
        _currentBackend != null) {
      _state = TranscriptionServiceState.transcribing;

      try {
        final rawText = await _currentBackend!.transcribePcm(
              audio.data,
              audio.sampleRate,
            ) ??
            '';
        final normalized = _normalizeAsrText(rawText);
        if (_isEngineErrorText(normalized)) {
          // 能力边界错误（如 Apple Speech 不支持 PCM）不污染全局状态
          if (_currentBackend!.isErrorResult(rawText) &&
              normalized.contains('仅支持')) {
            _state = TranscriptionServiceState.ready;
            _errorMessage = null;
          } else {
            _state = TranscriptionServiceState.error;
            _errorMessage = normalized.substring('Error:'.length).trim();
          }
          return TranscriptionResult(
            text: normalized,
            audioDuration: audio.duration,
            confidence: 0.0,
            segments: [],
          );
        }

        final text =
            enablePunctuation ? _restorePunctuation(normalized) : normalized;
        _state = TranscriptionServiceState.ready;
        _errorMessage = null;

        return TranscriptionResult(
          text: text,
          audioDuration: audio.duration,
          confidence: 0.9,
          segments: [
            TranscriptionSegment(
              text: text,
              startTime: Duration.zero,
              endTime: audio.duration,
              confidence: 0.9,
            ),
          ],
        );
      } catch (e) {
        _state = TranscriptionServiceState.ready;
        rethrow;
      }
    }

    // 如果没有加载模型，返回提示或错误详情
    final fallbackText = (_errorMessage != null && _errorMessage!.isNotEmpty)
        ? 'Error: $_errorMessage'
        : '请先在设置中选择并加载模型';
    return TranscriptionResult(
      text: fallbackText,
      audioDuration: audio.duration,
      confidence: 0.0,
      segments: [],
    );
  }

  /// 转写音频文件
  Future<TranscriptionResult> transcribeFile(
    String filePath, {
    bool enablePunctuation = true,
  }) async {
    // 如果引擎未加载，先尝试加载
    if (_state != TranscriptionServiceState.ready &&
        _currentModelPath != null) {
      final loaded = await _loadEngineByType(
        engineId: _currentEngineId ?? 'whisper',
        modelPath: _currentModelPath!,
      );
      if (loaded) {
        _state = TranscriptionServiceState.ready;
      } else {
        _state = TranscriptionServiceState.error;
        final detail = _currentBackend?.lastError;
        _errorMessage = (detail != null && detail.isNotEmpty)
            ? detail
            : '模型加载失败: $_currentModelPath';
      }
    }

    if (_state == TranscriptionServiceState.ready &&
        _currentBackend != null) {
      _state = TranscriptionServiceState.transcribing;

      try {
        final rawText =
            await _currentBackend!.transcribeFile(filePath) ?? '';
        final normalized = _normalizeAsrText(rawText);
        if (_isEngineErrorText(normalized)) {
          // 能力边界错误不应污染全局引擎状态
          _state = TranscriptionServiceState.ready;
          _errorMessage = null;
          return TranscriptionResult(
            text: normalized,
            audioDuration: Duration.zero,
            confidence: 0.0,
            segments: [],
          );
        }

        final text =
            enablePunctuation ? _restorePunctuation(normalized) : normalized;
        _state = TranscriptionServiceState.ready;
        _errorMessage = null;

        return TranscriptionResult(
          text: text,
          audioDuration: Duration.zero,
          confidence: 0.9,
          segments: [
            TranscriptionSegment(
              text: text,
              startTime: Duration.zero,
              endTime: Duration.zero,
              confidence: 0.9,
            ),
          ],
        );
      } catch (e) {
        _state = TranscriptionServiceState.ready;
        rethrow;
      }
    }

    // 如果没有加载模型，返回提示或错误详情
    final fallbackText = (_errorMessage != null && _errorMessage!.isNotEmpty)
        ? 'Error: $_errorMessage'
        : '请先在设置中选择并加载模型';
    return TranscriptionResult(
      text: fallbackText,
      audioDuration: Duration.zero,
      confidence: 0.0,
      segments: [],
    );
  }

  String _restorePunctuation(String input) {
    var text = input.trim();
    if (text.isEmpty || text.startsWith('Error:')) {
      return text;
    }

    text = text.replaceAll(RegExp(r'\s+'), ' ');
    final hasChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    final hasPunctuation = RegExp(r'[，。！？；：,.!?;:]').hasMatch(text);

    if (hasChinese && !hasPunctuation) {
      text = text.replaceAllMapped(
        RegExp(r'(然后|但是|所以|因为|而且|并且|不过|另外|其次)'),
        (m) => m.start == 0 ? m.group(0)! : '，${m.group(0)}',
      );
    }

    if (RegExp(r'[。！？.!?]$').hasMatch(text)) {
      return text;
    }

    final isQuestion = RegExp(
      r'(吗|么|呢|是否|是不是|为什么|怎么|如何|几时|多少|\bwhat\b|\bwhy\b|\bhow\b|\bwhen\b|\bwhere\b|\bdo\b|\bdoes\b|\bcan\b)',
      caseSensitive: false,
    ).hasMatch(text);
    final isExclaim =
        RegExp(r'(太|真|好|棒|厉害|wow|amazing|great|!)', caseSensitive: false)
            .hasMatch(text);

    if (hasChinese) {
      if (isQuestion) return '$text？';
      if (isExclaim) return '$text！';
      return '$text。';
    }

    if (isQuestion) return '$text?';
    if (isExclaim) return '$text!';
    return '$text.';
  }

  bool _isEngineErrorText(String text) {
    return text.trimLeft().startsWith('Error:');
  }

  String _normalizeAsrText(String input) {
    var text = input.trim();
    if (text.isEmpty || text.startsWith('Error:')) {
      return text;
    }

    // 先压缩空白。
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // 中文字符之间的空格移除，避免"几 个 字"样式。
    text = text.replaceAllMapped(
      RegExp(r'([\u4e00-\u9fff])\s+([\u4e00-\u9fff])'),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    while (RegExp(r'[\u4e00-\u9fff]\s+[\u4e00-\u9fff]').hasMatch(text)) {
      text = text.replaceAllMapped(
        RegExp(r'([\u4e00-\u9fff])\s+([\u4e00-\u9fff])'),
        (m) => '${m.group(1)}${m.group(2)}',
      );
    }

    // 清理标点前后空格。
    text = text.replaceAll(RegExp(r'\s+([，。！？；：,.!?;:])'), r'$1');
    text = text.replaceAll(RegExp(r'([（(])\s+'), r'$1');
    text = text.replaceAll(RegExp(r'\s+([）)])'), r'$1');

    // 清理"你。好。吗"这类中文字符间的点号噪声。
    while (RegExp(r'[\u4e00-\u9fff][。\.]+\s*[\u4e00-\u9fff]').hasMatch(text)) {
      text = text.replaceAllMapped(
        RegExp(r'([\u4e00-\u9fff])[。\.]+\s*([\u4e00-\u9fff])'),
        (m) => '${m.group(1)}${m.group(2)}',
      );
    }

    // 短文本实时片段经常带尾部点号，先去掉，最终句号由停录后统一补齐。
    if (text.length <= 12) {
      text = text.replaceAll(RegExp(r'[。\.]+$'), '');
    }

    return text.trim();
  }

  /// 流式转写
  Stream<TranscriptionResult> transcribeStream(
      Stream<AudioInput> audioStream) async* {
    if (_state != TranscriptionServiceState.ready) {
      throw Exception('引擎未加载');
    }

    await for (final audio in audioStream) {
      yield await transcribe(audio);
    }
  }

  /// 切换引擎
  Future<void> switchEngine(EngineInstance instance) async {
    await _instanceManager.setActiveInstance(instance.id);
    await loadEngine(instance);
  }

  /// 通过 BackendResolver 加载引擎
  Future<bool> _loadEngineByType({
    required String engineId,
    required String modelPath,
  }) async {
    _currentBackend = BackendResolver.resolve(engineId);
    return _currentBackend!.load(modelPath);
  }
}
