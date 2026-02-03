import SwiftUI
import AppKit

struct ProviderIconManager {
    static func icon(for provider: LLMProvider) -> Image {
        let (resourceName, fileExtension): (String, String)
        
        switch provider {
        case .ollama:
            resourceName = "ollama"
            fileExtension = "jpeg"
        case .anthropic:
            resourceName = "anthropic"
            fileExtension = "png"
        case .openai:
            resourceName = "openai"
            fileExtension = "png"
        case .gemini:
            resourceName = "gemini"
            fileExtension = "png"
        case .custom:
            resourceName = "perplexity" // Use perplexity icon as fallback for custom
            fileExtension = "png"
        }
        
        // Try multiple paths to load icon from resources
        let possiblePaths = [
            Bundle.main.path(forResource: resourceName, ofType: fileExtension),
            Bundle.main.path(forResource: resourceName, ofType: fileExtension, inDirectory: "Resources/Icons"),
            Bundle.main.resourcePath?.appending("/../../Resources/Icons/\(resourceName).\(fileExtension)"),
            Bundle.main.resourcePath?.appending("/Resources/Icons/\(resourceName).\(fileExtension)")
        ]
        
        for path in possiblePaths {
            if let path = path, FileManager.default.fileExists(atPath: path),
               let image = NSImage(contentsOfFile: path), image.isValid {
                return Image(nsImage: image)
                    .resizable()
            }
        }
        
        // Fallback to system icons
        switch provider {
        case .ollama:
            return Image(systemName: "sparkles")
        case .anthropic:
            return Image(systemName: "sparkles")
        case .openai:
            return Image(systemName: "brain")
        case .gemini:
            return Image(systemName: "globe")
        case .custom:
            return Image(systemName: "server.rack")
        }
    }
    
    static func iconName(for provider: LLMProvider) -> String {
        switch provider {
        case .ollama:
            return "sparkles"
        case .anthropic:
            return "sparkles"
        case .openai:
            return "brain"
        case .gemini:
            return "globe"
        case .custom:
            return "server.rack"
        }
    }
}
