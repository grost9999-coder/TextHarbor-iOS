import AppKit
import CoreGraphics
import ImageIO
import Foundation

// Generate a fully opaque 1024x1024 RGB PNG for Apple asset catalog.
let dimension = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let bitmap = CGContext(
    data: nil,
    width: dimension,
    height: dimension,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Could not create opaque RGB graphics context")
}
let bounds = CGRect(x: 0, y: 0, width: dimension, height: dimension)
bitmap.setFillColor(CGColor(red: 0.09, green: 0.24, blue: 0.45, alpha: 1))
bitmap.fill(bounds)
let whiteDocument = CGPath(
    roundedRect: CGRect(x: 210, y: 180, width: 604, height: 666),
    cornerWidth: 82,
    cornerHeight: 82,
    transform: nil
)
bitmap.addPath(whiteDocument)
bitmap.setFillColor(CGColor(gray: 1, alpha: 1))
bitmap.fillPath()

let graphics = NSGraphicsContext(cgContext: bitmap, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let text = "字" as NSString
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 405, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.09, green: 0.24, blue: 0.45, alpha: 1)
]
let textSize = text.size(withAttributes: attrs)
text.draw(at: NSPoint(x: (CGFloat(dimension) - textSize.width) / 2,
                      y: (CGFloat(dimension) - textSize.height) / 2),
          withAttributes: attrs)
NSGraphicsContext.restoreGraphicsState()

guard let cgImage = bitmap.makeImage() else {
    fatalError("Could not create opaque RGB image")
}
let output = "TextHarbor/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let outputURL = URL(fileURLWithPath: output)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL, "public.png" as CFString, 1, nil
) else {
    fatalError("Could not create PNG destination")
}
CGImageDestinationAddImage(destination, cgImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write PNG icon")
}
print("Generated opaque RGB app icon: \(output)")
