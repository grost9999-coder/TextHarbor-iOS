import Foundation
import UIKit
import CoreText

struct ExportService {
    static func makeFile(document: ExtractedDocument, pdf: Bool) throws -> URL {
        let filename = String(document.title.prefix(50))
            .replacingOccurrences(of: "[\\/:*?\"<>|]", with: "-", options: .regularExpression)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename.isEmpty ? "擷取文字" : filename)-\(UUID().uuidString.prefix(6))")
            .appendingPathExtension(pdf ? "pdf" : "txt")
        if pdf {
            try renderPDF(title: document.title, text: document.text).write(to: url)
        } else {
            try document.text.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }
    private static func renderPDF(title: String, text: String) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 45
        let available = CGRect(x: margin, y: margin, width: page.width - 2 * margin,
                               height: page.height - 2 * margin)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        let body = NSMutableAttributedString(string: title + "\n\n" + text,
            attributes: [.font: UIFont.systemFont(ofSize: 12),
                         .foregroundColor: UIColor.black,
                         .paragraphStyle: style])
        body.addAttributes([.font: UIFont.boldSystemFont(ofSize: 20)],
                           range: NSRange(location: 0, length: (title as NSString).length))
        let framesetter = CTFramesetterCreateWithAttributedString(body)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            var location = 0
            while location < body.length {
                context.beginPage()
                let cg = context.cgContext
                cg.saveGState()
                cg.translateBy(x: 0, y: page.height)
                cg.scaleBy(x: 1, y: -1)
                let path = CGPath(rect: CGRect(x: available.minX,
                                              y: page.height - available.maxY,
                                              width: available.width, height: available.height),
                                  transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
                CTFrameDraw(frame, cg)
                let visible = CTFrameGetVisibleStringRange(frame)
                cg.restoreGState()
                guard visible.length > 0 else { break }
                location += visible.length
            }
        }
    }
}
