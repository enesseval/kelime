// Contact sheet: swift sheet.swift out.png cols thumbWidth img1 img2 ...
import AppKit
let a = CommandLine.arguments
let out = a[1], cols = Int(a[2])!, tw = CGFloat(Int(a[3])!)
let imgs = a[4...].compactMap { NSImage(contentsOfFile: $0) }
let th = imgs.map { tw * $0.size.height / $0.size.width }.max()!
let rows = (imgs.count + cols - 1) / cols, gap: CGFloat = 12
let W = CGFloat(cols) * (tw + gap) + gap, H = CGFloat(rows) * (th + gap) + gap
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(white: 0.5, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
for (i, im) in imgs.enumerated() {
    let r = i / cols, c = i % cols
    let h = tw * im.size.height / im.size.width
    im.draw(in: NSRect(x: gap + CGFloat(c) * (tw + gap), y: H - gap - CGFloat(r) * (th + gap) - h, width: tw, height: h))
}
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
