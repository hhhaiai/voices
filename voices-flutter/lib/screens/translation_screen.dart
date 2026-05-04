import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/llm_service.dart';

/// 翻译方向
enum TranslationDirection {
  zhToEn('中文 → 英文'),
  enToZh('英文 → 中文'),
  auto('自动检测');

  final String label;
  const TranslationDirection(this.label);
}

/// 文字翻译界面
class TranslationScreen extends ConsumerStatefulWidget {
  const TranslationScreen({super.key});

  @override
  ConsumerState<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends ConsumerState<TranslationScreen> {
  final LlmService _llmService = LlmService();

  bool _isTranslating = false;
  String _sourceText = '';
  String _translatedText = '';
  TranslationDirection _direction = TranslationDirection.zhToEn;
  final TextEditingController _sourceController = TextEditingController();

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _sourceController.text.trim();
    if (text.isEmpty) return;
    if (!_llmService.isLoaded) return;

    setState(() {
      _isTranslating = true;
      _sourceText = text;
      _translatedText = '';
    });

    try {
      String sourceLang;
      String targetLang;
      switch (_direction) {
        case TranslationDirection.zhToEn:
          sourceLang = 'zh';
          targetLang = 'en';
        case TranslationDirection.enToZh:
          sourceLang = 'en';
          targetLang = 'zh';
        case TranslationDirection.auto:
          sourceLang = 'auto';
          targetLang = 'en';
      }

      final result = await _llmService.translateText(
        text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );

      setState(() {
        _isTranslating = false;
        if (result != null) {
          _translatedText = result.trim();
        }
      });
    } catch (e) {
      setState(() {
        _isTranslating = false;
      });
    }
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceText;
      _sourceText = _translatedText;
      _translatedText = temp;
      _sourceController.text = _sourceText;

      switch (_direction) {
        case TranslationDirection.zhToEn:
          _direction = TranslationDirection.enToZh;
        case TranslationDirection.enToZh:
          _direction = TranslationDirection.zhToEn;
        case TranslationDirection.auto:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文字翻译'),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatusCard(context),
                const SizedBox(height: 12),
                Expanded(child: _buildTranslationPanel(context)),
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
              Icon(Icons.translate_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '翻译引擎',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              _StatusBadge(
                label: _llmService.isLoaded ? '就绪' : '未加载',
                color: _llmService.isLoaded ? Colors.green : cs.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _llmService.isLoaded
                ? '已加载 ${_llmService.modelName ?? "LLM"} 进行翻译'
                : '请在设置中配置 LLM 模型用于翻译',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationPanel(BuildContext context) {
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
              Icon(Icons.swap_horiz_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '翻译方向',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              SegmentedButton<TranslationDirection>(
                segments: TranslationDirection.values.map((d) {
                  return ButtonSegment(
                    value: d,
                    label: Text(d.label, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                selected: {_direction},
                onSelectionChanged: (selection) {
                  setState(() {
                    _direction = selection.first;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '源文本',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _sourceController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: '输入要翻译的文字...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: IconButton.filledTonal(
              onPressed: _swapLanguages,
              icon: const Icon(Icons.swap_vert_rounded),
              tooltip: '交换语言',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '翻译结果',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isTranslating
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: SelectableText(
                        _translatedText.isEmpty
                            ? '翻译结果将显示在这里'
                            : _translatedText,
                        style: TextStyle(
                          color: _translatedText.isEmpty
                              ? cs.onSurfaceVariant
                              : cs.onSurface,
                        ),
                      ),
                    ),
            ),
          ),
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
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor:
                    _isTranslating ? cs.surfaceContainerHighest : cs.primary,
                foregroundColor:
                    _isTranslating ? cs.onSurfaceVariant : cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isTranslating || !_llmService.isLoaded
                  ? null
                  : _translate,
              icon: _isTranslating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.translate_rounded),
              label: Text(_isTranslating ? '翻译中...' : '翻译'),
            ),
          ),
        ],
      ),
    );
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
