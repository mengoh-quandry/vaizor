import Foundation

/// Service for detecting and rendering code visualizations (HTML, Mermaid, Excalidraw, etc.)
@MainActor
class VisualizationService {
    static let shared = VisualizationService()
    
    private init() {}
    
    /// Detect the type of visualization in content
    func detectVisualizationType(in content: String) -> VisualizationType? {
        // Check for HTML content
        if isHTML(content) {
            return .html
        }
        
        // Check for Mermaid diagram
        if isMermaid(content) {
            return .mermaid
        }
        
        // Check for Excalidraw
        if isExcalidraw(content) {
            return .excalidraw
        }
        
        // Check for SVG
        if isSVG(content) {
            return .svg
        }
        
        return nil
    }
    
    /// Extract visualization content from markdown code blocks
    func extractVisualization(from content: String, type: VisualizationType) -> String? {
        switch type {
        case .html:
            return extractHTML(from: content)
        case .mermaid:
            return extractMermaid(from: content)
        case .excalidraw:
            return extractExcalidraw(from: content)
        case .svg:
            return extractSVG(from: content)
        }
    }
    
    // MARK: - Detection
    
    private func isHTML(_ content: String) -> Bool {
        // Check for HTML code blocks with html language tag
        let htmlPattern = #"```html\s*\n([\s\S]*?)```"#
        if let _ = content.range(of: htmlPattern, options: .regularExpression) {
            return true
        }
        
        // Check for standalone HTML tags
        let htmlTagPattern = #"<html[\s>]|<body[\s>]|<div[\s>]|<p[\s>]|<h[1-6][\s>]"#
        return content.range(of: htmlTagPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    private func isMermaid(_ content: String) -> Bool {
        // Check for mermaid code blocks
        let mermaidPattern = #"```mermaid\s*\n([\s\S]*?)```"#
        return content.range(of: mermaidPattern, options: .regularExpression) != nil
    }
    
    private func isExcalidraw(_ content: String) -> Bool {
        // Check for excalidraw JSON format
        let excalidrawPattern = #"```excalidraw\s*\n([\s\S]*?)```"#
        if content.range(of: excalidrawPattern, options: .regularExpression) != nil {
            return true
        }
        
        // Check for Excalidraw JSON structure
        if content.contains("\"type\":\"excalidraw") || content.contains("\"appState\"") && content.contains("\"elements\"") {
            return true
        }
        
        return false
    }
    
    private func isSVG(_ content: String) -> Bool {
        // Check for SVG code blocks or inline SVG
        let svgPattern = #"```svg\s*\n([\s\S]*?)```|<svg[\s>]"#
        return content.range(of: svgPattern, options: .regularExpression) != nil
    }
    
    // MARK: - Extraction
    
    private func extractHTML(from content: String) -> String? {
        // Extract from ```html code blocks
        let pattern = #"```html\s*\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           match.range(at: 1).location != NSNotFound,
           let htmlRange = Range(match.range(at: 1), in: content) {
            return String(content[htmlRange])
        }
        
        // Extract standalone HTML
        if let htmlStart = content.range(of: "<html", options: .caseInsensitive),
           let htmlEnd = content.range(of: "</html>", options: .caseInsensitive, range: htmlStart.upperBound..<content.endIndex) {
            return String(content[htmlStart.lowerBound...htmlEnd.upperBound])
        }
        
        return nil
    }
    
    private func extractMermaid(from content: String) -> String? {
        let pattern = #"```mermaid\s*\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           match.range(at: 1).location != NSNotFound,
           let mermaidRange = Range(match.range(at: 1), in: content) {
            return String(content[mermaidRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func extractExcalidraw(from content: String) -> String? {
        // Extract from ```excalidraw code blocks
        let pattern = #"```excalidraw\s*\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           match.range(at: 1).location != NSNotFound,
           let excalidrawRange = Range(match.range(at: 1), in: content) {
            return String(content[excalidrawRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Try to extract JSON directly
        if let jsonStart = content.range(of: "{"),
           let jsonEnd = content.range(of: "}", options: .backwards) {
            let jsonContent = String(content[jsonStart.lowerBound...jsonEnd.upperBound])
            if jsonContent.contains("\"type\":\"excalidraw") || (jsonContent.contains("\"appState\"") && jsonContent.contains("\"elements\"")) {
                return jsonContent
            }
        }
        
        return nil
    }
    
    private func extractSVG(from content: String) -> String? {
        // Extract from ```svg code blocks
        let pattern = #"```svg\s*\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           match.range(at: 1).location != NSNotFound,
           let svgRange = Range(match.range(at: 1), in: content) {
            return String(content[svgRange])
        }
        
        // Extract inline SVG
        if let svgStart = content.range(of: "<svg"),
           let svgEnd = content.range(of: "</svg>", range: svgStart.upperBound..<content.endIndex) {
            return String(content[svgStart.lowerBound...svgEnd.upperBound])
        }
        
        return nil
    }
}

enum VisualizationType {
    case html
    case mermaid
    case excalidraw
    case svg
}
