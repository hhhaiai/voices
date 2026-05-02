import Flutter
import UIKit
import Speech
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var eventSink: FlutterEventSink?
    private let appleSpeechBridge = AppleSpeechBridge.shared
    private let backgroundDownloadManager = BackgroundDownloadManager()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if let controller = window?.rootViewController as? FlutterViewController {
            // Apple Speech 通道
            let channel = FlutterMethodChannel(
                name: "com.sanbo.voices/apple_speech",
                binaryMessenger: controller.binaryMessenger
            )

            let eventChannel = FlutterEventChannel(
                name: "com.sanbo.voices/apple_speech_events",
                binaryMessenger: controller.binaryMessenger
            )
            eventChannel.setStreamHandler(AppleSpeechEventStreamHandler(bridge: appleSpeechBridge))

            channel.setMethodCallHandler { [weak self] call, result in
                guard let self = self else { return }

                switch call.method {
                case "transcribeFile":
                    self.handleTranscribeFile(call: call, result: result)
                case "startPcmTranscription":
                    self.handleStartPcmTranscription(result: result)
                case "stopPcmTranscription":
                    self.handleStopPcmTranscription(result: result)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }

            // 后台下载通道
            let downloadChannel = FlutterMethodChannel(
                name: "com.sanbo.voices/background_download",
                binaryMessenger: controller.binaryMessenger
            )

            let downloadEventChannel = FlutterEventChannel(
                name: "com.sanbo.voices/background_download_events",
                binaryMessenger: controller.binaryMessenger
            )
            downloadEventChannel.setStreamHandler(DownloadEventStreamHandler(manager: backgroundDownloadManager))

            downloadChannel.setMethodCallHandler { [weak self] call, result in
                guard let self = self else { return }

                switch call.method {
                case "startDownload":
                    self.handleStartDownload(call: call, result: result)
                case "cancelDownload":
                    self.handleCancelDownload(call: call, result: result)
                case "getDownloadStatus":
                    self.handleGetDownloadStatus(call: call, result: result)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Background Download Completion

    func completeBackgroundDownload() {
        // 系统后台下载完成回调
        // 可以在这里发送本地通知
    }

    // MARK: - Background Download Handlers

    private func handleStartDownload(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let args = call.arguments as? [String: Any],
            let urlString = args["url"] as? String,
            let destPath = args["destPath"] as? String,
            let downloadId = args["downloadId"] as? String
        else {
            result(FlutterError(code: "bad_args", message: "缺少 url/destPath/downloadId", details: nil))
            return
        }

        let headers = args["headers"] as? [String: String] ?? [:]
        backgroundDownloadManager.startDownload(
            id: downloadId,
            url: urlString,
            destPath: destPath,
            headers: headers
        )
        result(nil)
    }

    private func handleCancelDownload(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let args = call.arguments as? [String: Any],
            let downloadId = args["downloadId"] as? String
        else {
            result(FlutterError(code: "bad_args", message: "缺少 downloadId", details: nil))
            return
        }

        backgroundDownloadManager.cancelDownload(id: downloadId)
        result(nil)
    }

    private func handleGetDownloadStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let args = call.arguments as? [String: Any],
            let downloadId = args["downloadId"] as? String
        else {
            result(FlutterError(code: "bad_args", message: "缺少 downloadId", details: nil))
            return
        }

        let status = backgroundDownloadManager.getDownloadStatus(id: downloadId)
        result(status)
    }

    private func handleTranscribeFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let args = call.arguments as? [String: Any],
            let filePath = args["filePath"] as? String
        else {
            result(FlutterError(code: "bad_args", message: "缺少 filePath", details: nil))
            return
        }

        appleSpeechBridge.transcribeFile(filePath: filePath) { transcribeResult in
            DispatchQueue.main.async {
                switch transcribeResult {
                case .success(let text):
                    result(text)
                case .failure(let error):
                    result("Error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleStartPcmTranscription(result: @escaping FlutterResult) {
        // eventSink 已在 application didFinishLaunchingWithOptions 中通过 EventChannel 设置
        // 这里直接启动识别即可
        appleSpeechBridge.startPcmTranscription { error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
                } else {
                    result(nil)
                }
            }
        }
    }

    private func handleStopPcmTranscription(result: @escaping FlutterResult) {
        appleSpeechBridge.stopPcmTranscription { finalText in
            DispatchQueue.main.async {
                if let text = finalText {
                    result(text)
                } else {
                    result(nil)
                }
            }
        }
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}

// EventChannel StreamHandler
class AppleSpeechEventStreamHandler: NSObject, FlutterStreamHandler {
    private weak var bridge: AppleSpeechBridge?

    init(bridge: AppleSpeechBridge) {
        self.bridge = bridge
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        bridge?.setEventSink { [weak self] text in
            events(text)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        bridge?.setEventSink(nil)
        return nil
    }
}

// MARK: - AppleSpeechBridge
final class AppleSpeechBridge {
    static let shared = AppleSpeechBridge()

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var eventSink: ((String) -> Void)?

    private init() {}

    func setEventSink(_ sink: ((String) -> Void)?) {
        self.eventSink = sink
    }

    func transcribeFile(
        filePath: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard #available(iOS 10.0, *) else {
            completion(.failure(NSError(domain: "AppleSpeech", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "当前系统版本不支持语音识别"
            ])))
            return
        }

        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                completion(.failure(NSError(domain: "AppleSpeech", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "未授权语音识别权限"
                ])))
                return
            }

            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) ?? SFSpeechRecognizer() else {
                completion(.failure(NSError(domain: "AppleSpeech", code: -3, userInfo: [
                    NSLocalizedDescriptionKey: "无法创建语音识别器"
                ])))
                return
            }

            let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: filePath))
            request.shouldReportPartialResults = false

            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                if let result = result, result.isFinal {
                    completion(.success(result.bestTranscription.formattedString))
                }
            }
        }
    }

    func startPcmTranscription(completion: @escaping (Error?) -> Void) {
        guard #available(iOS 13.0, *) else {
            completion(NSError(domain: "AppleSpeech", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "实时语音识别需要 iOS 13.0 或更高版本"
            ]))
            return
        }

        // 配置 AVAudioSession
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            completion(NSError(domain: "AppleSpeech", code: -6, userInfo: [
                NSLocalizedDescriptionKey: "无法配置音频会话: \(error.localizedDescription)"
            ]))
            return
        }

        // 检查权限
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                completion(NSError(domain: "AppleSpeech", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: "未授权语音识别权限"
                ]))
                return
            }

            guard let self = self else { return }

            do {
                // 创建 audio engine
                self.audioEngine = AVAudioEngine()
                guard let audioEngine = self.audioEngine else {
                    completion(NSError(domain: "AppleSpeech", code: -4, userInfo: [
                        NSLocalizedDescriptionKey: "无法创建音频引擎"
                    ]))
                    return
                }

                // 创建 recognition request
                self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                guard let recognitionRequest = self.recognitionRequest else {
                    completion(NSError(domain: "AppleSpeech", code: -5, userInfo: [
                        NSLocalizedDescriptionKey: "无法创建语音识别请求"
                    ]))
                    return
                }

                recognitionRequest.shouldReportPartialResults = true
                recognitionRequest.requiresOnDeviceRecognition = false

                // 获取输入节点并安装 tap
                let inputNode = audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)

                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                    self?.recognitionRequest?.append(buffer)
                }

                // 创建 recognizer
                guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) ?? SFSpeechRecognizer() else {
                    completion(NSError(domain: "AppleSpeech", code: -3, userInfo: [
                        NSLocalizedDescriptionKey: "无法创建语音识别器"
                    ]))
                    return
                }

                // 启动识别任务
                self.recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                        self?.eventSink?(text)

                        if result.isFinal {
                            self?.stopAudioEngine()
                        }
                    }

                    if let error = error {
                        self?.eventSink?("Error: \(error.localizedDescription)")
                        self?.stopAudioEngine()
                    }
                }

                // 启动 audio engine
                audioEngine.prepare()
                try audioEngine.start()

                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    func stopPcmTranscription(completion: @escaping (String?) -> Void) {
        stopAudioEngine()
        completion(nil)
    }

    private func stopAudioEngine() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }
}

