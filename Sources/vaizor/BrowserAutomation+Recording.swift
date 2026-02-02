import Foundation
import AVFoundation
import AppKit

extension BrowserAutomation {
    // Save a snapshot to disk
    func saveSnapshot(to url: URL) async throws {
        let image = try await takeSnapshot()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw AutomationError.unknown("Failed to encode snapshot")
        }
        try png.write(to: url)
    }

    // Simple time-lapse recording (periodic snapshots)
    func recordTimelapse(to url: URL, interval: TimeInterval = 0.5, duration: TimeInterval = 10) async throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let frameCount = Int(duration / interval)
        for i in 0..<frameCount {
            let frameURL = tmpDir.appendingPathComponent(String(format: "frame_%05d.png", i))
            try await saveSnapshot(to: frameURL)
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }

        // Encode with AVAssetWriter
        let assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280,
            AVVideoHeightKey: 720
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        assetWriter.add(input)
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)

        var frameTime = CMTime.zero
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(1.0/interval))

        for i in 0..<frameCount {
            let frameURL = tmpDir.appendingPathComponent(String(format: "frame_%05d.png", i))
            guard let img = NSImage(contentsOf: frameURL),
                  let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }

            while !input.isReadyForMoreMediaData {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }

            var pixelBuffer: CVPixelBuffer?
            let attrs = [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true
            ] as CFDictionary
            CVPixelBufferCreate(kCFAllocatorDefault, cg.width, cg.height, kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
            if let pb = pixelBuffer {
                CVPixelBufferLockBaseAddress(pb, [])
                let ctx = CGContext(
                    data: CVPixelBufferGetBaseAddress(pb),
                    width: cg.width,
                    height: cg.height,
                    bitsPerComponent: 8,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                )
                if let ctx { ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height)) }
                CVPixelBufferUnlockBaseAddress(pb, [])
                adaptor.append(pb, withPresentationTime: frameTime)
                frameTime = CMTimeAdd(frameTime, frameDuration)
            }
        }

        input.markAsFinished()
        assetWriter.finishWriting {
            try? FileManager.default.removeItem(at: tmpDir)
        }
    }
}
