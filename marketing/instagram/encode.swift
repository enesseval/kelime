// Frames (sorted .jpg) → H.264 MP4 for Instagram: swift encode.swift <frames-dir> <out.mp4> <fps> [audio.wav → AAC track]
import AVFoundation
import CoreImage
import ImageIO

let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1]), out = URL(fileURLWithPath: args[2]), fps = Int32(args[3]) ?? 30
let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
func load(_ url: URL) -> CGImage { CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil)! }
let first = load(files[0])
let w = first.width, h = first.height
try? FileManager.default.removeItem(at: out)
let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 10_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                      AVVideoMaxKeyFrameIntervalKey: Int(fps)],
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
])
writer.add(input)
var aIn: AVAssetWriterInput?, aOut: AVAssetReaderTrackOutput?, aReader: AVAssetReader?
if args.count > 4 {
    let asset = AVURLAsset(url: URL(fileURLWithPath: args[4]))
    let track = asset.tracks(withMediaType: .audio)[0]
    aReader = try AVAssetReader(asset: asset)
    aOut = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
    aReader!.add(aOut!)
    aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 128_000])
    writer.add(aIn!)
    aReader!.startReading()
}
writer.startWriting()
writer.startSession(atSourceTime: .zero)
let ctx = CIContext()
var audioDone = aIn == nil
func pumpAudio(upTo sec: Double) {
    guard let aIn = aIn, let aOut = aOut, !audioDone else { return }
    while aIn.isReadyForMoreMediaData {
        guard let sb = aOut.copyNextSampleBuffer() else { aIn.markAsFinished(); audioDone = true; return }
        aIn.append(sb)
        if CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sb)) > sec { return }
    }
}
for (i, url) in files.enumerated() {
    while !input.isReadyForMoreMediaData { pumpAudio(upTo: Double(i) / Double(fps) + 1.0); usleep(2000) }
    pumpAudio(upTo: Double(i) / Double(fps) + 1.0)
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
    ctx.render(CIImage(cgImage: i == 0 ? first : load(url)), to: pb!)
    adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
}
input.markAsFinished()
while !audioDone { pumpAudio(upTo: 1e9); usleep(2000) }
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status != .completed { print(writer.error ?? "failed"); exit(1) }