// MARK: - Background Download Manager

final class BackgroundDownloadManager: NSObject {
    private var session: URLSession!
    private var activeDownloads: [String: URLSessionDownloadTask] = [:]
    private var downloadCallbacks: [String: (Double) -> Void] = [:]
    private var destPaths: [String: String] = [:]
    private var eventSink: FlutterEventSink?

    override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.sanbo.voices.download")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 3600 // 1 hour
        config.httpMaximumConnectionsPerHost = 3
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }

    func setEventSink(_ sink: FlutterEventSink?) {
        self.eventSink = sink
    }

    func startDownload(id: String, url: String, destPath: String, headers: [String: String]) {
        // 取消已有的下载
        cancelDownload(id: id)

        guard let downloadURL = URL(string: url) else {
            sendEvent(id: id, status: "error", progress: 0, error: "无效的下载地址")
            return
        }

        var request = URLRequest(url: downloadURL)
        request.setValue("Voices/1.0 (Flutter STT App)", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let task = session.downloadTask(with: request)
        task.taskDescription = id
        activeDownloads[id] = task
        destPaths[id] = destPath

        sendEvent(id: id, status: "started", progress: 0, error: nil)
        task.resume()
    }

    func cancelDownload(id: String) {
        activeDownloads[id]?.cancel()
        activeDownloads.removeValue(forKey: id)
        destPaths.removeValue(forKey: id)
        sendEvent(id: id, status: "cancelled", progress: 0, error: nil)
    }

    func getDownloadStatus(id: String) -> [String: Any] {
        if let task = activeDownloads[id] {
            let progress = task.progress
            return [
                "id": id,
                "status": "downloading",
                "progress": Double(progress.fractionCompleted),
                "totalBytes": progress.totalUnitCount,
                "receivedBytes": progress.completedUnitCount,
            ]
        }
        return ["id": id, "status": "idle", "progress": 0.0]
    }

    private func sendEvent(id: String, status: String, progress: Double, error: String?) {
        var event: [String: Any] = [
            "id": id,
            "status": status,
            "progress": progress,
        ]
        if let error = error {
            event["error"] = error
        }
        eventSink?(event)
    }
}

