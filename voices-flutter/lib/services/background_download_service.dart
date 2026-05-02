import 'dart:io';

import 'package:flutter/services.dart';

/// 后台下载状态
enum BackgroundDownloadStatus {
  idle,
  started,
  downloading,
  completed,
  error,
  cancelled,
}

/// 后台下载事件
class BackgroundDownloadEvent {
  final String id;
  final BackgroundDownloadStatus status;
  final double progress;
  final String? error;

  const BackgroundDownloadEvent({
    required this.id,
    required this.status,
    required this.progress,
    this.error,
  });

  factory BackgroundDownloadEvent.fromMap(Map<dynamic, dynamic> map) {
    return BackgroundDownloadEvent(
      id: map['id'] as String? ?? '',
      status: _parseStatus(map['status'] as String? ?? 'idle'),
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      error: map['error'] as String?,
    );
  }

  static BackgroundDownloadStatus _parseStatus(String status) {
    switch (status) {
      case 'started':
        return BackgroundDownloadStatus.started;
      case 'downloading':
        return BackgroundDownloadStatus.downloading;
      case 'completed':
        return BackgroundDownloadStatus.completed;
      case 'error':
        return BackgroundDownloadStatus.error;
      case 'cancelled':
        return BackgroundDownloadStatus.cancelled;
      default:
        return BackgroundDownloadStatus.idle;
    }
  }
}

/// iOS 后台下载服务
///
/// 使用 NSURLSession 实现系统级后台下载，支持 app 后台运行时继续下载。
/// 仅在 iOS 平台可用，其他平台回退到 Dart Dio 下载。
class BackgroundDownloadService {
  static final BackgroundDownloadService _instance =
      BackgroundDownloadService._internal();
  factory BackgroundDownloadService() => _instance;
  BackgroundDownloadService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.sanbo.voices/background_download');
  static const EventChannel _eventChannel =
      EventChannel('com.sanbo.voices/background_download_events');

  Stream<BackgroundDownloadEvent>? _eventStream;
  final Map<String, void Function(BackgroundDownloadEvent)> _listeners = {};

  /// 是否支持后台下载（仅 iOS）
  bool get isSupported => Platform.isIOS;

  /// 获取事件流
  Stream<BackgroundDownloadEvent> get eventStream {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) =>
            BackgroundDownloadEvent.fromMap(event as Map<dynamic, dynamic>));
    return _eventStream!;
  }

  /// 监听特定下载任务的事件
  void listen(String downloadId,
      void Function(BackgroundDownloadEvent) listener) {
    _listeners[downloadId] = listener;

    eventStream.listen((event) {
      if (event.id == downloadId) {
        listener(event);
      }
    });
  }

  /// 移除监听
  void removeListener(String downloadId) {
    _listeners.remove(downloadId);
  }

  /// 开始后台下载
  Future<void> startDownload({
    required String downloadId,
    required String url,
    required String destPath,
    Map<String, String> headers = const {},
  }) async {
    if (!isSupported) {
      throw UnsupportedError('后台下载仅支持 iOS 平台');
    }

    await _channel.invokeMethod('startDownload', {
      'downloadId': downloadId,
      'url': url,
      'destPath': destPath,
      'headers': headers,
    });
  }

  /// 取消下载
  Future<void> cancelDownload(String downloadId) async {
    if (!isSupported) return;

    await _channel.invokeMethod('cancelDownload', {
      'downloadId': downloadId,
    });
  }

  /// 获取下载状态
  Future<Map<String, dynamic>> getDownloadStatus(String downloadId) async {
    if (!isSupported) {
      return {'id': downloadId, 'status': 'idle', 'progress': 0.0};
    }

    final result = await _channel.invokeMethod('getDownloadStatus', {
      'downloadId': downloadId,
    });
    return Map<String, dynamic>.from(result as Map);
  }
}
