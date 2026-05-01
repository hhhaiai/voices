import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/engine_definition.dart';
import '../models/engine_instance.dart';
import '../models/model_registry.dart';
import '../providers/providers.dart';
import '../services/model_download_manager.dart';

/// 设置屏幕（仅本地模型）
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final engines = ref.watch(engineListProvider);
    final activeInstance = ref.watch(activeInstanceProvider);
    final downloadedModelsAsync = ref.watch(downloadedModelsListProvider);
    final downloadState = ref.watch(modelDownloadStateProvider);
    final latencyMetrics = ref.watch(latencyMetricsProvider);
    final hasActiveDownloads = downloadState.items.values.any(
      (item) => item.status == ModelDownloadStatus.downloading,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本地模型模式',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '当前仅使用手机本地模型进行转写，不调用任何外部服务。',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '模型选择',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...engines.map((engine) {
            final selected = activeInstance?.engineId == engine.id;
            final isSupported = _isEngineSupportedOnCurrentPlatform(engine.id);
            final downloadableModels = ModelRegistry.modelsForEngine(engine.id);
            final builtinModels =
                ModelRegistry.builtinModelsForEngine(engine.id);
            final hasBuiltinModels = builtinModels.isNotEmpty;
            final hasDownloadableModels = downloadableModels.isNotEmpty;
            final downloadedPathByVersion = downloadedModelsAsync.maybeWhen(
              data: (items) {
                final map = <String, String>{};
                for (final item
                    in items.where((m) => m.engineId == engine.id)) {
                  map[item.version] = item.localPath;
                }
                return map;
              },
              orElse: () => <String, String>{},
            );
            ModelDownloadItemState stateForModel(String version) {
              return downloadState.itemFor(engine.id, version);
            }

            bool isDownloadedVersion(String version) {
              return downloadedPathByVersion.containsKey(version);
            }

            return Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(engine.name),
                    subtitle: Text(
                      '${engine.sizeMB}MB • ${engine.languages.join(", ")}\n'
                      '${_modelUsageHint(
                        engine.id,
                        hasBuiltinModels: hasBuiltinModels,
                        hasDownloadableModels: hasDownloadableModels,
                      )}',
                    ),
                    isThreeLine: true,
                    leading: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected ? Colors.green : null,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: isSupported ? () => _selectModel(engine) : null,
                    onLongPress:
                        isSupported ? () => _configureModelPath(engine) : null,
                  ),
                  if (hasBuiltinModels)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '内置本地模型已可用（含配置文件）',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.green.shade700),
                          ),
                          const SizedBox(height: 4),
                          ...builtinModels.map((builtin) => Text(
                                '${builtin.name}: ${_builtinFilesPreview(builtin.requiredAssetFiles)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              )),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: isSupported
                                ? () => _selectBuiltinModel(engine)
                                : null,
                            child: const Text('使用内置模型'),
                          ),
                        ],
                      ),
                    ),
                  if (downloadableModels.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasBuiltinModels) ...[
                            Text(
                              '可选在线下载模型',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                          ],
                          ...downloadableModels.map((model) {
                            final activeDownload = stateForModel(model.version);
                            final isDownloaded =
                                isDownloadedVersion(model.version);
                            final isActiveVersion = _isActiveModelVersion(
                              activeInstance,
                              engine.id,
                              model.version,
                              expectedModelPath:
                                  downloadedPathByVersion[model.version],
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          isDownloaded
                                              ? '已下载版本: ${model.version} (${model.sizeMB}MB)'
                                              : '可下载版本: ${model.version} (${model.sizeMB}MB)'
                                                  '${model.extraDownloadUrls.isNotEmpty ? ' • ${model.extraDownloadUrls.length + 1} 文件' : ''}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                      if (activeDownload.status ==
                                          ModelDownloadStatus.downloading)
                                        Text(
                                          '${(activeDownload.progress * 100).toStringAsFixed(0)}%',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (model.notes.isNotEmpty)
                                    Text(
                                      model.notes.join(' · '),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  if (model.extraDownloadUrls.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '包含额外文件: ${model.extraDownloadUrls.map((u) => Uri.parse(u).pathSegments.isNotEmpty ? Uri.parse(u).pathSegments.last : u).join(', ')}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  if (activeDownload.status ==
                                      ModelDownloadStatus.downloading)
                                    LinearProgressIndicator(
                                      value: activeDownload.progress,
                                    ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.tonal(
                                        onPressed: activeDownload.status ==
                                                ModelDownloadStatus.downloading
                                            ? null
                                            : () =>
                                                _downloadModel(engine, model),
                                        child: const Text('下载模型'),
                                      ),
                                      OutlinedButton(
                                        onPressed: isDownloaded &&
                                                !hasActiveDownloads &&
                                                !isActiveVersion
                                            ? () =>
                                                _confirmAndDeleteDownloadedModel(
                                                  engine.id,
                                                  model.version,
                                                )
                                            : null,
                                        child: const Text('删除已下载'),
                                      ),
                                      TextButton(
                                        onPressed: isDownloaded
                                            ? () => _selectModelVersion(
                                                  engine,
                                                  model.version,
                                                )
                                            : null,
                                        child: const Text('使用该模型'),
                                      ),
                                    ],
                                  ),
                                  if (activeDownload.status ==
                                          ModelDownloadStatus.error &&
                                      (activeDownload
                                              .errorMessage?.isNotEmpty ??
                                          false))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        '下载失败: ${_friendlyErrorMessage(activeDownload.errorMessage)}',
                                        style:
                                            const TextStyle(color: Colors.red),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          downloadedModelsAsync.maybeWhen(
            data: (items) {
              if (items.isEmpty) {
                return const SizedBox.shrink();
              }

              final grouped = <String, List<ModelDownloadInfo>>{};
              for (final item in items) {
                grouped.putIfAbsent(item.engineId, () => []).add(item);
              }

              final engineIds = grouped.keys.toList()..sort();
              for (final engineId in engineIds) {
                grouped[engineId]!
                    .sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '已下载模型',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (hasActiveDownloads)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '下载进行中，已暂时禁用删除操作',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.orange),
                          ),
                        ),
                      const SizedBox(height: 8),
                      ...engineIds.map((engineId) {
                        final engine = _findEngineById(engines, engineId);
                        final sectionItems = grouped[engineId]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                engine?.name ?? engineId,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 6),
                              ...sectionItems.map((item) {
                                final isActive = _isActiveDownloadedModel(
                                    activeInstance, item);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 6, 8, 6),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.withValues(alpha: 0.08)
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isActive
                                          ? Colors.green
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.version} • ${item.sizeMB}MB'
                                          '${isActive ? ' • 当前使用中' : ''}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: engine == null
                                            ? null
                                            : () => _selectModelVersion(
                                                  engine,
                                                  item.version,
                                                ),
                                        child: const Text('使用'),
                                      ),
                                      TextButton(
                                        onPressed: hasActiveDownloads ||
                                                isActive
                                            ? null
                                            : () =>
                                                _confirmAndDeleteDownloadedModel(
                                                  item.engineId,
                                                  item.version,
                                                ),
                                        child: const Text('删除'),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '外部模型目录',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: '添加外部模型目录',
                        onPressed: () => _addExternalModelPath(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '添加包含多格式模型的目录，app 会自动识别子目录中的兼容模型。'
                    '目录中的子目录名需匹配引擎别名（如 sensevoice-small、vosk-model-small-cn-0.22）。',
                  ),
                  ..._buildExternalPathChips(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('清理临时缓存'),
              subtitle: Text(
                hasActiveDownloads ? '下载进行中，暂时不可清理' : '不会删除已下载模型文件',
              ),
              onTap: hasActiveDownloads ? null : _showClearCacheDialog,
            ),
          ),
          if (latencyMetrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '性能指标',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildLatencyRow(
                      '推理次数',
                      '${latencyMetrics['inferenceCount'] ?? 0}',
                    ),
                    _buildLatencyRow(
                      '冷启动延迟',
                      _formatLatency(latencyMetrics['coldStartLatencyMs']),
                    ),
                    _buildLatencyRow(
                      '最近延迟',
                      _formatLatency(latencyMetrics['lastLatencyMs']),
                    ),
                    _buildLatencyRow(
                      '平均延迟',
                      _formatLatency(latencyMetrics['averageLatencyMs']),
                    ),
                    _buildLatencyRow(
                      '最小延迟',
                      _formatLatency(latencyMetrics['minLatencyMs']),
                    ),
                    _buildLatencyRow(
                      '最大延迟',
                      _formatLatency(latencyMetrics['maxLatencyMs']),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLatencyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatLatency(dynamic micros) {
    if (micros == null || micros == 0) return '-';
    final ms = (micros as int) / 1000;
    return '${ms.toStringAsFixed(1)}ms';
  }

  Future<void> _downloadModel(
    EngineDefinition engine,
    DownloadableModelDefinition model,
  ) async {
    try {
      await ref.read(modelDownloadStateProvider.notifier).downloadModel(
            engine: engine,
            model: model,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载完成: ${model.name} (${model.version})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('下载失败: ${_friendlyErrorMessage(e.toString())}')),
        );
      }
    }
  }

  Future<void> _confirmAndDeleteDownloadedModel(
    String engineId,
    String version,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除模型'),
        content: Text('将删除 $engineId/$version，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _deleteDownloadedModel(engineId, version);
  }

  Future<void> _deleteDownloadedModel(String engineId, String version) async {
    final activeInstance = ref.read(activeInstanceProvider);
    if (_isActiveModelVersion(activeInstance, engineId, version)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前使用中的模型不能删除')),
        );
      }
      return;
    }

    try {
      await ref.read(modelDownloadStateProvider.notifier).deleteDownloadedModel(
            engineId: engineId,
            version: version,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除: $engineId/$version')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('删除失败: ${_friendlyErrorMessage(e.toString())}')),
        );
      }
    }
  }

  Future<void> _selectModelVersion(
    EngineDefinition engine,
    String version,
  ) async {
    final manager = ModelDownloadManager();
    final path = await manager.getModelPath(engine.id, version);
    if (path == null || path.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未找到已下载模型: ${engine.id}/$version')),
        );
      }
      return;
    }

    final normalizedPath = path.trim();
    await manager.setPreferredModelPath(engine.id, normalizedPath);
    await _selectModel(
      engine,
      forcedModelPath: normalizedPath,
      forcedVersion: version,
    );
  }

  Future<void> _selectBuiltinModel(EngineDefinition engine) async {
    final modelManager = ModelDownloadManager();
    final builtinPath = await modelManager.getBuiltinModelPath(engine.id);
    if (builtinPath == null || builtinPath.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未找到 ${engine.name} 的内置模型')),
        );
      }
      return;
    }

    final normalizedPath = builtinPath.trim();
    await modelManager.setPreferredModelPath(engine.id, normalizedPath);
    await _selectModel(
      engine,
      forcedModelPath: normalizedPath,
    );
  }

  Future<void> _selectModel(
    EngineDefinition engine, {
    String? forcedModelPath,
    String? forcedVersion,
  }) async {
    final modelManager = ModelDownloadManager();
    String? modelPath;

    if (engine.id == 'apple_speech' && (Platform.isIOS || Platform.isMacOS)) {
      modelPath = '';
    } else {
      if (forcedModelPath != null && forcedModelPath.trim().isNotEmpty) {
        modelPath = forcedModelPath.trim();
      } else {
        modelPath = await modelManager.resolveModelPath(engine.id);
      }

      if (modelPath == null) {
        final manual = await _askModelPath(engine);
        if (manual != null && manual.trim().isNotEmpty) {
          final manualPath = manual.trim();
          modelPath = await modelManager.resolveModelPath(
            engine.id,
            preferredPath: manualPath,
          );
          if (modelPath != null) {
            await modelManager.setPreferredModelPath(engine.id, modelPath);
          }
        }
      }

      if (modelPath == null) {
        if (mounted) {
          final recommendDir = _recommendedModelDir(engine.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '未找到模型目录。\n推荐路径: $recommendDir',
              ),
            ),
          );
        }
        return;
      }
    }

    final instanceManager = ref.read(engineInstanceManagerProvider);
    await instanceManager.loadInstances();
    EngineInstance? instance;
    for (final item in instanceManager.listInstances()) {
      if (item.engineId == engine.id) {
        instance = item;
        break;
      }
    }
    instance ??= await instanceManager.createInstance(engine: engine);

    await instanceManager.updateInstanceState(
      instance.id,
      version: forcedVersion ?? engine.version,
      state: EngineInstanceState.downloaded,
      localPath: modelPath,
    );

    final updatedInstance =
        instanceManager.getInstance(instance.id) ?? instance;

    try {
      await ref
          .read(activeInstanceProvider.notifier)
          .setActiveInstance(updatedInstance);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('模型已加载: ${engine.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('加载失败: ${_friendlyErrorMessage(e.toString())}')),
        );
      }
    }
  }

  Future<void> _configureModelPath(EngineDefinition engine) async {
    if (engine.id == 'apple_speech') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apple Speech 无需配置模型路径')),
        );
      }
      return;
    }

    final manager = ModelDownloadManager();
    final current = await manager.getPreferredModelPath(engine.id) ?? '';
    final input = await _askModelPath(engine, initialValue: current);
    if (input == null) return;

    final path = input.trim();
    if (path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('路径为空，未保存')),
        );
      }
      return;
    }

    final resolvedPath = await manager.resolveModelPath(
      engine.id,
      preferredPath: path,
    );
    if (resolvedPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模型路径无效，请检查目录结构')),
        );
      }
      return;
    }

    await manager.setPreferredModelPath(engine.id, resolvedPath);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存模型路径')),
      );
    }
  }

  Future<String?> _askModelPath(
    EngineDefinition engine, {
    String initialValue = '',
  }) async {
    var inputValue = initialValue;
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置 ${engine.name} 本地路径'),
        content: TextFormField(
          initialValue: initialValue,
          autofocus: true,
          maxLines: 2,
          onChanged: (value) => inputValue = value,
          decoration: InputDecoration(
            hintText: _recommendedModelDir(engine.id),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, inputValue),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    return value;
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text('这将删除临时下载目录，不影响已下载模型。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              final manager = ref.read(modelDownloadManagerProvider);
              try {
                final clearedCount = await manager.clearTemporaryCache();
                if (mounted) {
                  final message = clearedCount > 0
                      ? '已清理 $clearedCount 个临时目录'
                      : '没有可清理的临时目录';
                  messenger.showSnackBar(SnackBar(content: Text(message)));
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '缓存清理失败: ${_friendlyErrorMessage(e.toString())}',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('清理'),
          ),
        ],
      ),
    );
  }

  EngineDefinition? _findEngineById(
    List<EngineDefinition> engines,
    String engineId,
  ) {
    for (final engine in engines) {
      if (engine.id == engineId) {
        return engine;
      }
    }
    return null;
  }

  bool _isActiveDownloadedModel(
    EngineInstance? activeInstance,
    ModelDownloadInfo item,
  ) {
    return _isActiveModelVersion(
      activeInstance,
      item.engineId,
      item.version,
      expectedModelPath: item.localPath,
    );
  }

  bool _isActiveModelVersion(
    EngineInstance? activeInstance,
    String engineId,
    String version, {
    String? expectedModelPath,
  }) {
    if (activeInstance == null || activeInstance.engineId != engineId) {
      return false;
    }

    final localPath = activeInstance.localPath;
    if (localPath == null || localPath.trim().isEmpty) {
      return false;
    }

    final normalizedActivePath = localPath.trim();
    final normalizedExpectedPath = expectedModelPath?.trim();

    if (normalizedExpectedPath != null && normalizedExpectedPath.isNotEmpty) {
      if (normalizedActivePath == normalizedExpectedPath) {
        return true;
      }
      final expectedPrefix = '$normalizedExpectedPath${Platform.pathSeparator}';
      return normalizedActivePath.startsWith(expectedPrefix);
    }

    final expectedSegment =
        '${Platform.pathSeparator}$engineId${Platform.pathSeparator}$version${Platform.pathSeparator}';
    return normalizedActivePath.contains(expectedSegment);
  }

  bool _isEngineSupportedOnCurrentPlatform(String engineId) {
    if (engineId == 'apple_speech') {
      return Platform.isIOS || Platform.isMacOS;
    }
    return true;
  }

  List<Widget> _buildExternalPathChips() {
    final paths = ModelDownloadManager().getExternalModelSearchPaths();
    if (paths.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('未配置外部模型目录'),
        ),
      ];
    }
    return [
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: paths.map((path) {
          return Chip(
            label: Text(
              path,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onDeleted: () => _removeExternalModelPath(path),
          );
        }).toList(),
      ),
    ];
  }

  Future<void> _addExternalModelPath() async {
    var inputValue = '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加外部模型目录'),
        content: TextFormField(
          autofocus: true,
          maxLines: 2,
          onChanged: (v) => inputValue = v,
          decoration: const InputDecoration(
            hintText: '/path/to/models',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, inputValue),
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (value == null || value.trim().isEmpty) return;

    final dir = Directory(value.trim());
    if (!await dir.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目录不存在，请检查路径')),
        );
      }
      return;
    }

    await ModelDownloadManager().addExternalModelSearchPath(value.trim());
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已添加外部模型目录')),
      );
    }
  }

  Future<void> _removeExternalModelPath(String path) async {
    final manager = ModelDownloadManager();
    final current = manager.getExternalModelSearchPaths();
    final updated = current.where((p) => p != path).toList();
    await manager.setExternalModelSearchPaths(updated);
    if (mounted) {
      setState(() {});
    }
  }

  String _friendlyErrorMessage(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '操作失败，请重试';
    }
    final text = raw.trim();
    if (text.contains('仅支持通过 HTTPS')) {
      return '下载地址无效，请使用 HTTPS 链接';
    }
    if (text.contains('下载来源不受信任')) {
      return '下载来源不受信任，请检查模型源配置';
    }
    if (text.contains('zip 文件过大')) {
      return '模型压缩包过大，已拒绝处理';
    }
    if (text.contains('zip 条目')) {
      return '模型压缩包结构异常，无法解压';
    }
    if (text.contains('SHA-256')) {
      return '模型文件完整性校验失败，请重新下载';
    }
    if (text.contains('下载进行中，暂时无法清理缓存')) {
      return '下载进行中，暂时无法清理缓存';
    }
    if (text.contains('SocketException') || text.contains('TimeoutException')) {
      return '网络连接失败或超时，请稍后重试';
    }
    return '操作失败，请重试';
  }

  String _modelUsageHint(
    String engineId, {
    bool hasBuiltinModels = false,
    bool hasDownloadableModels = false,
  }) {
    if (engineId == 'apple_speech') {
      return '点按选择并加载；仅支持文件转写，暂不支持实时 PCM 转写（仅 iOS/macOS 可用）';
    }

    if (hasBuiltinModels) {
      if (hasDownloadableModels) {
        return '点按可直接使用内置模型；也可以下载其他版本后切换';
      }
      if (engineId == 'sensevoice_onnx') {
        return '点按选择并加载；模型与配置文件均已内置本地（无需下载）';
      }
      return '点按选择并加载；模型已内置本地（无需下载）';
    }

    if (engineId == 'sensevoice_onnx') {
      return '点按选择并加载；长按可设置自定义路径（目录需包含 model_sherpa.onnx/model_quant.onnx/model.onnx 与 tokens）';
    }
    if (engineId == 'whisper' && (Platform.isIOS || Platform.isMacOS)) {
      return '点按选择并加载；长按可设置自定义路径（目录需包含 encoder/decoder ONNX 与 tokens.txt）';
    }
    if (engineId == 'vosk' && (Platform.isIOS || Platform.isMacOS)) {
      return '点按选择并加载；长按可设置自定义路径（目录需包含 model.onnx 或 encoder/decoder/joiner 与 tokens.txt）';
    }
    return '点按选择并加载；长按可设置自定义路径';
  }

  String _builtinFilesPreview(List<String> files) {
    if (files.isEmpty) return '无';
    if (files.length <= 3) {
      return files.join(', ');
    }
    final head = files.take(3).join(', ');
    final remaining = files.length - 3;
    return '$head 等 $remaining 个文件';
  }

  String _recommendedModelDir(String engineId) {
    if (engineId == 'whisper' && (Platform.isIOS || Platform.isMacOS)) {
      return '${Directory.systemTemp.path}/whisper-onnx';
    }
    if (engineId == 'vosk' && (Platform.isIOS || Platform.isMacOS)) {
      return '${Directory.systemTemp.path}/vosk-onnx';
    }

    switch (engineId) {
      case 'sensevoice_onnx':
        return '/storage/emulated/0/Android/data/com.sanbo.voices/files/models/sensevoice-onnx';
      default:
        return '/storage/emulated/0/voices/models/$engineId';
    }
  }
}
