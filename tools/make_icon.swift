// Renders the app icon (light, dark, tinted) with the bundled Newsreader font, and with
// `alternates` the alternate icons (Profil › Uygulama ikonu, and App Store icon tests).
// Usage: swift tools/make_icon.swift Fonts/Newsreader.ttf App/Assets.xcassets/AppIcon.appiconset
//        swift tools/make_icon.swift Fonts/Newsreader.ttf App/Assets.xcassets alternates
import AppKit
import ImageIO
import CoreText

let fontURL = URL(fileURLWithPath: CommandLine.arguments[1])
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
let outDir = URL(fileURLWithPath: CommandLine.arguments[2])

func render(name: String, background: NSColor?, ink: NSColor, dot: NSColor) {
    let size = 1024
    // No alpha channel: the App Store rejects 1024 px icons with one.
    let cg = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
    if let background {
        background.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
    }
    let font = NSFont(name: "Newsreader", size: 760) ?? NSFont.systemFont(ofSize: 760)
    let text = NSAttributedString(string: "k", attributes: [.font: font, .foregroundColor: ink])
    let bounds = text.boundingRect(with: NSSize(width: 2000, height: 2000), options: [.usesLineFragmentOrigin, .usesDeviceMetrics])
    let x = (CGFloat(size) - bounds.width) / 2 - bounds.minX - 75
    let y = (CGFloat(size) - bounds.height) / 2 - bounds.minY - 200
    text.draw(at: NSPoint(x: x, y: y))
    // The half-filled state dot: the "struggling" mark that makes a word come back.
    let d: CGFloat = 150
    let rect = NSRect(x: 655, y: 440, width: d, height: d)
    let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 14, dy: 14))
    ring.lineWidth = 28
    dot.setStroke()
    ring.stroke()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(rect: NSRect(x: rect.minX, y: rect.minY, width: d / 2, height: d)).addClip()
    dot.setFill()
    NSBezierPath(ovalIn: rect.insetBy(dx: 14, dy: 14)).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    let dest = CGImageDestinationCreateWithURL(outDir.appendingPathComponent(name) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, cg.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

if CommandLine.arguments.count > 3 && CommandLine.arguments[3] == "alternates" {
    render(name: "AppIcon-Blue.appiconset/AppIcon-Blue.png", background: hex(0x335AA6), ink: hex(0xF4F1EB), dot: hex(0xF0A94A))
    render(name: "AppIcon-Orange.appiconset/AppIcon-Orange.png", background: hex(0xE49839), ink: hex(0x1B1916), dot: hex(0xF4F1EB))
} else {
    render(name: "AppIcon.png", background: hex(0xF4F1EB), ink: hex(0x1B1916), dot: hex(0xE49839))
    render(name: "AppIcon-Dark.png", background: hex(0x121110), ink: hex(0xF2EEE7), dot: hex(0xEEAC53))
    render(name: "AppIcon-Tinted.png", background: hex(0x000000), ink: NSColor(white: 1, alpha: 1), dot: NSColor(white: 0.75, alpha: 1))
}
