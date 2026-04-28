import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'model_format_detector.dart';
import 'sensevoice_metadata_fixer.dart';

/// 格式适配结果。
class AdaptResult {
  const AdaptResult({
    required this.success,
    this.modelPath,
    this.message,
    this.downloaded = false,
  });

  final bool success;
  final String? modelPath;
  final String? message;
  final bool downloaded;

  factory AdaptResult.ok(String path, {bool downloaded = false}) =>
      AdaptResult(success: true, modelPath: path, downloaded: downloaded);

  factory AdaptResult.fail(String message) =>
      AdaptResult(success: false, message: message);
}

/// 模型格式适配器。
///
/// 当检测到模型格式与目标引擎不兼容时，
/// 自动从 HuggingFace 下载兼容格式或修复现有文件。
class ModelFormatAdapter {
  ModelFormatAdapter._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  /// Whisper GGML 模型的 HuggingFace 下载源。
  static const Map<String, String> _whisperGgmlUrls = {
    'tiny':
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
    'base':
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
    'small':
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
  };

  /// Whisper ONNX 模型的 HuggingFace 下载源（sherpa-onnx 格式）。
  static const Map<String, List<String>> _whisperOnnxUrls = {
    'tiny': [
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/encoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/decoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tokens.txt',
    ],
    'base': [
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main/encoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main/decoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base/resolve/main/tokens.txt',
    ],
  };

  /// Vosk Paraformer ONNX 模型下载源（替代 Vosk Kaldi 用于 iOS/macOS）。
  static const List<String> _voskParaformerOnnxUrls = [
    'https://huggingface.co/csukuangfj/sherpa-onnx-paraformer-zh-small-2024-03-09/resolve/main/model.int8.onnx',
    'https://huggingface.co/csukuangfj/sherpa-onnx-paraformer-zh-small-2024-03-09/resolve/main/tokens.txt',
  ];

  /// SenseVoice ONNX 模型下载源（sherpa-onnx 兼容版本）。
  static const List<String> _senseVoiceOnnxUrls = [
    'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx',
    'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/tokens.txt',
  ];

  /// 尝试适配模型格式。
  ///
  /// 检测 [modelPath] 的格式，如果不兼容当前平台，
  /// 尝试自动修复或下载兼容格式。
  ///
  /// [engineId] 目标引擎。
  /// [onProgress] 下载进度回调（0.0 ~ 1.0）。
  static Future<AdaptResult> adapt({
    required String modelPath,
    required String engineId,
    void Function(double progress)? onProgress,
  }) async {
    final report = await ModelFormatDetector.detect(modelPath);
    if (report == null) {
      return AdaptResult.fail('无法检测模型格式: $modelPath');
    }

    // 已经兼容，直接返回。
    if (report.isCompatible) {
      return AdaptResult.ok(report.path);
    }

    // 根据引擎和格式类型选择适配策略。
    switch (engineId) {
      case 'whisper':
        return _adaptWhisper(report, onProgress: onProgress);
      case 'vosk':
        return _adaptVosk(report, onProgress: onProgress);
      case 'sensevoice_onnx':
        return _adaptSenseVoice(report, onProgress: onProgress);
      default:
        return AdaptResult.fail('不支持的引擎: $engineId');
    }
  }

  /// Whisper 格式适配。
  static Future<AdaptResult> _adaptWhisper(
    ModelFormatReport report, {
    void Function(double progress)? onProgress,
  }) async {
    switch (report.format) {
      case ModelFormat.whisperPytorch:
        // PyTorch 格式：下载对应的 GGML 或 ONNX 版本。
        return _downloadWhisperCompatibleFormat(report, onProgress: onProgress);

      case ModelFormat.whisperGgml:
        // GGML 格式但当前平台不支持（iOS/macOS）：下载 ONNX 版本。
        if (Platform.isIOS || Platform.isMacOS) {
          return _downloadWhisperOnnx(report, onProgress: onProgress);
        }
        return AdaptResult.fail('GGML 格式在当前平台不可用');

      case ModelFormat.whisperOnnx:
        // ONNX 格式但当前平台不支持（Android）：下载 GGML 版本。
        if (Platform.isAndroid) {
          return _downloadWhisperGgml(report, onProgress: onProgress);
        }
        return AdaptResult.fail('ONNX 格式在当前平台不可用');

      default:
        return AdaptResult.fail('无法适配 Whisper 格式: ${report.formatName}');
    }
  }

