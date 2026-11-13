import AppKit
import Foundation

// Temporary, opaque 1024x1024 App Store icon for 字捕手.
// Replace with approved brand artwork before public App Store release.
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSColor(calibratedRed: 0.09, green: 0.24, blue: 0.45, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()
let document = NSBezierPath(roundedRect: NSRect(x: 212, y: 184, width: 600, height: 656), xRadius: 84, yRadius: 84)
NSColor.white.setFill()
document.fill()
let symbol = "字" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 410, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.09, green: 0.24, blue: 0.45, alpha: 1)
]
let rect = symbol.boundingRect(with: NSSize(width: 600, height: 520), options: [], attributes: attributes)
symbol.draw(at: NSPoint(x: (CGFloat(size) - rect.width) / 2, y: 260), withAttributes: attributes)
image.unlockFocus()
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 3,
    hasAlpha: false,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("Unable to prepare opaque RGB icon")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon")
}
let output = "TextHarbor/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
try FileManager.default.createDirectory(atPath: (output as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
try png.write(to: URL(fileURLWithPath: output))
print("Generated \(output), \(png.count) bytes")
