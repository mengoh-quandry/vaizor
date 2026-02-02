import Foundation
import AppKit
import CoreGraphics

enum SystemScreenshot {
    static func captureMainDisplay() throws -> NSImage {
        guard let cgImage = CGDisplayCreateImage(CGMainDisplayID()) else {
            throw NSError(domain: "SystemScreenshot", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to capture display"])
        }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        return image
    }

    static func saveMainDisplay(to url: URL) throws {
        let img = try captureMainDisplay()
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SystemScreenshot", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }
        try png.write(to: url)
    }
}