  /// Vosk 格式适配。
  static Future<AdaptResult> _adaptVosk(
    ModelFormatReport report, {
    void Function(double progress)? onProgress,
  }) async {
    switch (report.format) {
      case ModelFormat.voskKaldi:
        // Kaldi 格式但当前平台不支持（iOS/macOS）：下载 Paraformer ONNX。
        if (Platform.isIOS || Platform.isMacOS) {
          return _downloadVoskParaformer(report, onProgress: onProgress);
        }
        return AdaptResult.fail('Kaldi 格式在当前平台不可用');

      case ModelFormat.voskOnnx:
        // ONNX 格式但当前平台不支持（Android）。
        if (Platform.isAndroid) {
          return AdaptResult.fail(
            'Android Vosk 需要 Kaldi 格式，请下载 vosk-model-small-cn',
          );
        }
        return AdaptResult.fail('ONNX 格式在当前平台不可用');

      default:
        return AdaptResult.fail('无法适配 Vosk 格式: ${report.formatName}');
    }
  }

  /// SenseVoice 格式适配。
  static Future<AdaptResult> _adaptSenseVoice(
    ModelFormatReport report, {
    void Function(double progress)? onProgress,
  }) async {
    if (report.format == ModelFormat.senseVoiceOnnxBroken) {
      // 尝试 1：查找 model_sherpa.onnx。
      final dir = File(report.path).parent;
      final sherpa = File('${dir.path}/model_sherpa.onnx');
      if (await sherpa.exists()) {
        return AdaptResult.ok(sherpa.path);
      }

      // 尝试 2：自动修复 metadata。
      final supportDir = await getApplicationSupportDirectory();
      final fixDir = Directory('${supportDir.path}/sensevoice_fixed');
      final fixedPath = await SenseVoiceMetadataFixer.fixModel(
        onnxPath: report.path,
        outputDir: fixDir.path,
      );
      if (fixedPath != null) {
        return AdaptResult.ok(fixedPath, downloaded: true);
      }

      // 尝试 3：下载兼容版本。
      return _downloadSenseVoice(report, onProgress: onProgress);
    }

    return AdaptResult.fail('无法适配 SenseVoice 格式: ${report.formatName}');
  }

  /// 下载 Whisper 兼容格式。
  static Future<AdaptResult> _downloadWhisperCompatibleFormat(
    ModelFormatReport report, {
    void Function(double progress)? onProgress,
  }) async {
    if (Platform.isAndroid) {
      return _downloadWhisperGgml(report, onProgress: onProgress);
    } else {
      return _downloadWhisperOnnx(report, onProgress: onProgress);
    }
  }

