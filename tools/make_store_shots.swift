// Composes App Store screenshots: a coloured page, a two-line caption, and the app screen
// below it with rounded corners. Fonts are the app's own (Hanken Grotesk, Newsreader).
// Usage: swift tools/make_store_shots.swift docs/store-shots/spec.json <out dir>
// spec.json: [{"image": "...png", "title": "...", "subtitle": "...", "theme": "blue|cream|ink|orange"}]
import AppKit
import CoreText
import ImageIO

for font in ["Fonts/HankenGrotesk.ttf", "Fonts/Newsreader.ttf"] {
    CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: font) as CFURL, .process, nil)
}

struct Shot: Decodable {
    var image: String
    var title: String
    var subtitle: String
    var theme: String
}

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

let themes: [String: (bg: NSColor, title: NSColor, sub: NSColor)] = [
    "blue": (hex(0x335AA6), hex(0xFBF9F5), hex(0xDCE5F7)),
    "cream": (hex(0xF4F1EB), hex(0x1B1916), hex(0x6B655C)),
    "ink": (hex(0x1B1916), hex(0xF4F1EB), hex(0xB9B1A5)),
    "orange": (hex(0xE49839), hex(0x1B1916), hex(0x4A3518)),
]

func font(_ size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFontDescriptor(fontAttributes: [.family: "Hanken Grotesk"])
        .addingAttributes([.traits: [NSFontDescriptor.TraitKey.weight: weight]])
    return NSFont(descriptor: base, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
}

let args = CommandLine.arguments
let specURL = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
let shots = try JSONDecoder().decode([Shot].self, from: Data(contentsOf: specURL))
let W = 1206, H = 2622

for (index, shot) in shots.enumerated() {
    let theme = themes[shot.theme] ?? themes["cream"]!
    let cg = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
    theme.bg.setFill()
    NSRect(x: 0, y: 0, width: W, height: H).fill()

    // Caption, centred, near the top.
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineSpacing = 4
    let title = NSAttributedString(string: shot.title, attributes: [
        .font: font(92, weight: .bold), .foregroundColor: theme.title, .paragraphStyle: para, .kern: -1.5,
    ])
    let sub = NSAttributedString(string: shot.subtitle, attributes: [
        .font: font(46, weight: .medium), .foregroundColor: theme.sub, .paragraphStyle: para,
    ])
    let textWidth = CGFloat(W) - 140
    let titleRect = title.boundingRect(with: NSSize(width: textWidth, height: 600), options: [.usesLineFragmentOrigin])
    let subRect = sub.boundingRect(with: NSSize(width: textWidth, height: 300), options: [.usesLineFragmentOrigin])
    var y = CGFloat(H) - 190 - titleRect.height
    title.draw(with: NSRect(x: 70, y: y, width: textWidth, height: titleRect.height), options: [.usesLineFragmentOrigin])
    y -= 26 + subRect.height
    sub.draw(with: NSRect(x: 70, y: y, width: textWidth, height: subRect.height), options: [.usesLineFragmentOrigin])

    // The app screen: 84% wide, rounded, with a soft shadow; it runs off the bottom edge.
    let image = NSImage(contentsOfFile: shot.image)!
    let screenWidth = CGFloat(W) * 0.84
    let screenHeight = screenWidth * image.size.height / image.size.width
    let top = y - 80
    let rect = NSRect(x: (CGFloat(W) - screenWidth) / 2, y: top - screenHeight, width: screenWidth, height: screenHeight)
    let radius: CGFloat = 64
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 60
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    theme.bg.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
    // A thin frame so a cream screen still separates from a cream page.
    NSColor.black.withAlphaComponent(0.08).setStroke()
    let frame = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: radius, yRadius: radius)
    frame.lineWidth = 3
    frame.stroke()

    NSGraphicsContext.restoreGraphicsState()
    let name = String(format: "%02d.png", index + 1)
    let dest = CGImageDestinationCreateWithURL(outDir.appendingPathComponent(name) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, cg.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(name)")
}
