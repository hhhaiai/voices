import Flutter
import UIKit
import Speech
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var eventSink: FlutterEventSink?
    private let appleSpeechBridge = AppleSpeechBridge.shared

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: "com.sanbo.voices/apple_speech",
                binaryMessenger: controller.binaryMessenger
            )

            // 设置 EventChannel 用于推送 partial results
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
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