  /// 下载 Whisper GGML 格式。
  static Future<AdaptResult> _downloadWhisperGgml(
    ModelFormatReport report, {
    void Function(double progress)? onProgress,
  }) async {
    final modelSize = _detectWhisperSize(report.path);
    final url = _whisperGgmlUrls[modelSize];
    if (url == null) {
      return AdaptResult.fail('未找到 $modelSize 大小的 GGML 模型下载源');
    }

    final supportDir = await getApplicationSupportDirectory();
    final outputDir = Directory('${supportDir.path}/whisper_ggml/$modelSize');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final fileName = 'ggml-$modelSize.bin';
    final outputPath = '${outputDir.path}/$fileName';
    final outputFile = File(outputPath);

    // 如果已下载，直接返回。
    if (await outputFile.exists() && await outputFile.length() > 1024 * 1024) {
      return AdaptResult.ok(outputPath);
    }

    try {
      await _dio.download(
        url,
        outputPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total);
          }
        },
      );

      if (await outputFile.exists() && await outputFile.length() > 1024 * 1024) {
        return AdaptResult.ok(outputPath, downloaded: true);
      }
      return AdaptResult.fail('下载的文件不完整');
    } catch (e) {
      return AdaptResult.fail('下载 GGML 模型失败: $e');
    }
  }

  /// 下载 Whisper ONNX 格式。
  static Future<AdaptResult> _downloadWhisperOnnx(
    ModelFormatReport report, {
    void Function(double progress)? onProgress,
  }) async {
    final modelSize = _detectWhisperSize(report.path);
    final urls = _whisperOnnxUrls[modelSize];
    if (urls == null || urls.isEmpty) {
      return AdaptResult.fail('未找到 $modelSize 大小的 ONNX 模型下载源');
    }

    final supportDir = await getApplicationSupportDirectory();
    final outputDir =
        Directory('${supportDir.path}/whisper_onnx/$modelSize');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    // 检查是否已下载。
    final tokensFile = File('${outputDir.path}/tokens.txt');
    if (await tokensFile.exists()) {
      return AdaptResult.ok(outputDir.path);
    }

    try {
      for (var i = 0; i < urls.length; i++) {
        final url = urls[i];
        final fileName = url.split('/').last;
        final outputPath = '${outputDir.path}/$fileName';
        await _dio.download(
          url,
          outputPath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final fileProgress = received / total;
              onProgress?.call((i + fileProgress) / urls.length);
            }
          },
        );
      }

      if (await tokensFile.exists()) {
        return AdaptResult.ok(outputDir.path, downloaded: true);
      }
      return AdaptResult.fail('下载的文件不完整');
    } catch (e) {
      return AdaptResult.fail('下载 ONNX 模型失败: $e');
    }
  }

  /// 下载 Vosk Paraformer ONNX（替代 Vosk Kaldi 用于 iOS/macOS）。
  static Future<AdaptResult> _downloadVoskParaformer(
    ModelFormatReport report, {
    void Function(double progress)? onProgress,
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    final outputDir =
        Directory('${supportDir.path}/vosk_paraformer_onnx');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    // 检查是否已下载。
    final tokensFile = File('${outputDir.path}/tokens.txt');
    if (await tokensFile.exists()) {
      return AdaptResult.ok(outputDir.path);
    }

    try {
      for (var i = 0; i < _voskParaformerOnnxUrls.length; i++) {
        final url = _voskParaformerOnnxUrls[i];
        final fileName = url.split('/').last;
        final outputPath = '${outputDir.path}/$fileName';
        await _dio.download(
          url,
          outputPath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final fileProgress = received / total;
              onProgress?.call(
                  (i + fileProgress) / _voskParaformerOnnxUrls.length);
            }
          },
        );
      }

      if (await tokensFile.exists()) {
        return AdaptResult.ok(outputDir.path, downloaded: true);
      }
      return AdaptResult.fail('下载的文件不完整');
    } catch (e) {
      return AdaptResult.fail('下载 Paraformer 模型失败: $e');
    }
  }

  /// 下载 SenseVoice ONNX 兼容版本。
  static Future<AdaptResult> _downloadSenseVoice(
    ModelFormatReport report, {
    void Function(double progress)? onProgress,
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    final outputDir =
        Directory('${supportDir.path}/sensevoice_onnx_fixed');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    // 检查是否已下载。
    final modelFile = File('${outputDir.path}/model.int8.onnx');
    if (await modelFile.exists()) {
      return AdaptResult.ok(modelFile.path);
    }

    try {
      for (var i = 0; i < _senseVoiceOnnxUrls.length; i++) {
        final url = _senseVoiceOnnxUrls[i];
        final fileName = url.split('/').last;
        final outputPath = '${outputDir.path}/$fileName';
        await _dio.download(
          url,
          outputPath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final fileProgress = received / total;
              onProgress?.call(
                  (i + fileProgress) / _senseVoiceOnnxUrls.length);
            }
          },
        );
      }

      if (await modelFile.exists()) {
        return AdaptResult.ok(modelFile.path, downloaded: true);
      }
      return AdaptResult.fail('下载的文件不完整');
    } catch (e) {
      return AdaptResult.fail('下载 SenseVoice 模型失败: $e');
    }
  }

  /// 从路径中检测 Whisper 模型大小。
  static String _detectWhisperSize(String path) {
    final lower = path.toLowerCase();
    if (lower.contains('small')) return 'small';
    if (lower.contains('base')) return 'base';
    if (lower.contains('medium')) return 'medium';
    if (lower.contains('large')) return 'large';
    return 'tiny';
  }
}
