import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tts_service.dart';
import '../services/model_download_manager.dart';

/// TTS 文字转语音界面
class TtsScreen extends ConsumerStatefulWidget {
  const TtsScreen({super.key});

  @override
  ConsumerState<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends ConsumerState<TtsScreen> {
  final TextEditingController _textController = TextEditingController();
  final TtsService _ttsService = TtsService();

  bool _isPlaying = false;
  bool _isGenerating = false;
  String? _error;
  int _selectedSpeaker = 0;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    // 优先尝试从内置模型加载 TTS
    try {
      final modelPath =
          await ModelDownloadManager().getBuiltinModelPath('sherpa_tts');
      if (modelPath != null && modelPath.isNotEmpty) {
        final success = await _ttsService.loadModel(modelPath);
        if (success) return;
      }
    } catch (_) {
      // ignore
    }

    // 尝试从已下载模型中加载 TTS
    try {
      final modelDir = await ModelDownloadManager().getModelDir();
      final ttsDir = Directory('$modelDir/tts');
      if (await ttsDir.exists()) {
        final entries = await ttsDir.list().toList();
        for (final entry in entries) {
          if (entry is Directory) {
            final modelPath = entry.path;
            final success = await _ttsService.loadModel(modelPath);
            if (success) return;
          }
        }
      }
    } catch (_) {
      // 忽略错误，静默等待用户在设置中下载模型
    }

    // 目前无内置 TTS 模型，需要用户在设置中下载
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _error = '请输入要转换的文字';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final success = await _ttsService.speak(
        text,
        speakerId: _selectedSpeaker,
        speed: _speed,
      );

      setState(() {
        _isGenerating = false;
        if (!success) {
          _error = _ttsService.errorMessage ?? '语音生成失败';
        }
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _stop() async {
    await _ttsService.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文字转语音'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.35),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(context),
                const SizedBox(height: 12),
                Expanded(child: _buildInputCard(context)),
                const SizedBox(height: 12),
                _buildControlPanel(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = _ttsService.state;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volume_up_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'TTS 引擎',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              _StatusBadge(
                label: _stateLabel(state),
                color: _stateColor(cs, state),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _ttsService.isLoaded
                ? '已加载模型，支持 ${_ttsService.numSpeakers} 个声音'
                : '请在设置中配置 TTS 模型',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.text_fields_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '输入文字',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: '请输入要转换的文字...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: cs.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          // 声音和语速设置
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '声音 ${_selectedSpeaker + 1}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    DropdownButton<int>(
                      value: _selectedSpeaker,
                      isExpanded: true,
                      items: List.generate(
                        _ttsService.numSpeakers.clamp(1, 10),
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text('声音 ${i + 1}'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSpeaker = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '语速 ${_speed.toStringAsFixed(1)}x',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      value: _speed,
                      min: 0.5,
                      max: 2.0,
                      divisions: 6,
                      onChanged: (value) {
                        setState(() {
                          _speed = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 生成按钮
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: _isGenerating ? cs.surfaceContainerHighest : cs.primary,
                    foregroundColor: _isGenerating ? cs.onSurfaceVariant : cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isGenerating || !_ttsService.isLoaded ? null : _speak,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_circle_outline_rounded),
                  label: Text(_isGenerating ? '生成中...' : '生成并播放'),
                ),
              ),
              if (_isPlaying) ...[
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _stop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text(''),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _stateLabel(TtsServiceState state) {
    switch (state) {
      case TtsServiceState.ready:
        return '就绪';
      case TtsServiceState.loading:
        return '加载中';
      case TtsServiceState.generating:
        return '生成中';
      case TtsServiceState.playing:
        return '播放中';
      case TtsServiceState.error:
        return '错误';
      case TtsServiceState.idle:
        return '未加载';
    }
  }

  Color _stateColor(ColorScheme cs, TtsServiceState state) {
    switch (state) {
      case TtsServiceState.ready:
        return Colors.green;
      case TtsServiceState.loading:
      case TtsServiceState.generating:
      case TtsServiceState.playing:
        return cs.primary;
      case TtsServiceState.error:
        return cs.error;
      case TtsServiceState.idle:
        return cs.onSurfaceVariant;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
