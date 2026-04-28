import Foundation
import Speech
import AVFoundation

final class AppleSpeechHelper {
  static let shared = AppleSpeechHelper()
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

      guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        ?? SFSpeechRecognizer() else {
        completion(.failure(NSError(domain: "AppleSpeech", code: -3, userInfo: [
          NSLocalizedDescriptionKey: "无法创建语音识别器"
        ])))
        return
      }

      let url = URL(fileURLWithPath: filePath)
      let request = SFSpeechURLRecognitionRequest(url: url)
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
