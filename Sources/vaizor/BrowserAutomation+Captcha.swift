import Foundation
import Vision
import AppKit

extension BrowserAutomation {
    // Attempt to detect visible CAPTCHA images and extract text via Vision (very naive)
    func detectCaptchaText(timeout: TimeInterval = 8) async throws -> String? {
        let image = try await takeSnapshot()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let cg = rep.cgImage else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        let best = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
        return best.isEmpty ? nil : best
    }

    // Hook to execute site-specific CAPTCHA bypass (e.g., trigger challenge UI, wait for completion)
    func attemptCaptchaBypass(selector: String? = nil, timeout: TimeInterval = 20) async throws -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            // Example: look for known widgets
            let hasHCaptcha = (try? await eval("document.querySelector('[data-hcaptcha-response]') !== null")) as? Bool ?? false
            let hasReCaptcha = (try? await eval("document.querySelector('[data-sitekey]') !== null")) as? Bool ?? false
            if hasHCaptcha || hasReCaptcha { return true }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return false
    }
}
