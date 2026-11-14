import Foundation

/// Conservative OCR merge. It never discards a new, different line just
/// because a fixed header or one neighbouring line was seen before.
enum TextMergePolicy {
    /// For scrolling catalogues: each exactly matching line appears once.
    /// Never fuzzy-match product codes or names: near matches may be different items.
    case scrollingList
    /// For general videos: a line can reappear after the specified pause.
    case recent(seconds: Double)
    /// Preserve every recognised line, useful for multiple different photographs.
    case preserveAll
}

struct TextAccumulator {
    private(set) var lines: [String] = []
    private(set) var observedLineCount = 0
    private(set) var skippedDuplicateLines = 0
    private var frameNumber = 0
    private let policy: TextMergePolicy
    private var lastObserved: [String: Double] = [:]
    private var seenGlobally = Set<String>()

    init(policy: TextMergePolicy = .recent(seconds: 20)) {
        self.policy = policy
    }

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

    mutating func appendFrame(_ frameLines: [String], timestamp: Double? = nil) {
        frameNumber += 1
        let time = timestamp ?? Double(frameNumber)
        for source in frameLines {
            let line = source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            observedLineCount += 1
            let key = Self.normalized(line)
            guard !key.isEmpty else { continue }
            switch policy {
            case .scrollingList:
                if !seenGlobally.insert(key).inserted {
                    skippedDuplicateLines += 1
                    continue
                }
            case .recent(let seconds):
                if let last = lastObserved[key], time >= last && time - last < seconds {
                    lastObserved[key] = time
                    skippedDuplicateLines += 1
                    continue
                }
                lastObserved[key] = time
            case .preserveAll:
                break
            }
            lines.append(line)
        }
    }

    var text: String { lines.joined(separator: "\n") }
}
