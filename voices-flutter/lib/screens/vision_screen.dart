import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../services/vision_service.dart';

/// 图像理解界面
class VisionScreen extends ConsumerStatefulWidget {
  const VisionScreen({super.key});

  @override
  ConsumerState<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends ConsumerState<VisionScreen> {
  final VisionService _visionService = VisionService();

  bool _isInferring = false;
  String? _selectedImagePath;
  String? _result;
  String? _error;
  final TextEditingController _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initVision();
  }

  Future<void> _initVision() async {
    // TODO: 从设置中获取 Vision 模型路径
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedImagePath = result.files.first.path;
          _result = null;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _understand() async {
    if (_selectedImagePath == null) {
      setState(() {
        _error = '请先选择一张图片';
      });
      return;
    }

    if (!_visionService.isLoaded) {
      setState(() {
        _error = '请在设置中配置 Vision 模型';
      });
      return;
    }

    setState(() {
      _isInferring = true;
      _error = null;
      _result = null;
    });

    try {
      final visionResult = await _visionService.understand(
        _selectedImagePath!,
        question: _questionController.text.trim().isEmpty
            ? null
            : _questionController.text.trim(),
      );

      setState(() {
        _isInferring = false;
        if (visionResult != null) {
          _result = visionResult.description;
        } else {
          _error = _visionService.errorMessage ?? '图像理解失败';
        }
      });
    } catch (e) {
      setState(() {
        _isInferring = false;
        _error = e.toString();
      });
    }
  }

  void _clear() {
    setState(() {
      _selectedImagePath = null;
      _result = null;
      _error = null;
      _questionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('图像理解'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.refresh),
            tooltip: '重置',
          ),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatusCard(context),
                const SizedBox(height: 12),
                Expanded(child: _buildImagePanel(context)),
                const SizedBox(height: 12),
                _buildResultPanel(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = _visionService.state;

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
              Icon(Icons.image_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Vision 引擎',
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
            _visionService.isLoaded
                ? '已加载 ${_visionService.modelName ?? "模型"}'
                : '请在设置中配置 Vision 模型',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          if (_visionService.isLoaded) ...[
            const SizedBox(height: 4),
            Text(
              '支持格式: ${_visionService.supportedFormats.join(", ")}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePanel(BuildContext context) {
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
              Icon(Icons.image_outlined, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '图像',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('选择图片'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _selectedImagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_selectedImagePath!),
                      fit: BoxFit.contain,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 64,
                          color: cs.outlineVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '点击上方按钮选择图片',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          // 问题输入
          TextField(
            controller: _questionController,
            maxLines: 1,
            decoration: InputDecoration(
              hintText: '可以向模型提问关于这张图片的问题...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded),
                onPressed: _isInferring ? null : _understand,
              ),
            ),
            onSubmitted: (_) => _understand(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel(BuildContext context) {
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '图像描述',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isInferring)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_result != null)
            SelectableText(
              _result!,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: cs.error, fontSize: 14),
            )
          else
            Text(
              '图像理解结果将显示在这里',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: _isInferring || !_visionService.isLoaded
                    ? cs.surfaceContainerHighest
                    : cs.primary,
                foregroundColor: _isInferring || !_visionService.isLoaded
                    ? cs.onSurfaceVariant
                    : cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isInferring ||
                      !_visionService.isLoaded ||
                      _selectedImagePath == null
                  ? null
                  : _understand,
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('理解图像'),
            ),
          ),
        ],
      ),
    );
  }

  String _stateLabel(VisionServiceState state) {
    switch (state) {
      case VisionServiceState.ready:
        return '就绪';
      case VisionServiceState.loading:
        return '加载中';
      case VisionServiceState.inferring:
        return '推理中';
      case VisionServiceState.error:
        return '错误';
      case VisionServiceState.idle:
        return '未加载';
    }
  }

  Color _stateColor(ColorScheme cs, VisionServiceState state) {
    switch (state) {
      case VisionServiceState.ready:
        return Colors.green;
      case VisionServiceState.loading:
      case VisionServiceState.inferring:
        return cs.primary;
      case VisionServiceState.error:
        return cs.error;
      case VisionServiceState.idle:
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
