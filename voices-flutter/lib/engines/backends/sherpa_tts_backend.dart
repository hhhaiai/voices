import 'dart:io';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../models/engine_config.dart';
import '../base/tts_backend.dart';

/// Sherpa TTS 引擎后端
/// 使用 sherpa_onnx Dart 包进行 TTS 推理
class SherpaTtsBackend implements TtsBackend {
  static bool _bindingsInitialized = false;
  sherpa_onnx.OfflineTts? _tts;
  final TtsConfig _config = const TtsConfig();
  String? _modelDir;
  int _numSpeakers = 0;
  int _sampleRate = 0;
  String? _lastError;

  TtsBackendState _state = TtsBackendState.idle;

  @override
  String get engineId => 'sherpa_tts';

  @override
  TtsBackendState get state => _state;

  @override
  bool get isLoaded => _tts != null;

  @override
  String? get lastError => _lastError;

  @override
  String? get modelPath => _modelDir;

  @override
  int get numSpeakers => _numSpeakers;

  @override
  int get sampleRate => _sampleRate;

  @override
  Future<bool> load(String modelPathOrDir) async {
    await unload();
    _state = TtsBackendState.loading;
    _lastError = null;

    try {
      _ensureBindings();

      final resolvedDir = await _resolveModelDir(modelPathOrDir);
      if (resolvedDir == null) {
        _lastError = '无法解析模型路径: $modelPathOrDir';
        _state = TtsBackendState.error;
        return false;
      }

      // 检测模型类型并构建配置
      final modelConfig = await _detectAndBuildConfig(resolvedDir);
      if (modelConfig == null) {
        _lastError = '无法检测模型类型或构建配置';
        _state = TtsBackendState.error;
        return false;
      }

      final config = sherpa_onnx.OfflineTtsConfig(
        model: modelConfig,
        maxNumSenetences: 1,
      );

      _tts = sherpa_onnx.OfflineTts(config);
      _modelDir = resolvedDir.path;
      _numSpeakers = _tts!.numSpeakers;
      _sampleRate = _tts!.sampleRate;
      _state = TtsBackendState.ready;
      return true;
    } catch (e) {
      _lastError = e.toString();
      _state = TtsBackendState.error;
      return false;
    }
  }

  Future<Directory?> _resolveModelDir(String input) async {
    final directFile = File(input);
    if (await directFile.exists()) {
      return directFile.parent;
    }

    final directDir = Directory(input);
    if (await directDir.exists()) {
      return directDir;
    }

    return null;
  }

  Future<sherpa_onnx.OfflineTtsModelConfig?> _detectAndBuildConfig(
      Directory modelDir) async {
    // 尝试检测 VITS 模型
    final vitsModel = await _pickFirstExistingFile(modelDir, const [
      'vits.onnx',
      'model.onnx',
    ]);
    final vitsTokens = await _pickFirstExistingFile(modelDir, const [
      'tokens.txt',
    ]);

    if (vitsModel != null) {
      // VITS 模型检测到
      // vits-melo-tts-zh_en 使用 lexicon 方式，不需要 dataDir/phontab
      // 配置: model.onnx + lexicon.txt + tokens.txt
      final vitsLexicon = await _pickFirstExistingFile(modelDir, const [
        'lexicon.txt',
      ]);
      return sherpa_onnx.OfflineTtsModelConfig(
        vits: sherpa_onnx.OfflineTtsVitsModelConfig(
          model: vitsModel.path,
          tokens: vitsTokens?.path ?? '',
          lexicon: vitsLexicon?.path ?? '',
          dataDir: '', // 不需要 dataDir
          noiseScale: _config.noiseScale,
          noiseScaleW: _config.noiseScaleW,
          lengthScale: _config.lengthScale,
        ),
        numThreads: _config.numThreads,
        debug: _config.debug,
        provider: _config.provider,
      );
    }

    // 尝试检测 Kokoro 模型
    final kokoroModel = await _pickFirstExistingFile(modelDir, const [
      'kokoro.onnx',
      'model.onnx',
    ]);
    final kokoroVoices = await _pickFirstExistingFile(modelDir, const [
      'voices.bin',
      'voices.onnx',
    ]);

    if (kokoroModel != null) {
      return sherpa_onnx.OfflineTtsModelConfig(
        kokoro: sherpa_onnx.OfflineTtsKokoroModelConfig(
          model: kokoroModel.path,
          voices: kokoroVoices?.path ?? '',
          tokens: vitsTokens?.path ?? '',
          dataDir: modelDir.path,
          lengthScale: _config.lengthScale,
        ),
        numThreads: _config.numThreads,
        debug: _config.debug,
        provider: _config.provider,
      );
    }

    // 尝试检测 Matcha 模型
    final matchaAcoustic = await _pickFirstExistingFile(modelDir, const [
      'acoustic.onnx',
      'model.onnx',
    ]);
    final matchaVocoder = await _pickFirstExistingFile(modelDir, const [
      'vocoder.onnx',
    ]);

    if (matchaAcoustic != null) {
      return sherpa_onnx.OfflineTtsModelConfig(
        matcha: sherpa_onnx.OfflineTtsMatchaModelConfig(
          acousticModel: matchaAcoustic.path,
          vocoder: matchaVocoder?.path ?? '',
          tokens: vitsTokens?.path ?? '',
          dataDir: modelDir.path,
          noiseScale: _config.noiseScale,
          lengthScale: _config.lengthScale,
        ),
        numThreads: _config.numThreads,
        debug: _config.debug,
        provider: _config.provider,
      );
    }

    return null;
  }

  Future<File?> _pickFirstExistingFile(
    Directory dir,
    List<String> names,
  ) async {
    for (final name in names) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  @override
  Future<TtsAudioResult?> synthesize(
    String text, {
    int sid = 0,
    double speed = 1.0,
  }) async {
    final tts = _tts;
    if (tts == null) {
      return null;
    }

    _state = TtsBackendState.generating;

    try {
      final audio = tts.generate(
        text: text,
        sid: sid,
        speed: speed,
      );

      _state = TtsBackendState.ready;
      return TtsAudioResult(
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
    } catch (e) {
      _state = TtsBackendState.error;
      return null;
    }
  }

  @override
  Future<void> unload() async {
    try {
      _tts?.free();
    } catch (_) {
      // ignore
    } finally {
      _tts = null;
      _modelDir = null;
      _numSpeakers = 0;
      _sampleRate = 0;
      _state = TtsBackendState.idle;
    }
  }

  @override
  Map<String, dynamic> statusMap() {
    return {
      'engineId': engineId,
      'state': _state.name,
      'isLoaded': isLoaded,
      'modelPath': modelPath,
      'numSpeakers': numSpeakers,
      'sampleRate': sampleRate,
      'lastError': lastError,
    };
  }

  @override
  Future<bool> warmup() async {
    final tts = _tts;
    if (tts == null) return false;

    try {
      // 预热：生成一个短句
      tts.generate(text: '你好', sid: 0, speed: 1.0);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    unload();
  }

  void _ensureBindings() {
    if (_bindingsInitialized) return;
    sherpa_onnx.initBindings();
    _bindingsInitialized = true;
  }
}
