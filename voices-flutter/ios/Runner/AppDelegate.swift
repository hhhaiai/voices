import Flutter
import UIKit
import Speech
import Foundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.sanbo.voices/apple_speech",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "transcribeFile" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let args = call.arguments as? [String: Any],
          let filePath = args["filePath"] as? String
        else {
          result(FlutterError(code: "bad_args", message: "缺少 filePath", details: nil))
          return
        }

        AppleSpeechBridge.shared.transcribeFile(filePath: filePath) { transcribeResult in
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
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

final class AppleSpeechBridge {
  static let shared = AppleSpeechBridge()
  private init() {}

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
}
