import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/engine_instance.dart';
import '../providers/providers.dart';
import '../services/audio_recorder_service.dart';
import '../services/transcription_service.dart';

/// 主屏幕 - 实时语音转写
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final AudioRecorderService _recorder = AudioRecorderService();
  late final TranscriptionService _transcriptionService;

  bool _isRecording = false;
  bool _isTranscribing = false;
  String _liveText = '';
  String _finalText = '';
  String? _error;
  double _amplitude = 0;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  DateTime? _recordingStartedAt;
  DateTime? _lastTranscribeAt;
  Duration _transcribeMinInterval = const Duration(milliseconds: 900);
  bool _tickBusy = false;
  int _lastTranscribedOffsetBytes = 0;
  static const int _minDeltaBytesForTranscribe = 16000;
  Timer? _metricsTimer;

  int _tickCount = 0;
  int _skipBusyCount = 0;
  int _skipIntervalCount = 0;
  int _skipDeltaCount = 0;
  int _skipNoAudioCount = 0;
  int _transcribeCount = 0;
  int _transcribeErrorCount = 0;
  int _transcribeLatencyTotalMs = 0;
  int _transcribeLatencyMaxMs = 0;
  int _lastTranscribeLatencyMs = 0;
  String? _lastAutoLoadedInstanceId;
  String _lastRealtimeChunk = '';
  int _silenceMs = 0;
  static const int _tickMs = 500;

  @override
  void initState() {
    super.initState();
    _transcriptionService = TranscriptionService();
    _initEngineIfPossible();
  }

  Future<void> _initEngineIfPossible() async {
    final activeInstance = ref.read(activeInstanceProvider);
    if (activeInstance == null) {
      return;
    }
    await _transcriptionService.loadEngine(activeInstance);
    _lastAutoLoadedInstanceId = activeInstance.id;
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _autoLoadEngineIfNeeded(EngineInstance? activeInstance) async {
    if (activeInstance == null) return;
    if (_isRecording || _isTranscribing) return;
    if (_transcriptionService.state == TranscriptionServiceState.ready &&
        _lastAutoLoadedInstanceId == activeInstance.id) {
      return;
    }
    if (_transcriptionService.state == TranscriptionServiceState.error &&
        _lastAutoLoadedInstanceId == activeInstance.id) {
      return;
    }
    if (_lastAutoLoadedInstanceId == activeInstance.id &&
        _transcriptionService.state == TranscriptionServiceState.loading) {
      return;
    }

    _lastAutoLoadedInstanceId = activeInstance.id;
    await _transcriptionService.loadEngine(activeInstance);
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _metricsTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
      return;
    }
    await _startRecording();
  }

  Future<void> _startRecording() async {
    final activeInstance = ref.read(activeInstanceProvider);
    if (activeInstance == null) {
      _showSnack('请先在设置中选择模型');
      return;
    }

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        setState(() {
          _error = '未获取麦克风权限';
        });
        return;
      }

      await _transcriptionService.loadEngine(activeInstance);
      await _recorder.startRecording();

      _recordingStartedAt = DateTime.now();
      _lastTranscribeAt = null;
      _lastTranscribedOffsetBytes = 0;
      _transcribeMinInterval = const Duration(milliseconds: 900);
      _resetRuntimeMetrics();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _onRealtimeTick());
      _metricsTimer?.cancel();
      _metricsTimer = Timer.periodic(const Duration(seconds: 10), (_) => _logRealtimeMetrics('periodic'));

      setState(() {
        _isRecording = true;
        _error = null;
        _liveText = '';
        _finalText = '';
        _lastRealtimeChunk = '';
        _silenceMs = 0;
        _elapsed = Duration.zero;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _pickAndTranscribeFile() async {
    final activeInstance = ref.read(activeInstanceProvider);
    if (activeInstance == null) {
      _showSnack('请先在设置中选择模型');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      if (file.path == null) {
        _showSnack('无法获取文件路径');
        return;
      }

      setState(() {
        _isTranscribing = true;
        _error = null;
      });

      await _transcriptionService.loadEngine(activeInstance);

      final sw = Stopwatch()..start();
      final transcriptionResult = await _transcriptionService.transcribeFile(
        file.path!,
        enablePunctuation: true,
      );
      sw.stop();

      final text = transcriptionResult.text.trim();
      developer.log(
        'file_transcribe file=${file.name} duration_ms=${sw.elapsedMilliseconds} text_len=${text.length}',
        name: 'voices.file',
      );

      setState(() {
        _isTranscribing = false;
        _finalText = text;
        _liveText = '';
      });

      if (text.isNotEmpty && !text.startsWith('Error:')) {
        _showSnack('文件转写完成');
      } else if (text.startsWith('Error:')) {
        setState(() {
          _error = text;
        });
      }
    } catch (e) {
      setState(() {
        _isTranscribing = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _onRealtimeTick() async {
    if (!_isRecording) return;
    if (_tickBusy) {
      _skipBusyCount++;
      return;
    }

    _tickBusy = true;
    _tickCount++;
    try {
      final startAt = _recordingStartedAt;
      if (startAt != null) {
        _elapsed = DateTime.now().difference(startAt);
      }

      _amplitude = await _recorder.getAmplitude();
      if (_amplitude < 0.08) {
        _silenceMs += _tickMs;
      } else {
        _silenceMs = 0;
      }

      final now = DateTime.now();
      if (_lastTranscribeAt != null && now.difference(_lastTranscribeAt!) < _transcribeMinInterval) {
        _skipIntervalCount++;
        if (mounted) setState(() {});
        return;
      }

      final capturedBytes = _recorder.totalCapturedBytes;
      final deltaBytes = capturedBytes - _lastTranscribedOffsetBytes;
      if (deltaBytes < _minDeltaBytesForTranscribe) {
        _skipDeltaCount++;
        if (mounted) setState(() {});
        return;
      }

      final audio = await _recorder.getCurrentAudio();
      if (audio == null || audio.data.length < 3200) {
        _skipNoAudioCount++;
        if (mounted) setState(() {});
        return;
      }

      _lastTranscribeAt = now;
      _isTranscribing = true;
      if (mounted) setState(() {});
      final sw = Stopwatch()..start();
      final result = await _transcriptionService.transcribe(
        audio,
        enablePunctuation: false,
      );
      sw.stop();
      _transcribeCount++;
      final costMs = sw.elapsedMilliseconds;
      _lastTranscribeLatencyMs = costMs;
      _transcribeLatencyTotalMs += costMs;
      if (costMs > _transcribeLatencyMaxMs) {
        _transcribeLatencyMaxMs = costMs;
      }
      final text = result.text.trim();

      if (text.isNotEmpty && !text.startsWith('Error:')) {
        _appendRealtimeText(text);
        _lastTranscribedOffsetBytes = capturedBytes;
      }

      if (costMs > 1600) {
        _transcribeMinInterval = const Duration(milliseconds: 1800);
      } else if (costMs > 900) {
        _transcribeMinInterval = const Duration(milliseconds: 1300);
      } else {
        _transcribeMinInterval = const Duration(milliseconds: 900);
      }

      if (mounted) setState(() {});
    } catch (e) {
      _transcribeErrorCount++;
      _error = e.toString();
      if (mounted) setState(() {});
    } finally {
      _isTranscribing = false;
      _tickBusy = false;
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _timer = null;
    _metricsTimer?.cancel();
    _metricsTimer = null;

    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    try {
      final audio = await _recorder.stopRecording();
      if (audio == null) {
        setState(() {
          _error = '录音数据为空';
          _isTranscribing = false;
        });
        return;
      }

      final result = await _transcriptionService.transcribe(audio);
      final finalText = _applyProsodyPunctuation(result.text.trim());

      setState(() {
        _isTranscribing = false;
        _amplitude = 0;
        _finalText = _mergeFinalText(finalText);
      });

      if (_recorder.finalAudioTruncated && mounted) {
        _showSnack('录音超过 120 秒，已自动截断前段音频以保证稳定性。');
      }
      _logRealtimeMetrics('stop');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isTranscribing = false;
      });
      _logRealtimeMetrics('stop_with_error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeInstance = ref.watch(activeInstanceProvider);
    if (activeInstance != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoLoadEngineIfNeeded(activeInstance);
      });
    }
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('实时语音转写'),
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
              children: [
                _buildStatusCard(context, activeInstance),
                const SizedBox(height: 12),
                Expanded(child: _buildTranscriptPanel(context)),
                const SizedBox(height: 12),
                _buildControlPanel(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, EngineInstance? activeInstance) {
    final cs = Theme.of(context).colorScheme;
    final state = _transcriptionService.state;

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
              Icon(Icons.memory_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                activeInstance?.engineId ?? '未选择模型',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
            '当前仅使用手机本地模型进行转写，不调用外部服务。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = _finalText.isNotEmpty ? _finalText : _liveText;

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
          Row(
            children: [
              Icon(Icons.subtitles_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                _isRecording ? '实时字幕' : '转写结果',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (text.isNotEmpty)
                IconButton(
                  tooltip: '复制文本',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!mounted) return;
                    _showSnack('已复制文本');
                  },
                  icon: const Icon(Icons.content_copy_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _error != null
                ? Center(
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.error),
                    ),
                  )
                : text.isEmpty
                    ? Center(
                        child: Text(
                          _isRecording ? '正在听你说话...' : '点击下方按钮开始实时语音转文字',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          text,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
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
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: cs.primary),
              const SizedBox(width: 6),
              Text(_formatDuration(_elapsed)),
              const SizedBox(width: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: _isRecording ? _amplitude.clamp(0.02, 1.0) : 0,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (_isTranscribing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: _isRecording ? cs.error : cs.primary,
                    foregroundColor: _isRecording ? cs.onError : cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  // 录音中始终允许点击”停止”，避免实时转写阶段按钮闪烁不可点。
                  onPressed: (_isRecording || !_isTranscribing) ? _toggleRecording : null,
                  icon: Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic_rounded),
                  label: Text(_isRecording ? '停止并生成文本' : '开始实时转写'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isRecording || _isTranscribing ? null : _pickAndTranscribeFile,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text(''),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _stateLabel(TranscriptionServiceState state) {
    switch (state) {
      case TranscriptionServiceState.ready:
        return '就绪';
      case TranscriptionServiceState.loading:
        return '加载中';
      case TranscriptionServiceState.transcribing:
        return '识别中';
      case TranscriptionServiceState.error:
        return '错误';
      case TranscriptionServiceState.idle:
        return '未启动';
    }
  }

  Color _stateColor(ColorScheme cs, TranscriptionServiceState state) {
    switch (state) {
      case TranscriptionServiceState.ready:
        return Colors.green;
      case TranscriptionServiceState.loading:
      case TranscriptionServiceState.transcribing:
        return cs.primary;
      case TranscriptionServiceState.error:
        return cs.error;
      case TranscriptionServiceState.idle:
        return cs.onSurfaceVariant;
    }
  }

  String _formatDuration(Duration value) {
    final m = value.inMinutes.toString().padLeft(2, '0');
    final s = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _appendRealtimeText(String chunk) {
    final current = chunk.trim();
    if (current.isEmpty) return;

    String delta = current;
    final previous = _lastRealtimeChunk;
    if (previous.isNotEmpty) {
      if (current == previous) {
        return;
      }
      if (current.startsWith(previous)) {
        delta = current.substring(previous.length);
      } else {
        final overlap = _longestSuffixPrefix(previous, current);
        if (overlap > 0) {
          delta = current.substring(overlap);
        } else if (previous.contains(current)) {
          delta = '';
        }
      }
    }
    _lastRealtimeChunk = current;
    if (delta.trim().isEmpty) return;

    if (_liveText.isNotEmpty && _silenceMs >= 900) {
      final end = _liveText[_liveText.length - 1];
      if (!RegExp(r'[，。！？,.!?]$').hasMatch(end)) {
        _liveText = '$_liveText，';
      }
    }

    if (_liveText.isEmpty) {
      _liveText = delta.trimLeft();
      return;
    }

    final needsSpace = RegExp(r'[A-Za-z0-9]$').hasMatch(_liveText) &&
        RegExp(r'^[A-Za-z0-9]').hasMatch(delta);
    _liveText = '$_liveText${needsSpace ? ' ' : ''}$delta';
  }

  int _longestSuffixPrefix(String left, String right) {
    final max = left.length < right.length ? left.length : right.length;
    for (int n = max; n > 0; n--) {
      if (left.substring(left.length - n) == right.substring(0, n)) {
        return n;
      }
    }
    return 0;
  }

  String _mergeFinalText(String finalText) {
    final finalTrim = finalText.trim();
    final liveTrim = _liveText.trim();
    if (finalTrim.isEmpty) return liveTrim;
    if (liveTrim.isEmpty) return finalTrim;
    if (finalTrim.startsWith(liveTrim)) return finalTrim;
    if (liveTrim.startsWith(finalTrim)) return liveTrim;
    return '$liveTrim\n$finalTrim';
  }

  String _applyProsodyPunctuation(String text) {
    if (text.isEmpty || text.startsWith('Error:')) return text;
    if (RegExp(r'[。！？.!?]$').hasMatch(text)) return text;

    final isQuestion = RegExp(r'(吗|么|呢|是否|是不是|为什么|怎么|如何|why|what|how)', caseSensitive: false)
        .hasMatch(text);
    final isExclaim = RegExp(r'(太|真|好|棒|厉害|wow|great|amazing)', caseSensitive: false)
        .hasMatch(text);
    final hasChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);

    if (hasChinese) {
      if (isQuestion) return '$text？';
      if (isExclaim) return '$text！';
      return '$text。';
    }

    if (isQuestion) return '$text?';
    if (isExclaim) return '$text!';
    return '$text.';
  }

  void _resetRuntimeMetrics() {
    _tickCount = 0;
    _skipBusyCount = 0;
    _skipIntervalCount = 0;
    _skipDeltaCount = 0;
    _skipNoAudioCount = 0;
    _transcribeCount = 0;
    _transcribeErrorCount = 0;
    _transcribeLatencyTotalMs = 0;
    _transcribeLatencyMaxMs = 0;
    _lastTranscribeLatencyMs = 0;
  }

  void _logRealtimeMetrics(String reason) {
    final avgLatency = _transcribeCount == 0
        ? 0
        : (_transcribeLatencyTotalMs / _transcribeCount).round();

    developer.log(
      'reason=$reason '
      'ticks=$_tickCount '
      'transcribe=$_transcribeCount '
      'transcribe_err=$_transcribeErrorCount '
      'latency_ms_last=$_lastTranscribeLatencyMs '
      'latency_ms_avg=$avgLatency '
      'latency_ms_max=$_transcribeLatencyMaxMs '
      'skip_busy=$_skipBusyCount '
      'skip_interval=$_skipIntervalCount '
      'skip_delta=$_skipDeltaCount '
      'skip_no_audio=$_skipNoAudioCount '
      'bytes_total=${_recorder.totalCapturedBytes} '
      'bytes_rt_window=${_recorder.realtimeWindowBytes} '
      'bytes_final_buffered=${_recorder.finalBufferedBytes} '
      'bytes_rt_dropped=${_recorder.droppedRealtimeBytes} '
      'bytes_final_dropped=${_recorder.droppedFinalBytes}',
      name: 'voices.realtime',
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
