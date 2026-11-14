import Foundation
import Vision
import UIKit
import AVFoundation
import ImageIO

struct VideoOCRStats {
    let requestedFrames: Int
    let analyzedFrames: Int
    let failedFrames: Int
    let detectedLines: Int
    let retainedLines: Int
    let rotatedFrames: Int
    let rawText: String
}

struct OCRService {
    private static func observations(_ image: CGImage,
                                     subtitleOnly: Bool = false,
                                     orientation: CGImagePropertyOrientation = .up) throws -> [VNRecognizedTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hant", "en-US"]
        request.minimumTextHeight = 0.005
        if subtitleOnly {
            request.regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 0.35)
        }
        try VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:]).perform([request])
        return (request.results ?? []).sorted {
            if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.017 {
                return $0.boundingBox.midY > $1.boundingBox.midY
            }
            return $0.boundingBox.minX < $1.boundingBox.minX
        }
    }

    private static func extractedLines(_ results: [VNRecognizedTextObservation]) -> [String] {
        results.compactMap { $0.topCandidates(1).first?.string }
    }

    static func recognize(_ image: CGImage, subtitleOnly: Bool = false) throws -> [String] {
        try extractedLines(observations(image, subtitleOnly: subtitleOnly))
    }

    // The screen recording can contain an actual 90-degree UI rotation
    // while its encoded canvas remains portrait. Video metadata alone does
    // not describe the orientation of the text inside each frame.
    // Periodically compare OCR quality for up/left/right orientations.
    private static func chooseOrientation(_ image: CGImage, subtitleOnly: Bool)
      throws -> (orientation: CGImagePropertyOrientation, lines: [String]) {
        var best: (orientation: CGImagePropertyOrientation, lines: [String], score: Double)?
        for orientation: CGImagePropertyOrientation in [.up, .left, .right] {
            let results = try observations(image, subtitleOnly: subtitleOnly, orientation: orientation)
            var score = 0.0
            for observation in results {
                if let candidate = observation.topCandidates(1).first {
                    let meaningful = candidate.string.filter { !$0.isWhitespace && !$0.isNewline }.count
                    if meaningful >= 2 {
                        score += Double(min(meaningful, 60)) * Double(candidate.confidence)
                    }
                }
            }
            let lines = extractedLines(results)
            if best == nil || score > best!.score {
                best = (orientation, lines, score)
            }
        }
        guard let best else { return (.up, []) }
        return (best.orientation, best.lines)
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

                let interval = max(0.30, duration / 1500)
                let count = max(1, Int(ceil(duration / interval)))
                var output = TextAccumulator()
                var rawParts: [String] = []
                var analyzed = 0
                var failed = 0
                var rotated = 0
                var orientation: CGImagePropertyOrientation = .up

                for i in 0..<count {
                    let second = min(max(0, duration - 0.01), Double(i) * interval + interval / 2)
                    let time = CMTime(seconds: second, preferredTimescale: 600)
                    do {
                        let frame = try generator.copyCGImage(at: time, actualTime: nil)
                        let lines: [String]
                        if i == 0 || i % 20 == 0 {
                            let choice = try chooseOrientation(frame, subtitleOnly: subtitleOnly)
                            orientation = choice.orientation
                            lines = choice.lines
                        } else {
                            lines = try extractedLines(observations(frame,
                                                                    subtitleOnly: subtitleOnly,
                                                                    orientation: orientation))
                        }
                        analyzed += 1
                        if orientation != .up { rotated += 1 }
                        output.appendFrame(lines)
                        if !lines.isEmpty {
                            let seconds = Int(second)
                            let stamp = String(format: "[%02d:%02d]", seconds / 60, seconds % 60)
                            rawParts.append(stamp + "\n" + lines.joined(separator: "\n"))
                        }
                    } catch {
                        failed += 1
                    }
                    DispatchQueue.main.async { progress(Double(i + 1) / Double(count)) }
                }

                let info = VideoOCRStats(requestedFrames: count,
                                         analyzedFrames: analyzed,
                                         failedFrames: failed,
                                         detectedLines: output.observedLineCount,
                                         retainedLines: output.lines.count,
                                         rotatedFrames: rotated,
                                         rawText: rawParts.joined(separator: "\n\n"))
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
