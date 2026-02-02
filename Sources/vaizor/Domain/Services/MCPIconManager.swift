import SwiftUI
import AppKit

struct MCPIconManager {
    static func icon() -> Image {
        // Try Bundle resource loading first (proper way for bundled resources)
        if let bundlePath = Bundle.main.path(forResource: "mcp", ofType: "png", inDirectory: "Resources/Icons") ?? 
                            Bundle.main.path(forResource: "mcp", ofType: "png") {
            if let nsImage = NSImage(contentsOfFile: bundlePath) {
                if nsImage.isValid {
                    Task { @MainActor in
                        AppLogger.shared.log("MCPIconManager: Loaded icon from bundle: \(bundlePath) (size: \(nsImage.size))", level: .info)
                    }
                    return Image(nsImage: nsImage)
                        .resizable()
                }
            }
        }
        
        // Try direct file paths (for development)
        let fileManager = FileManager.default
        let possiblePaths = [
            Bundle.main.bundlePath + "/../../Resources/Icons/mcp.png",
            Bundle.main.bundlePath + "/Resources/Icons/mcp.png",
            Bundle.main.resourcePath.map { $0 + "/Resources/Icons/mcp.png" },
            Bundle.main.resourcePath.map { $0 + "/../../Resources/Icons/mcp.png" },
            "/Users/marcus/Downloads/vaizor/Resources/Icons/mcp.png"
        ].compactMap { $0 }
        
        for mcpPath in possiblePaths {
            guard fileManager.fileExists(atPath: mcpPath) else { continue }
            
            // Try loading as NSImage
            if let nsImage = NSImage(contentsOfFile: mcpPath) {
                if nsImage.isValid && nsImage.size.width > 0 && nsImage.size.height > 0 {
                    Task { @MainActor in
                        AppLogger.shared.log("MCPIconManager: Successfully loaded icon from: \(mcpPath)", level: .info)
                    }
                    return Image(nsImage: nsImage)
                        .resizable()
                }
            }
        }
        
        // Fallback - log what we tried
        Task { @MainActor in
            AppLogger.shared.log("MCPIconManager: Failed to load PNG. Bundle resourcePath: \(Bundle.main.resourcePath ?? "nil"), bundlePath: \(Bundle.main.bundlePath)", level: .warning)
        }
        return Image(systemName: "server.rack")
    }
}
