import Foundation
import Vision
import UIKit
import AVFoundation

struct VideoOCRStats {
    let requestedFrames: Int
    let analyzedFrames: Int
    let failedFrames: Int
    let detectedLines: Int
    let retainedLines: Int
}

struct OCRService {
    static func recognize(_ image: CGImage, subtitleOnly: Bool = false) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.005
        request.recognitionLanguages = ["zh-Hant", "en-US"]
        if subtitleOnly {
            request.regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 0.35)
        }
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? [])
            .sorted {
                if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.017 {
                    return $0.boundingBox.midY > $1.boundingBox.midY
                }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
            .compactMap { $0.topCandidates(1).first?.string }
    }

    static func recognizeImages(_ images: [UIImage], progress: @escaping (Double) -> Void,
                                completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var output = TextAccumulator()
                for (index, image) in images.enumerated() {
                    guard let cgImage = image.cgImage else { continue }
                    output.appendFrame(try recognize(cgImage))
                    DispatchQueue.main.async { progress(Double(index + 1) / Double(max(1, images.count))) }
                }
                DispatchQueue.main.async { completion(.success(output.text)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    static func recognizeVideo(_ url: URL, subtitleOnly: Bool,
                               progress: @escaping (Double) -> Void,
                               stats: ((VideoOCRStats) -> Void)? = nil,
                               completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let asset = AVURLAsset(url: url)
                let duration = CMTimeGetSeconds(asset.duration)
                guard duration.isFinite, duration > 0 else { throw ExtractionError.invalidVideo }
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
                generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

                // More frequent sampling for short-lived text and faster scrolling.
                // Sampling cannot recover frames blurred by motion, so record how
                // many frames could actually be read and show diagnostics to user.
                let interval = max(0.30, duration / 1500)
                let count = max(1, Int(ceil(duration / interval)))
                var output = TextAccumulator()
                var analyzed = 0
                var failed = 0
                for i in 0..<count {
                    let second = min(max(0, duration - 0.01), Double(i) * interval + interval / 2)
                    let time = CMTime(seconds: second, preferredTimescale: 600)
                    do {
                        let frame = try generator.copyCGImage(at: time, actualTime: nil)
                        let recognized = try recognize(frame, subtitleOnly: subtitleOnly)
                        analyzed += 1
                        output.appendFrame(recognized)
                    } catch {
                        failed += 1
                    }
                    DispatchQueue.main.async { progress(Double(i + 1) / Double(count)) }
                }
                let info = VideoOCRStats(requestedFrames: count,
                                         analyzedFrames: analyzed,
                                         failedFrames: failed,
                                         detectedLines: output.observedLineCount,
                                         retainedLines: output.lines.count)
                DispatchQueue.main.async {
                    stats?(info)
                    completion(.success(output.text))
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}

enum ExtractionError: LocalizedError {
    case invalidVideo, noSpeech, noText
    var errorDescription: String? {
        switch self {
        case .invalidVideo: return "影片無法讀取或長度不正確。"
        case .noSpeech: return "影片中沒有可辨識的語音，或無法匯出音軌。"
        case .noText: return "沒有辨識到文字，請檢查畫面清晰度或更改擷取模式。"
        }
    }
}
