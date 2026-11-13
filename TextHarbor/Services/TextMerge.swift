import Foundation

struct TextAccumulator {
    private(set) var lines: [String] = []
    static func clean(_ input: String) -> String {
        input.replacingOccurrences(of: "\r", with: "", options: .regularExpression)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
    private static func normalized(_ line: String) -> String {
        line.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "zh_TW"))
            .filter { !$0.isWhitespace && !$0.isNewline && !$0.isPunctuation }
    }
    mutating func appendFrame(_ frameLines: [String]) {
        let fresh = frameLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !fresh.isEmpty else { return }
        guard !lines.isEmpty else { lines = fresh; return }
        let maxOverlap = min(lines.count, fresh.count, 80)
        var overlap = 0
        if maxOverlap > 0 {
            for length in stride(from: maxOverlap, through: 1, by: -1) {
                let oldPart = lines.suffix(length).map(Self.normalized)
                let newPart = fresh.prefix(length).map(Self.normalized)
                if oldPart.elementsEqual(newPart) {
                    overlap = length
                    break
                }
            }
        }
        if overlap > 0 {
            lines.append(contentsOf: fresh.dropFirst(overlap))
            return
        }
        let recent = Array(lines.suffix(50)).map(Self.normalized)
        let candidate = fresh.map(Self.normalized)
        var bestOld = -1
        var bestNew = -1
        for index in candidate.indices {
            if let old = recent.lastIndex(of: candidate[index]), old >= bestOld {
                bestOld = old
                bestNew = index
            }
        }
        if bestNew >= 0 && bestNew + 1 < fresh.count {
            lines.append(contentsOf: fresh.dropFirst(bestNew + 1))
        } else if bestNew < 0 {
            lines.append(contentsOf: fresh)
        }
    }
    var text: String { lines.joined(separator: "\n") }
}
