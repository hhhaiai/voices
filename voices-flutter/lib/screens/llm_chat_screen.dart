import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engines/base/llm_backend.dart';
import '../services/llm_service.dart';

/// LLM 对话界面
class LlmChatScreen extends ConsumerStatefulWidget {
  const LlmChatScreen({super.key});

  @override
  ConsumerState<LlmChatScreen> createState() => _LlmChatScreenState();
}

class _LlmChatScreenState extends ConsumerState<LlmChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final LlmService _llmService = LlmService();
  final ScrollController _scrollController = ScrollController();

  bool _isInferring = false;
  String? _error;
  double _temperature = 0.7;
  final List<_ChatBubble> _messages = [];

  // 流式输出缓冲
  String _streamingBuffer = '';

  @override
  void initState() {
    super.initState();
    _initLlm();
  }

  Future<void> _initLlm() async {
    // TODO: 从设置中获取 LLM 模型路径
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (!_llmService.isLoaded) {
      setState(() {
        _error = '请在设置中配置 LLM 模型';
      });
      return;
    }

    setState(() {
      _isInferring = true;
      _error = null;
      _streamingBuffer = '';
      // 添加用户消息
      _messages.add(_ChatBubble(
        role: LlmMessageRole.user,
        content: text,
      ));
    });

    _textController.clear();

    try {
      // 使用流式推理
      await for (final result in _llmService.streamInfer(
        text,
        temperature: _temperature,
      )) {
        if (!mounted) return;

        setState(() {
          if (result.done) {
            // 推理完成
            if (result.fullText != null && result.fullText!.isNotEmpty) {
              _messages.add(_ChatBubble(
                role: LlmMessageRole.assistant,
                content: result.fullText!,
              ));
            }
            _streamingBuffer = '';
            _isInferring = false;
          } else {
            // 流式输出
            _streamingBuffer += result.delta;
            // 更新最后一条助手消息
            if (_messages.isNotEmpty &&
                _messages.last.role == LlmMessageRole.user) {
              _messages.add(_ChatBubble(
                role: LlmMessageRole.assistant,
                content: _streamingBuffer,
                isStreaming: true,
              ));
            } else if (_messages.isNotEmpty &&
                _messages.last.role == LlmMessageRole.assistant) {
              _messages[_messages.length - 1] = _ChatBubble(
                role: LlmMessageRole.assistant,
                content: _streamingBuffer,
                isStreaming: true,
              );
            }
          }
        });

        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isInferring = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _stopInference() {
    _llmService.stopInference();
    setState(() {
      _isInferring = false;
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _streamingBuffer = '';
    });
    _llmService.createSession();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 对话'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空对话',
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
          child: Column(
            children: [
              _buildStatusCard(context),
              Expanded(child: _buildMessageList(context)),
              _buildInputPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = _llmService.state;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
              Icon(Icons.psychology_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'LLM 引擎',
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
            _llmService.isLoaded
                ? '已加载 ${_llmService.modelName ?? "模型"}，上下文 ${_llmService.contextLength} tokens'
                : '请在设置中配置 LLM 模型',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(
              '开始对话吧',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _MessageBubble(
          message: msg,
          isUser: msg.role == LlmMessageRole.user,
        );
      },
    );
  }

  Widget _buildInputPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 温度调节
          Row(
            children: [
              Text(
                '温度 ${_temperature.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Expanded(
                child: Slider(
                  value: _temperature,
                  min: 0.1,
                  max: 2.0,
                  divisions: 19,
                  onChanged: (value) {
                    setState(() {
                      _temperature = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 输入和按钮
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: _isInferring ? null : _send,
                    ),
                  ),
                ),
              ),
              if (_isInferring) ...[
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _stopInference,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text(''),
                ),
              ],
            ],
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

  String _stateLabel(LlmServiceState state) {
    switch (state) {
      case LlmServiceState.ready:
        return '就绪';
      case LlmServiceState.loading:
        return '加载中';
      case LlmServiceState.inferring:
        return '推理中';
      case LlmServiceState.error:
        return '错误';
      case LlmServiceState.idle:
        return '未加载';
    }
  }

  Color _stateColor(ColorScheme cs, LlmServiceState state) {
    switch (state) {
      case LlmServiceState.ready:
        return Colors.green;
      case LlmServiceState.loading:
      case LlmServiceState.inferring:
        return cs.primary;
      case LlmServiceState.error:
        return cs.error;
      case LlmServiceState.idle:
        return cs.onSurfaceVariant;
    }
  }
}

class _ChatBubble {
  final LlmMessageRole role;
  final String content;
  final bool isStreaming;

  const _ChatBubble({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatBubble message;
  final bool isUser;

  const _MessageBubble({
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor =
        isUser ? cs.primaryContainer : cs.surfaceContainerHighest;
    final textColor = isUser ? cs.onPrimaryContainer : cs.onSurface;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                message.content,
                style: TextStyle(color: textColor),
              ),
            ),
            if (message.isStreaming) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: textColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
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
