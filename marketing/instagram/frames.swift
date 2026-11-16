// Kontrol için MP4'ten kare çıkarır: swift frames.swift <video> <outdir> <t1> <t2> ...
import AVFoundation
import AppKit
let a = CommandLine.arguments
let asset = AVAsset(url: URL(fileURLWithPath: a[1]))
let gen = AVAssetImageGenerator(asset: asset)
gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
try? FileManager.default.createDirectory(atPath: a[2], withIntermediateDirectories: true)
for s in a[3...] {
    let t = Double(s)!
    let img = try gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil)
    let rep = NSBitmapImageRep(cgImage: img)
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(a[2])/f\(s).png"))
}
