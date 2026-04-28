import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/engine_definition.dart';
import '../models/model_registry.dart';
import '../utils/model_format_adapter.dart';
import '../utils/model_format_detector.dart';

/// 模型下载信息
class ModelDownloadInfo {
  final String engineId;
  final String version;
  final String localPath;
  final DateTime downloadedAt;
  final int sizeMB;

  const ModelDownloadInfo({
    required this.engineId,
    required this.version,
    required this.localPath,
    required this.downloadedAt,
    required this.sizeMB,
  });
}

/// 模型下载管理器
class ModelDownloadManager {
  static final ModelDownloadManager _instance =
      ModelDownloadManager._internal();
  factory ModelDownloadManager() => _instance;
  ModelDownloadManager._internal();

  static const int _maxZipBytes = 512 * 1024 * 1024;
  static const int _maxZipEntries = 10000;
  static const int _maxExtractedBytes = 2 * 1024 * 1024 * 1024;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(minutes: 15),
    ),
  );
  final Map<String, double> _downloadProgress = {};
  static const String _modelPathPrefix = 'model_path_';
  static const String _externalPathsKey = 'external_model_search_paths';

  final List<String> _externalModelSearchPaths = [];

  /// 设置外部模型搜索路径（覆盖现有列表）
  Future<void> setExternalModelSearchPaths(List<String> paths) async {
    _externalModelSearchPaths
      ..clear()
      ..addAll(paths.where((p) => p.trim().isNotEmpty));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_externalPathsKey, _externalModelSearchPaths);
  }

  /// 添加单个外部模型搜索路径
  Future<void> addExternalModelSearchPath(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty || _externalModelSearchPaths.contains(trimmed)) return;
    _externalModelSearchPaths.add(trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_externalPathsKey, _externalModelSearchPaths);
  }

  /// 获取当前外部模型搜索路径
  List<String> getExternalModelSearchPaths() =>
      List.unmodifiable(_externalModelSearchPaths);

  /// 从 SharedPreferences 恢复外部搜索路径（app 启动时调用）
  Future<void> loadExternalModelSearchPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_externalPathsKey);
    if (saved != null && saved.isNotEmpty) {
      _externalModelSearchPaths
        ..clear()
        ..addAll(saved.where((p) => p.trim().isNotEmpty));
    }
  }

  static List<String> _engineAliases(String engineId) {
    switch (engineId) {
      case 'whisper':
        return ['whisper-tiny'];
      case 'sensevoice_onnx':
        // 先匹配当前项目主目录命名，再兼容历史别名，最后匹配外部模型目录命名。
        return ['sensevoice-onnx', 'sensevoice_onnx', 'sensevoice', 'sensevoice-small'];
      case 'vosk':
        return [
          'vosk',
          'vosk-cn',
          'vosk-model-small-cn-0.22',
          'vosk-model-small-en-us-0.15'
        ];
      default:
        return [engineId];
    }
  }

  Future<String?> _resolveBuiltinAlias(String engineId) async {
    // 保持 Android 既有 native assets 别名行为不变。
    switch (engineId) {
      case 'whisper':
        return 'whisper-tiny';
      case 'sensevoice_onnx':
        return null;
      case 'vosk':
        return 'vosk-cn';
      default:
        final aliases = _engineAliases(engineId);
        if (aliases.isNotEmpty) {
          return aliases.first;
        }
        return null;
    }
  }

  Future<String> _builtinExtractionRoot() async {
    final supportDir = await getApplicationSupportDirectory();
    final root = Directory('${supportDir.path}/builtin_models');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root.path;
  }

  Future<String?> _extractBuiltinToFilesystem(
    BuiltinModelDefinition model,
  ) async {
    final root = await _builtinExtractionRoot();
    final modelRoot = Directory('$root/${model.engineId}/${model.id}');
    if (!await modelRoot.exists()) {
      await modelRoot.create(recursive: true);
    }

    for (final relative in model.requiredAssetFiles) {
      final cleaned = relative.trim();
      if (cleaned.isEmpty) continue;
      final target = File('${modelRoot.path}/$cleaned');
      if (!await target.parent.exists()) {
        await target.parent.create(recursive: true);
      }
      if (!await target.exists()) {
        final assetPath = '${model.assetBasePath}/$cleaned';
        try {
          final data = await rootBundle.load(assetPath);
          await target.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            flush: true,
          );
        } catch (_) {
          return null;
        }
      }
    }

    if (model.resolveToDirectory) {
      return modelRoot.path;
    }

    if (model.modelRelativePath.trim().isEmpty) {
      return null;
    }

    final modelFile = File('${modelRoot.path}/${model.modelRelativePath}');
    if (await modelFile.exists()) {
      return modelFile.path;
    }
    return null;
  }

  Future<String?> _resolveBuiltinModelPathViaRegistry(String engineId) async {
    final builtin = ModelRegistry.preferredBuiltinForEngine(engineId);
    if (builtin == null) return null;

    if (Platform.isAndroid && !builtin.requiresLocalFilesystem) {
      // 保持 Android whisper/vosk 走历史 alias。
      final alias = await _resolveBuiltinAlias(engineId);
      if (alias != null && alias.isNotEmpty) {
        return alias;
      }
    }

    if (builtin.requiresLocalFilesystem || !Platform.isAndroid) {
      return _extractBuiltinToFilesystem(builtin);
    }

    return null;
  }

  /// 获取模型存储目录
  Future<String> get _modelDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  /// 获取内置模型路径。
  /// - Android whisper/vosk: 返回历史 alias，交给 native 层从 assets 加载
  /// - 需要文件路径的引擎（如 sensevoice_onnx）: 从 assets 抽取到本地后返回文件路径
  Future<String?> getBuiltinModelPath(String engineId) async {
    return _resolveBuiltinModelPathViaRegistry(engineId);
  }

  /// 下载模型
  Future<void> downloadModel({
    required EngineDefinition engine,
    required String version,
    required String downloadUrl,
    List<String> extraDownloadUrls = const [],
    List<String>? allowedHosts,
    String? expectedSha256,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _modelDir;
    final safeEngineId = _sanitizePathSegment(engine.id, fallback: 'engine');
    final safeVersion = _sanitizePathSegment(version, fallback: 'v1');
    final modelPath = '$dir/$safeEngineId/$safeVersion';
    final modelDir = Directory(modelPath);
    final tempPath = '$dir/$safeEngineId/$safeVersion.__downloading';
    final tempDir = Directory(tempPath);

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    final trustedHosts = (allowedHosts ?? const ['huggingface.co'])
        .map((h) => h.toLowerCase())
        .toSet();
    final downloadUrls = <String>[downloadUrl, ...extraDownloadUrls]
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);

    if (downloadUrls.isEmpty) {
      throw Exception('下载地址为空');
    }

    final downloadedFiles = <String>[];
    final fileNameCounts = <String, int>{};
    _downloadProgress[engine.id] = 0.0;
    try {
      for (var i = 0; i < downloadUrls.length; i++) {
        final currentUrl = downloadUrls[i];
        final uri = Uri.parse(currentUrl);
        if (uri.scheme.toLowerCase() != 'https') {
          throw Exception('仅支持通过 HTTPS 下载模型');
        }
        final host = uri.host.toLowerCase();
        if (!trustedHosts.contains(host)) {
          throw Exception('下载来源不受信任: $host');
        }

        final inferredFileName = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : 'model_$i.bin';
        final safeFileName = _sanitizePathSegment(
          inferredFileName,
          fallback: 'model_$i.bin',
        );

        final seenCount = fileNameCounts[safeFileName] ?? 0;
        fileNameCounts[safeFileName] = seenCount + 1;
        final resolvedFileName =
            seenCount == 0 ? safeFileName : '${seenCount + 1}_$safeFileName';
        final filePath = '$tempPath/$resolvedFileName';

        final totalUrls = downloadUrls.length;
        await _dio.download(
          currentUrl,
          filePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              final perFileProgress = received / total;
              final overallProgress = (i + perFileProgress) / totalUrls;
              _downloadProgress[engine.id] = overallProgress;
              onProgress?.call(overallProgress);
            }
          },
        );

        if (i == 0 &&
            expectedSha256 != null &&
            expectedSha256.trim().isNotEmpty) {
          final actualSha256 = await _computeFileSha256(File(filePath));
          final normalizedExpected = expectedSha256.trim().toLowerCase();
          if (actualSha256 != normalizedExpected) {
            throw Exception('模型完整性校验失败（SHA-256 不匹配）');
          }
        }

        downloadedFiles.add(filePath);
      }

      for (final filePath in downloadedFiles) {
        if (filePath.toLowerCase().endsWith('.zip')) {
          await _extractZip(filePath, tempPath);
          await File(filePath).delete();
        }
      }

      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
      }
      await tempDir.rename(modelPath);
      onProgress?.call(1.0);
    } catch (_) {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      rethrow;
    } finally {
      _downloadProgress.remove(engine.id);
    }
  }

  /// 解压 zip 文件
  Future<void> _extractZip(String zipPath, String destPath) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw Exception('zip 文件不存在: $zipPath');
    }

    final zipStat = await zipFile.stat();
    if (zipStat.size > _maxZipBytes) {
      throw Exception('zip 文件过大，已拒绝解压');
    }

    final bytes = await zipFile.readAsBytes();
    if (bytes.length > _maxZipBytes) {
      throw Exception('zip 文件过大，已拒绝解压');
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.length > _maxZipEntries) {
      throw Exception('zip 条目数量过多，已拒绝解压');
    }

    final destRoot = Directory(destPath).absolute.path;
    final destRootPrefix = '$destRoot${Platform.pathSeparator}';
    var extractedBytes = 0;

    for (final entry in archive) {
      final normalizedName = entry.name.replaceAll('\\', '/').trim();
      if (normalizedName.isEmpty ||
          normalizedName.startsWith('/') ||
          normalizedName.startsWith('~')) {
        throw Exception('zip 条目路径非法: ${entry.name}');
      }

      final segments = normalizedName
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();
      if (segments.any((segment) => segment == '.' || segment == '..')) {
        throw Exception('zip 条目包含非法路径段: ${entry.name}');
      }

      final safeRelativePath = segments
          .map((segment) => _sanitizePathSegment(segment, fallback: '_'))
          .join(Platform.pathSeparator);
      final resolvedOutputPath =
          File('$destRoot${Platform.pathSeparator}$safeRelativePath')
              .absolute
              .path;
      if (resolvedOutputPath != destRoot &&
          !resolvedOutputPath.startsWith(destRootPrefix)) {
        throw Exception('zip 条目越界: ${entry.name}');
      }

      if (entry.isFile) {
        final data = entry.content as List<int>;
        extractedBytes += data.length;
        if (extractedBytes > _maxExtractedBytes) {
          throw Exception('zip 解压总大小超限，已中止');
        }

        final outFile = File(resolvedOutputPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(data, flush: true);
      } else {
        final outDir = Directory(resolvedOutputPath);
        await outDir.create(recursive: true);
      }
    }
  }

  /// 保存用户指定的模型目录（支持绝对路径）
  Future<void> setPreferredModelPath(String engineId, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_modelPathPrefix$engineId', path.trim());
  }

  /// 获取用户指定的模型目录
  Future<String?> getPreferredModelPath(String engineId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('$_modelPathPrefix$engineId');
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    return path.trim();
  }

  String _sanitizePathSegment(String input, {required String fallback}) {
    final sanitized = input
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      return fallback;
    }
    return sanitized;
  }

  Future<bool> _looksLikeWhisperOnnxDir(Directory dir) async {
    final encoderInt8 = File('${dir.path}/encoder.int8.onnx');
    final encoder = File('${dir.path}/encoder.onnx');
    final decoderInt8 = File('${dir.path}/decoder.int8.onnx');
    final decoder = File('${dir.path}/decoder.onnx');
    final tokens = File('${dir.path}/tokens.txt');

    final hasEncoder = await encoderInt8.exists() || await encoder.exists();
    final hasDecoder = await decoderInt8.exists() || await decoder.exists();
    final hasTokens = await tokens.exists();

    return hasEncoder && hasDecoder && hasTokens;
  }

  Future<bool> _looksLikeVoskOnnxDir(Directory dir) async {
    final tokens = File('${dir.path}/tokens.txt');
    if (!await tokens.exists()) return false;

    final paraformerInt8 = File('${dir.path}/model.int8.onnx');
    final paraformer = File('${dir.path}/model.onnx');
    final hasParaformer =
        await paraformerInt8.exists() || await paraformer.exists();
    if (hasParaformer) return true;

    final encoderInt8 = File('${dir.path}/encoder.int8.onnx');
    final encoder = File('${dir.path}/encoder.onnx');
    final decoderInt8 = File('${dir.path}/decoder.int8.onnx');
    final decoder = File('${dir.path}/decoder.onnx');
    final joinerInt8 = File('${dir.path}/joiner.int8.onnx');
    final joiner = File('${dir.path}/joiner.onnx');

    final hasEncoder = await encoderInt8.exists() || await encoder.exists();
    final hasDecoder = await decoderInt8.exists() || await decoder.exists();
    final hasJoiner = await joinerInt8.exists() || await joiner.exists();

    return hasEncoder && hasDecoder && hasJoiner;
  }

  Future<String?> _resolveVersionedModelPath(
    String appModelDir,
    String engineId,
  ) async {
    final safeEngineId = _sanitizePathSegment(engineId, fallback: engineId);
    final engineDir = Directory('$appModelDir/$safeEngineId');
    if (!await engineDir.exists()) {
      return null;
    }

    final versionDirs = <Directory>[];
    await for (final entry in engineDir.list(followLinks: false)) {
      if (entry is Directory) {
        versionDirs.add(entry);
      }
    }
    versionDirs.sort((a, b) {
      final aName = a.path.split(Platform.pathSeparator).last;
      final bName = b.path.split(Platform.pathSeparator).last;
      return bName.compareTo(aName);
    });

    for (final entry in versionDirs) {
      final versionName = entry.path.split(Platform.pathSeparator).last;
      if (versionName.endsWith('.__downloading')) {
        continue;
      }

      if (engineId == 'sensevoice_onnx') {
        final c1 = File('${entry.path}/model_quant.onnx');
        if (await c1.exists()) return c1.path;
        final c2 = File('${entry.path}/model.int8.onnx');
        if (await c2.exists()) return c2.path;
        final c3 = File('${entry.path}/model.onnx');
        if (await c3.exists()) return c3.path;
      }
      if (engineId == 'whisper') {
        if (!Platform.isAndroid) {
          if (await _looksLikeWhisperOnnxDir(entry)) {
            return entry.path;
          }
        }
        final c = File('${entry.path}/ggml-tiny.bin');
        if (await c.exists()) return c.path;
      }
      if (engineId == 'vosk') {
        if (!Platform.isAndroid) {
          if (await _looksLikeVoskOnnxDir(entry)) {
            return entry.path;
          }
          continue;
        }
        return entry.path;
      }
    }

    return null;
  }

  /// 解析模型路径：优先用户路径，其次本地目录，最后 assets 别名
  Future<String?> resolveModelPath(String engineId,
      {String? preferredPath}) async {
    final pathFromPrefs = await getPreferredModelPath(engineId);

    final preferredCandidates = <String>[];
    if (preferredPath != null && preferredPath.trim().isNotEmpty) {
      preferredCandidates.add(preferredPath.trim());
    }
    if (pathFromPrefs != null && pathFromPrefs.trim().isNotEmpty) {
      preferredCandidates.add(pathFromPrefs.trim());
    }

    final preferredBuiltinAlias =
        await _resolvePreferredBuiltinAlias(engineId, preferredCandidates);
    if (preferredBuiltinAlias != null) {
      return preferredBuiltinAlias;
    }

    final preferredResolved =
        await _resolveExistingPathCandidates(engineId, preferredCandidates);
    if (preferredResolved != null) {
      return preferredResolved;
    }

    final appDir = await getApplicationDocumentsDirectory();

    final versionedPath =
        await _resolveVersionedModelPath('${appDir.path}/models', engineId);
    if (versionedPath != null) {
      return versionedPath;
    }

    final aliases = _engineAliases(engineId);
    final candidates = <String>[];
    for (final alias in aliases) {
      candidates.add('${appDir.path}/models/$alias');
      if (engineId == 'whisper') {
        candidates.add('${appDir.path}/models/$alias/ggml-tiny.bin');
        if (!Platform.isAndroid) {
          candidates.add('${appDir.path}/models/$alias/encoder.int8.onnx');
          candidates.add('${appDir.path}/models/$alias/encoder.onnx');
        }
      } else if (engineId == 'sensevoice_onnx') {
        candidates.add('${appDir.path}/models/$alias/model_sherpa.onnx');
        candidates.add('${appDir.path}/models/$alias/model_quant.onnx');
        candidates.add('${appDir.path}/models/$alias/model.int8.fixed.onnx');
        candidates.add('${appDir.path}/models/$alias/model.onnx');
      }
    }

    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        for (final alias in aliases) {
          candidates.add('${externalDir.path}/models/$alias');
          if (engineId == 'whisper') {
            candidates.add('${externalDir.path}/models/$alias/ggml-tiny.bin');
          } else if (engineId == 'sensevoice_onnx') {
            candidates
                .add('${externalDir.path}/models/$alias/model_sherpa.onnx');
            candidates
                .add('${externalDir.path}/models/$alias/model_quant.onnx');
            candidates
                .add('${externalDir.path}/models/$alias/model.int8.fixed.onnx');
            candidates.add('${externalDir.path}/models/$alias/model.onnx');
          }
        }
      }
      for (final alias in aliases) {
        // 对于 SenseVoice，优先 app 专属目录，避免 Android 13+ 公共目录权限问题。
        if (engineId != 'sensevoice_onnx') {
          candidates.add('/storage/emulated/0/voices/models/$alias');
          if (engineId == 'whisper') {
            candidates
                .add('/storage/emulated/0/voices/models/$alias/ggml-tiny.bin');
          }
        }
      }
    }

    final resolved = await _resolveExistingPathCandidates(engineId, candidates);
    if (resolved != null) {
      return resolved;
    }

    // 搜索外部模型目录（用户配置的多格式模型路径）。
    final externalPath = await _resolveExternalModelPaths(engineId);
    if (externalPath != null) {
      return externalPath;
    }

    // 最后尝试内置模型（优先 registry，兼容 Android alias 逻辑）。
    final builtinPath = await _resolveBuiltinModelPathViaRegistry(engineId);
    if (builtinPath != null) {
      return builtinPath;
    }

    return null;
  }

  /// 解析模型路径，当格式不兼容时自动适配（下载/修复）。
  ///
  /// 这是 [resolveModelPath] 的增强版本，会：
  /// 1. 先调用 resolveModelPath 查找已有模型
  /// 2. 检测格式兼容性
  /// 3. 不兼容时自动触发适配（下载正确格式或修复 metadata）
  ///
  /// [onProgress] 下载进度回调（0.0 ~ 1.0）。
  Future<String?> resolveModelPathWithAdapt(
    String engineId, {
    String? preferredPath,
    void Function(double progress)? onProgress,
  }) async {
    // 先尝试标准解析。
    final resolved = await resolveModelPath(
      engineId,
      preferredPath: preferredPath,
    );

    if (resolved == null) {
      // 没有找到任何模型，尝试直接下载兼容格式。
      final adaptResult = await ModelFormatAdapter.adapt(
        modelPath: '',
        engineId: engineId,
        onProgress: onProgress,
      );
      if (adaptResult.success && adaptResult.modelPath != null) {
        await setPreferredModelPath(engineId, adaptResult.modelPath!);
        return adaptResult.modelPath;
      }
      return null;
    }

    // 检测格式兼容性。
    final report = await ModelFormatDetector.detect(resolved);
    if (report == null || report.isCompatible) {
      return resolved;
    }

    // 格式不兼容，尝试自动适配。
    final adaptResult = await ModelFormatAdapter.adapt(
      modelPath: resolved,
      engineId: engineId,
      onProgress: onProgress,
    );

    if (adaptResult.success && adaptResult.modelPath != null) {
      // 适配成功，更新用户偏好路径。
      await setPreferredModelPath(engineId, adaptResult.modelPath!);
      return adaptResult.modelPath;
    }

    // 适配失败，返回原始路径（调用方会收到错误）。
    return resolved;
  }

  Future<String?> _resolvePreferredBuiltinAlias(
    String engineId,
    List<String> preferredCandidates,
  ) async {
    final builtinAlias = await _resolveBuiltinAlias(engineId);
    if (builtinAlias == null || builtinAlias.isEmpty) {
      return null;
    }

    for (final candidate in preferredCandidates) {
      if (candidate.trim() == builtinAlias) {
        return builtinAlias;
      }
    }

    return null;
  }

  Future<String?> _resolveExistingPathCandidates(
    String engineId,
    List<String> candidates,
  ) async {
    for (final path in candidates.toSet()) {
      if (path.trim().isEmpty) {
        continue;
      }

      if (await File(path).exists()) {
        return path;
      }
      if (!await Directory(path).exists()) {
        continue;
      }

      if (engineId == 'sensevoice_onnx') {
        final c0 = File('$path/model_sherpa.onnx');
        if (await c0.exists()) {
          return c0.path;
        }
        final c1 = File('$path/model_quant.onnx');
        if (await c1.exists()) {
          return c1.path;
        }
        final c2 = File('$path/model.int8.fixed.onnx');
        if (await c2.exists()) {
          return c2.path;
        }
        final c3 = File('$path/model.int8.onnx');
        if (await c3.exists()) {
          return c3.path;
        }
        final c4 = File('$path/model.onnx');
        if (await c4.exists()) {
          return c4.path;
        }
        continue;
      }
      if (engineId == 'whisper' && !Platform.isAndroid) {
        final whisperDir = Directory(path);
        if (await _looksLikeWhisperOnnxDir(whisperDir)) {
          return path;
        }
        continue;
      }
      if (engineId == 'vosk' && !Platform.isAndroid) {
        final voskDir = Directory(path);
        if (await _looksLikeVoskOnnxDir(voskDir)) {
          return path;
        }
        continue;
      }
      return path;
    }

    return null;
  }

  /// 搜索外部模型目录中的兼容模型。
  ///
  /// 扫描所有配置的外部搜索路径，按引擎别名匹配子目录名，
  /// 然后按引擎类型做格式探测（ONNX 目录结构、Kaldi 目录结构等）。
  Future<String?> _resolveExternalModelPaths(String engineId) async {
    if (_externalModelSearchPaths.isEmpty) return null;

    final aliases = _engineAliases(engineId);
    for (final basePath in _externalModelSearchPaths) {
      final baseDir = Directory(basePath);
      if (!await baseDir.exists()) continue;

      // 遍历外部目录下的子目录，按别名匹配。
      await for (final entity in baseDir.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final dirName = entity.path.split(Platform.pathSeparator).last;

        // 检查目录名是否匹配引擎别名。
        final aliasMatch = aliases.any((a) => a == dirName);
        if (!aliasMatch) continue;

        // 按引擎类型做格式探测。
        final result = await _probeEngineModelDir(engineId, entity);
        if (result != null) return result;
      }
    }

    return null;
  }

  /// 对单个目录做引擎格式探测，返回可用的模型路径或 null。
  Future<String?> _probeEngineModelDir(
      String engineId, Directory dir) async {
    switch (engineId) {
      case 'sensevoice_onnx':
        return _probeSenseVoiceDir(dir);
      case 'whisper':
        return _probeWhisperDir(dir);
      case 'vosk':
        return _probeVoskDir(dir);
      default:
        return null;
    }
  }

  Future<String?> _probeSenseVoiceDir(Directory dir) async {
    // SenseVoice ONNX：查找兼容的模型文件。
    final candidates = [
      'model_sherpa.onnx',
      'model_quant.onnx',
      'model.int8.fixed.onnx',
      'model.int8.onnx',
      'model.onnx',
    ];
    for (final name in candidates) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) {
        // 检查是否有对应的 tokens 文件。
        final tokensTxt = File('${dir.path}/tokens.txt');
        final tokensJson = File('${dir.path}/tokens.json');
        if (await tokensTxt.exists() || await tokensJson.exists()) {
          return file.path;
        }
      }
    }
    return null;
  }

  Future<String?> _probeWhisperDir(Directory dir) async {
    if (Platform.isAndroid) {
      // Android Whisper：查找 ggml 格式。
      final ggml = File('${dir.path}/ggml-tiny.bin');
      if (await ggml.exists()) return ggml.path;
      return null;
    }
    // iOS/macOS Whisper：查找 ONNX 格式（encoder/decoder/tokens）。
    if (await _looksLikeWhisperOnnxDir(dir)) return dir.path;
    return null;
  }

  Future<String?> _probeVoskDir(Directory dir) async {
    if (Platform.isAndroid) {
      // Android Vosk：Kaldi 原生格式，直接返回目录路径。
      final readme = File('${dir.path}/README');
      final mdl = File('${dir.path}/am/final.mdl');
      if (await readme.exists() || await mdl.exists()) return dir.path;
      return null;
    }
    // iOS/macOS Vosk：查找 ONNX 格式。
    if (await _looksLikeVoskOnnxDir(dir)) return dir.path;
    return null;
  }

  /// 检查模型是否已下载
  Future<bool> isModelDownloaded(String engineId, String version) async {
    final dir = await _modelDir;
    final safeEngineId = _sanitizePathSegment(engineId, fallback: 'engine');
    final safeVersion = _sanitizePathSegment(version, fallback: 'v1');
    final modelDir = Directory('$dir/$safeEngineId/$safeVersion');
    return modelDir.exists();
  }

  /// 获取模型路径
  Future<String?> getModelPath(String engineId, String version) async {
    final dir = await _modelDir;
    final safeEngineId = _sanitizePathSegment(engineId, fallback: 'engine');
    final safeVersion = _sanitizePathSegment(version, fallback: 'v1');
    final modelDir = Directory('$dir/$safeEngineId/$safeVersion');
    if (await modelDir.exists()) {
      return modelDir.path;
    }
    return null;
  }

  /// 删除模型
  Future<void> deleteModel(String engineId, String version) async {
    final dir = await _modelDir;
    final safeEngineId = _sanitizePathSegment(engineId, fallback: 'engine');
    final safeVersion = _sanitizePathSegment(version, fallback: 'v1');
    final modelDir = Directory('$dir/$safeEngineId/$safeVersion');
    if (await modelDir.exists()) {
      await modelDir.delete(recursive: true);
    }
  }

  /// 清理临时缓存目录（例如下载中的中间目录）
  Future<int> clearTemporaryCache() async {
    if (_downloadProgress.isNotEmpty) {
      throw Exception('下载进行中，暂时无法清理缓存');
    }

    final dir = await _modelDir;
    final rootDir = Directory(dir);
    if (!await rootDir.exists()) {
      return 0;
    }

    var deletedCount = 0;
    await for (final engineEntity in rootDir.list(followLinks: false)) {
      if (engineEntity is! Directory) continue;

      await for (final versionEntity in engineEntity.list(followLinks: false)) {
        if (versionEntity is! Directory) continue;

        final name = versionEntity.path.split(Platform.pathSeparator).last;
        if (!name.endsWith('.__downloading')) {
          continue;
        }

        await versionEntity.delete(recursive: true);
        deletedCount += 1;
      }
    }

    return deletedCount;
  }

  /// 获取下载进度
  double getDownloadProgress(String engineId) =>
      _downloadProgress[engineId] ?? 0.0;

  /// 获取已下载模型列表
  Future<List<ModelDownloadInfo>> getDownloadedModels() async {
    final dir = await _modelDir;
    final rootDir = Directory(dir);
    final List<ModelDownloadInfo> models = [];

    if (!await rootDir.exists()) return models;

    await for (final engineEntity in rootDir.list(followLinks: false)) {
      if (engineEntity is! Directory) continue;
      final engineId = engineEntity.path.split(Platform.pathSeparator).last;

      await for (final versionEntity in engineEntity.list(followLinks: false)) {
        if (versionEntity is! Directory) continue;

        final version = versionEntity.path.split(Platform.pathSeparator).last;
        if (version.endsWith('.__downloading')) {
          continue;
        }

        final stat = await versionEntity.stat();
        final sizeBytes = await _computeDirectorySizeBytes(versionEntity);
        final sizeMB = (sizeBytes / (1024 * 1024)).ceil();

        models.add(ModelDownloadInfo(
          engineId: engineId,
          version: version,
          localPath: versionEntity.path,
          downloadedAt: stat.modified,
          sizeMB: sizeMB,
        ));
      }
    }

    models.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return models;
  }

  Future<int> _computeDirectorySizeBytes(Directory dir) async {
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final stat = await entity.stat();
        total += stat.size;
      }
    }
    return total;
  }

  Future<String> _computeFileSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase();
  }
}
