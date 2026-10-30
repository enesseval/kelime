// Cuts an iPhone screen recording into an App Store app preview: the chosen segments joined,
// scaled to 886 × 1920 (6.1"/6.3" previews), 30 fps H.264 with a silent stereo AAC track, and
// the status bar's red recording pill hidden from `coverFrom` seconds on.
// Usage: swiftc -O -parse-as-library tools/make_preview.swift -o build/make_preview
//        build/make_preview in.mp4 out.mp4 "0-4.5,16.5-26,34-40,49-56" 4.5
//
// The composition is read at the recording's own size and scaled frame by frame with Core
// Image: an export session with a scaled render size fails on this machine (-12904).
import AVFoundation
import CoreImage

@main
struct MakePreview {
    static let size = CGSize(width: 886, height: 1920)
    static let background = CIColor(red: 0x12 / 255, green: 0x11 / 255, blue: 0x10 / 255)

    static func main() async throws {
        let args = CommandLine.arguments
        let input = URL(fileURLWithPath: args[1]), output = URL(fileURLWithPath: args[2])
        let segments: [(Double, Double)] = args[3].split(separator: ",").map {
            let p = $0.split(separator: "-").map { Double($0)! }
            return (p[0], p[1])
        }
        let coverFrom = Double(args[4]) ?? 0

        let asset = AVURLAsset(url: input)
        let source = try await asset.loadTracks(withMediaType: .video).first!
        let natural = try await source.load(.naturalSize)

        let comp = AVMutableComposition()
        let track = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        var cursor = CMTime.zero
        for (start, end) in segments {
            let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), end: CMTime(seconds: end, preferredTimescale: 600))
            try track.insertTimeRange(range, of: source, at: cursor)
            cursor = cursor + range.duration
        }

        let reader = try AVAssetReader(asset: comp)
        let video = AVMutableVideoComposition()
        video.renderSize = natural
        video.frameDuration = CMTime(value: 1, timescale: 30)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: cursor)
        instruction.layerInstructions = [AVMutableVideoCompositionLayerInstruction(assetTrack: track)]
        video.instructions = [instruction]
        let readerOutput = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        readerOutput.videoComposition = video
        reader.add(readerOutput)

        try? FileManager.default.removeItem(at: output)
        let videoOnly = output.deletingLastPathComponent().appendingPathComponent("preview-video.mp4")
        try? FileManager.default.removeItem(at: videoOnly)
        let writer = try AVAssetWriter(outputURL: videoOnly, fileType: .mp4)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 10_000_000, AVVideoExpectedSourceFrameRateKey: 30],
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        writer.add(videoInput)
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let context = CIContext()
        let scaleX = size.width / natural.width, scaleY = size.height / natural.height
        // The status bar's left side in output pixels (CI's origin is bottom left).
        let coverRect = CGRect(x: 0, y: size.height - 84 * scaleY, width: 200 * scaleX, height: 84 * scaleY)
        var frames = 0
        while let sample = readerOutput.copyNextSampleBuffer(), let pixels = CMSampleBufferGetImageBuffer(sample) {
            let time = CMSampleBufferGetPresentationTimeStamp(sample)
            var image = CIImage(cvPixelBuffer: pixels).transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            if time.seconds >= coverFrom {
                // Clone the empty strip just right of the pill over it: wallpaper on the lock
                // screen, page background in the app.
                let patch = image.cropped(to: coverRect.offsetBy(dx: coverRect.width, dy: 0))
                    .transformed(by: CGAffineTransform(translationX: -coverRect.width, y: 0))
                image = patch.composited(over: image)
            }
            while !videoInput.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var out: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &out)
            context.render(image, to: out!)
            adaptor.append(out!, withPresentationTime: time)
            frames += 1
        }
        videoInput.markAsFinished()
        await writer.finishWriting()
        if let error = writer.error { throw error }

        // App Store previews want an audio track: a silent one, joined to the video without
        // re-encoding. (Writing both into one AVAssetWriter stalled on this machine.)
        let silence = output.deletingLastPathComponent().appendingPathComponent("preview-silence.m4a")
        try? FileManager.default.removeItem(at: silence)
        let pcm = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let file = try AVAudioFile(forWriting: silence, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 256_000,
        ])
        let frameCount = AVAudioFrameCount(cursor.seconds * 44_100)
        let buffer = AVAudioPCMBuffer(pcmFormat: pcm, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        try file.write(from: buffer)
        file.close()

        let joined = AVMutableComposition()
        let videoAsset = AVURLAsset(url: videoOnly), audioAsset = AVURLAsset(url: silence)
        let vt = try await videoAsset.loadTracks(withMediaType: .video).first!
        let at = try await audioAsset.loadTracks(withMediaType: .audio).first!
        let length = try await videoAsset.load(.duration)
        try joined.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
            .insertTimeRange(CMTimeRange(start: .zero, duration: length), of: vt, at: .zero)
        let audioLength = min(length, try await audioAsset.load(.duration))
        try joined.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
            .insertTimeRange(CMTimeRange(start: .zero, duration: audioLength), of: at, at: .zero)
        try? FileManager.default.removeItem(at: output)
        let export = AVAssetExportSession(asset: joined, presetName: AVAssetExportPresetPassthrough)!
        try await export.export(to: output, as: .mp4)
        try? FileManager.default.removeItem(at: videoOnly)
        try? FileManager.default.removeItem(at: silence)
        print("wrote \(output.path): \(frames) frames, \(length.seconds) s")
    }
}