extension BackgroundDownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription else { return }

        let destPath = destPaths[id] ?? ""
        let destURL = URL(fileURLWithPath: destPath)

        do {
            // 确保目标目录存在
            let destDir = destURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: destPath) {
                try FileManager.default.removeItem(at: destURL)
            }

            // 移动下载文件到目标位置
            try FileManager.default.moveItem(at: location, to: destURL)

            sendEvent(id: id, status: "completed", progress: 1.0, error: nil)
        } catch {
            sendEvent(id: id, status: "error", progress: 0, error: error.localizedDescription)
        }

        activeDownloads.removeValue(forKey: id)
        destPaths.removeValue(forKey: id)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription else { return }

        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0

        sendEvent(id: id, status: "downloading", progress: progress, error: nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription, let error = error else { return }

        let nsError = error as NSError
        // 忽略取消错误
        if nsError.code == NSURLErrorCancelled {
            return
        }

        sendEvent(id: id, status: "error", progress: 0, error: error.localizedDescription)
        activeDownloads.removeValue(forKey: id)
        destPaths.removeValue(forKey: id)
    }
}

extension BackgroundDownloadManager: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // 后台下载完成，通知系统可以释放资源
        DispatchQueue.main.async {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.completeBackgroundDownload()
            }
        }
    }
}

// MARK: - Download Event Stream Handler

class DownloadEventStreamHandler: NSObject, FlutterStreamHandler {
    private weak var manager: BackgroundDownloadManager?

    init(manager: BackgroundDownloadManager) {
        self.manager = manager
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        manager?.setEventSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        manager?.setEventSink(nil)
        return nil
    }
}
