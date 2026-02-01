import Foundation

/// Represents a renderable artifact (React component, HTML, SVG, etc.)
struct Artifact: Identifiable, Codable {
    let id: UUID
    let type: ArtifactType
    let title: String
    let content: String
    let language: String
    let createdAt: Date
    var isExpanded: Bool = false

    init(id: UUID = UUID(), type: ArtifactType, title: String, content: String, language: String, createdAt: Date = Date()) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.language = language
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, type, title, content, language, createdAt
    }
}

enum ArtifactType: String, Codable {
    case react = "react"
    case html = "html"
    case svg = "svg"
    case mermaid = "mermaid"
    case chart = "chart"
    case canvas = "canvas"       // Fabric.js / Konva canvas
    case three = "three"         // Three.js 3D
    case presentation = "slides" // Reveal.js presentations
    case animation = "animation" // Anime.js / Framer Motion
    case sketch = "sketch"       // Rough.js hand-drawn style
    case d3 = "d3"               // D3.js visualizations

    var displayName: String {
        switch self {
        case .react: return "React Component"
        case .html: return "HTML"
        case .svg: return "SVG"
        case .mermaid: return "Diagram"
        case .chart: return "Chart"
        case .canvas: return "Canvas"
        case .three: return "3D Scene"
        case .presentation: return "Presentation"
        case .animation: return "Animation"
        case .sketch: return "Sketch"
        case .d3: return "D3 Visualization"
        }
    }

    var icon: String {
        switch self {
        case .react: return "atom"
        case .html: return "doc.text"
        case .svg: return "square.on.circle"
        case .mermaid: return "point.3.connected.trianglepath.dotted"
        case .chart: return "chart.bar"
        case .canvas: return "paintbrush"
        case .three: return "cube"
        case .presentation: return "rectangle.on.rectangle"
        case .animation: return "sparkles"
        case .sketch: return "pencil.and.outline"
        case .d3: return "chart.dots.scatter"
        }
    }
}

/// Detects artifacts in code blocks
struct ArtifactDetector {

    /// Detect if a code block represents an artifact
    static func detectArtifact(code: String, language: String?) -> Artifact? {
        guard let lang = language?.lowercased() else { return nil }

        // React/JSX detection
        if lang.contains("react") || lang.contains("jsx") || lang.contains("tsx") {
            let title = extractComponentName(from: code) ?? "React Component"
            return Artifact(type: .react, title: title, content: code, language: lang)
        }

        // Three.js / 3D detection
        if lang == "three" || lang == "threejs" || lang == "3d" || lang == "webgl" {
            return Artifact(type: .three, title: "3D Scene", content: code, language: "three")
        }

        // D3.js detection
        if lang == "d3" || lang == "d3js" {
            return Artifact(type: .d3, title: "D3 Visualization", content: code, language: "d3")
        }

        // Canvas / Fabric.js detection
        if lang == "canvas" || lang == "fabric" || lang == "konva" {
            return Artifact(type: .canvas, title: "Canvas", content: code, language: "canvas")
        }

        // Presentation / Slides detection
        if lang == "slides" || lang == "presentation" || lang == "reveal" {
            return Artifact(type: .presentation, title: "Presentation", content: code, language: "slides")
        }

        // Animation detection
        if lang == "animation" || lang == "anime" || lang == "motion" || lang == "gsap" {
            return Artifact(type: .animation, title: "Animation", content: code, language: "animation")
        }

        // Sketch / Rough.js detection
        if lang == "sketch" || lang == "rough" || lang == "hand-drawn" {
            return Artifact(type: .sketch, title: "Sketch", content: code, language: "sketch")
        }

        // HTML detection (with visual content)
        if lang == "html" || lang == "htm" {
            if containsVisualContent(code) {
                let title = extractHTMLTitle(from: code) ?? "HTML Preview"
                return Artifact(type: .html, title: title, content: code, language: lang)
            }
        }

        // SVG detection
        if lang == "svg" || (lang == "xml" && code.contains("<svg")) {
            return Artifact(type: .svg, title: "SVG Image", content: code, language: "svg")
        }

        // Mermaid diagram detection
        if lang == "mermaid" {
            let diagramType = extractMermaidType(from: code)
            return Artifact(type: .mermaid, title: diagramType, content: code, language: lang)
        }

        return nil
    }

    /// Extract React component name from code
    private static func extractComponentName(from code: String) -> String? {
        // Match: function ComponentName, const ComponentName =, export default ComponentName
        let patterns = [
            "function\\s+([A-Z][a-zA-Z0-9]*)",
            "const\\s+([A-Z][a-zA-Z0-9]*)\\s*=",
            "class\\s+([A-Z][a-zA-Z0-9]*)\\s+extends",
            "export\\s+default\\s+([A-Z][a-zA-Z0-9]*)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: code, options: [], range: NSRange(code.startIndex..., in: code)),
               let range = Range(match.range(at: 1), in: code) {
                return String(code[range])
            }
        }
        return nil
    }

    /// Check if HTML contains visual content worth previewing
    private static func containsVisualContent(_ code: String) -> Bool {
        let visualTags = ["<div", "<canvas", "<svg", "<img", "<video", "<table", "<form", "<button", "<input", "<style", "<section", "<article", "<main", "<header", "<footer", "<nav"]
        let lowercased = code.lowercased()
        return visualTags.contains { lowercased.contains($0) }
    }

    /// Extract title from HTML
    private static func extractHTMLTitle(from code: String) -> String? {
        if let regex = try? NSRegularExpression(pattern: "<title>([^<]+)</title>", options: .caseInsensitive),
           let match = regex.firstMatch(in: code, options: [], range: NSRange(code.startIndex..., in: code)),
           let range = Range(match.range(at: 1), in: code) {
            return String(code[range])
        }
        return nil
    }

    /// Extract mermaid diagram type
    private static func extractMermaidType(from code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasPrefix("graph") || trimmed.hasPrefix("flowchart") {
            return "Flowchart"
        } else if trimmed.hasPrefix("sequencediagram") {
            return "Sequence Diagram"
        } else if trimmed.hasPrefix("classDiagram") {
            return "Class Diagram"
        } else if trimmed.hasPrefix("statediagram") {
            return "State Diagram"
        } else if trimmed.hasPrefix("erdiagram") {
            return "ER Diagram"
        } else if trimmed.hasPrefix("gantt") {
            return "Gantt Chart"
        } else if trimmed.hasPrefix("pie") {
            return "Pie Chart"
        }
        return "Diagram"
    }
}
