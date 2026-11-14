import Foundation

/// Merge overlapping video OCR frames without discarding non-overlapping content.
/// The prior implementation searched for ANY familiar line in the last 50 lines
/// and discarded everything before that line. Scrolling pages often repeat
/// headers and UI elements, so that algorithm could silently lose paragraphs.
struct TextAccumulator {
    private(set) var lines: [String] = []
    private var precedingFrame: [String] = []
    private(set) var observedLineCount = 0

    static func clean(_ input: String) -> String {
        input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func normalized(_ line: String) -> String {
        line.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "zh_TW"))
            .filter { !$0.isWhitespace && !$0.isNewline }
    }

    mutating func appendFrame(_ frameLines: [String]) {
        let fresh = frameLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !fresh.isEmpty else { return }
        observedLineCount += fresh.count

        if precedingFrame.isEmpty {
            lines.append(contentsOf: fresh)
            precedingFrame = fresh
            return
        }

        let old = precedingFrame.map(Self.normalized)
        let current = fresh.map(Self.normalized)

        // Prefer an exact suffix/prefix match between ADJACENT frames only.
        // This handles scrolling paragraphs without confusing repeated headers
        // with text seen much earlier in the video.
        let maximum = min(old.count, current.count)
        var overlap = 0
        if maximum > 0 {
            for length in stride(from: maximum, through: 1, by: -1) {
                if old.suffix(length).elementsEqual(current.prefix(length)) {
                    overlap = length
                    break
                }
            }
        }

        if overlap == current.count {
            // New frame is entirely inside the previous frame.
        } else if overlap > 0 {
            lines.append(contentsOf: fresh.dropFirst(overlap))
        } else if old == current {
            // Exact duplicate frame.
        } else {
            // Detect an overlapping subsequence without deleting novel text.
            // Example: old A B C D / new B C D E (overlap B C D).
            var bestStart = 0
            var bestCount = 0
            for start in current.indices {
                let remaining = current.count - start
                let bound = min(old.count, remaining)
                if bound == 0 { continue }
                for length in stride(from: bound, through: 1, by: -1) {
                    let matches = old.suffix(length).elementsEqual(current[start..<(start + length)])
                    if matches && length > bestCount {
                        bestStart = start
                        bestCount = length
                        break
                    }
                }
            }
            if bestCount >= 2 {
                // Preserve text before overlap if it is not already in the
                // output; otherwise only append the genuinely new suffix.
                let prefix = Array(fresh.prefix(bestStart))
                if !prefix.isEmpty && !lines.suffix(prefix.count).elementsEqual(prefix) {
                    lines.append(contentsOf: prefix)
                }
                lines.append(contentsOf: fresh.dropFirst(bestStart + bestCount))
            } else {
                // Single matching UI labels are not sufficient evidence to
                // throw text away. Preserve all lines, including uncertain ones.
                lines.append(contentsOf: fresh)
            }
        }

        precedingFrame = fresh
    }

    var text: String { lines.joined(separator: "\n") }
}
