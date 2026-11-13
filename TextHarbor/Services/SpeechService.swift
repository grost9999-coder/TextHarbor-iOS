import Foundation
import Speech
import AVFoundation

final class SpeechService {
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    func transcribe(videoURL: URL, locale: String = "zh-TW",
                    completion: @escaping (Result<String, Error>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                DispatchQueue.main.async { completion(.failure(SpeechError.permissionDenied)) }
                return
            }
            self?.exportAudio(videoURL: videoURL, locale: locale, completion: completion)
        }
    }
    private func exportAudio(videoURL: URL, locale: String,
                             completion: @escaping (Result<String, Error>) -> Void) {
        let asset = AVURLAsset(url: videoURL)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            DispatchQueue.main.async { completion(.failure(ExtractionError.noSpeech)) }
            return
        }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        session.outputURL = output
        session.outputFileType = .m4a
        session.exportAsynchronously { [weak self] in
            guard session.status == .completed else {
                DispatchQueue.main.async { completion(.failure(session.error ?? ExtractionError.noSpeech)) }
                return
            }
            self?.recognizeAudio(url: output, locale: locale) { result in
                try? FileManager.default.removeItem(at: output)
                completion(result)
            }
        }
    }
    private func recognizeAudio(url: URL, locale: String,
                                completion: @escaping (Result<String, Error>) -> Void) {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        self.recognizer = recognizer
        guard let recognizer, recognizer.isAvailable else {
            DispatchQueue.main.async { completion(.failure(SpeechError.unavailable)) }
            return
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        task?.cancel()
        task = recognizer.recognitionTask(with: request) { result, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
            } else if let result, result.isFinal {
                DispatchQueue.main.async { completion(.success(result.bestTranscription.formattedString)) }
            }
        }
    }
}

enum SpeechError: LocalizedError {
    case permissionDenied, unavailable
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "請在 iPhone 設定中允許語音辨識權限。"
        case .unavailable: return "目前無法使用語音辨識，請檢查網路、系統語言或稍後再試。"
        }
    }
}
