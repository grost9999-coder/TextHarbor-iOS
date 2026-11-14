import Foundation

func verify(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError("FAIL: " + message) }
}

var list = TextAccumulator(policy: .scrollingList)
list.appendFrame(["商品清單", "分類", "代碼 A100", "代碼 A101"], timestamp: 0)
list.appendFrame(["商品清單", "分類", "代碼 A101", "代碼 A102"], timestamp: 0.25)
list.appendFrame(["商品清單", "分類", "代碼 A102", "代碼 A103"], timestamp: 0.5)
verify(list.lines == ["商品清單", "分類", "代碼 A100", "代碼 A101", "代碼 A102", "代碼 A103"],
       "Stable navigation must not remove new entries")
verify(list.skippedDuplicateLines == 6, "Duplicate diagnostics must be accurate")

var codes = TextAccumulator(policy: .scrollingList)
codes.appendFrame(["南山商品 10Z1", "南山商品 10ZI", "南山商品 10Z2"])
verify(codes.lines.count == 3, "Different insurance product codes must not be fuzzy merged")

var conversation = TextAccumulator(policy: .recent(seconds: 10))
conversation.appendFrame(["歡迎大家", "第一段"], timestamp: 0)
conversation.appendFrame(["歡迎大家", "第二段"], timestamp: 2)
conversation.appendFrame(["歡迎大家", "第三段"], timestamp: 20)
verify(conversation.lines == ["歡迎大家", "第一段", "第二段", "歡迎大家", "第三段"],
       "Ordinary videos must keep intentional repetition after a long pause")

var photos = TextAccumulator(policy: .preserveAll)
photos.appendFrame(["A", "A"])
photos.appendFrame(["A"])
verify(photos.lines.count == 3, "Photo mode must preserve repeated lines")

var normalization = TextAccumulator(policy: .scrollingList)
normalization.appendFrame(["ＡＢＣ　１２３"])
normalization.appendFrame(["ABC 123"])
verify(normalization.lines.count == 1, "Full-width / whitespace normalization")

// Stress test: 1,000 unique scrolling items under 600 overlapping frames.
var stress = TextAccumulator(policy: .scrollingList)
for index in 0..<600 {
    stress.appendFrame(["商品清單", "所有商品", "產品 NO-\(index)", "產品 NO-\(index + 1)"],
                       timestamp: Double(index) * 0.25)
}
verify(stress.lines.count == 603, "All 601 distinct scrolling products plus two navigation labels must remain")
verify(stress.lines.last == "產品 NO-600", "Last scrolled product should not disappear")
print("PASS: 6 OCR merge scenarios including 600 scrolling frames")
