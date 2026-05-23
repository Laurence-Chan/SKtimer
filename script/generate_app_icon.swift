import AppKit
import Foundation

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "SKtimer/Assets.xcassets/AppIcon.appiconset")

let icons: [(filename: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for icon in icons {
    let data = makeIcon(size: icon.pixels)
    try data.write(to: outputDirectory.appendingPathComponent(icon.filename))
}

func makeIcon(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: .alphaFirst,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let radius = CGFloat(size) * 0.22
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.06, dy: CGFloat(size) * 0.06), xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.02, green: 0.46, blue: 0.58, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.67, blue: 0.54, alpha: 1),
        NSColor(calibratedRed: 0.93, green: 0.72, blue: 0.30, alpha: 1)
    ])!
    gradient.draw(in: background, angle: 135)

    let faceRect = rect.insetBy(dx: CGFloat(size) * 0.21, dy: CGFloat(size) * 0.21)
    let face = NSBezierPath(ovalIn: faceRect)
    NSColor.white.withAlphaComponent(0.94).setFill()
    face.fill()
    NSColor.black.withAlphaComponent(0.12).setStroke()
    face.lineWidth = max(1, CGFloat(size) * 0.018)
    face.stroke()

    let center = NSPoint(x: rect.midX, y: rect.midY)
    let minuteLength = CGFloat(size) * 0.2
    let hourLength = CGFloat(size) * 0.14

    let minuteHand = NSBezierPath()
    minuteHand.move(to: center)
    minuteHand.line(to: NSPoint(x: center.x + minuteLength * 0.72, y: center.y + minuteLength * 0.72))
    NSColor(calibratedRed: 0.04, green: 0.31, blue: 0.38, alpha: 1).setStroke()
    minuteHand.lineWidth = max(2, CGFloat(size) * 0.035)
    minuteHand.lineCapStyle = .round
    minuteHand.stroke()

    let hourHand = NSBezierPath()
    hourHand.move(to: center)
    hourHand.line(to: NSPoint(x: center.x, y: center.y + hourLength))
    hourHand.lineWidth = max(2, CGFloat(size) * 0.045)
    hourHand.lineCapStyle = .round
    hourHand.stroke()

    let centerDot = NSBezierPath(ovalIn: NSRect(
        x: center.x - CGFloat(size) * 0.035,
        y: center.y - CGFloat(size) * 0.035,
        width: CGFloat(size) * 0.07,
        height: CGFloat(size) * 0.07
    ))
    NSColor(calibratedRed: 0.93, green: 0.45, blue: 0.26, alpha: 1).setFill()
    centerDot.fill()

    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}
