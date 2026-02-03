import SwiftUI
import MarkdownUI

// Claude-style artifact indicator card shown in chat when an artifact is created
struct ArtifactIndicatorCard: View {
    let title: String
    let type: String
    
    @State private var isHovered = false
    
    private var icon: String {
        switch type {
        case "react": return "atom"
        case "html": return "doc.text"
        case "svg": return "square.on.circle"
        case "mermaid": return "point.3.connected.trianglepath.dotted"
        case "chart": return "chart.bar"
        case "canvas": return "paintbrush"
        case "three": return "cube"
        case "slides": return "rectangle.on.rectangle"
        case "animation": return "sparkles"
        case "sketch": return "pencil.and.outline"
        case "d3": return "chart.dots.scatter"
        default: return "sparkles"
        }
    }
    
    private var typeName: String {
        switch type {
        case "react": return "React Component"
        case "html": return "HTML"
        case "svg": return "SVG"
        case "mermaid": return "Diagram"
        case "chart": return "Chart"
        case "canvas": return "Canvas"
        case "three": return "3D Scene"
        case "slides": return "Presentation"
        case "animation": return "Animation"
        case "sketch": return "Sketch"
        case "d3": return "D3 Visualization"
        default: return "Artifact"
        }
    }
    
    var body: some View {
        Button {
            // Clicking opens the artifact panel (if there's a current artifact)
            NotificationCenter.default.post(name: .openArtifactInPanel, object: nil)
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(typeName)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        
                        Text("• Click to view")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(ThemeColors.success)
                        .frame(width: 6, height: 6)
                    Text("Ready")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 8 : 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .padding(.vertical, 4)
    }
}

struct CollapsibleMessageContent: View {
    let content: String
    let role: MessageRole
    let isPromptEnhanced: Bool
    let messageId: UUID
    let conversationId: UUID

    @Environment(\.colorScheme) private var colorScheme

    // Adaptive colors helper
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    private let collapseThreshold = 2000 // Characters
    @State private var isExpanded = false

    private var shouldCollapse: Bool {
        content.count > collapseThreshold
    }

    // Text color adapts to role and color scheme
    private var textColor: Color {
        if role == .user {
            // User messages: slightly lighter text in dark mode, darker in light mode
            return colorScheme == .dark ? Color(hex: "eeeeee") : Color(hex: "1d1d1f")
        } else {
            // Assistant/system messages: use system text color which adapts automatically
            return Color(nsColor: .textColor)
        }
    }

    private var previewContent: String {
        String(content.prefix(collapseThreshold))
    }

    // Detect if message contains artifact creation indicator
    private var detectedArtifactInfo: (title: String, type: String)? {
        // Look for artifact JSON in the content
        if let jsonRange = content.range(of: #"\{"artifact_type"[^}]+\}"#, options: .regularExpression),
           let jsonData = String(content[jsonRange]).data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let type = json["artifact_type"] as? String,
           let title = json["artifact_title"] as? String {
            return (title, type)
        }
        
        // Look for common artifact creation phrases
        let artifactPhrases = [
            ("dashboard", "react"),
            ("chart", "react"),
            ("visualization", "react"),
            ("component", "react"),
            ("diagram", "mermaid"),
            ("flowchart", "mermaid"),
            ("presentation", "slides"),
            ("3D", "three")
        ]
        
        let lower = content.lowercased()
        if lower.contains("created") || lower.contains("here's your") || lower.contains("i've built") || lower.contains("here is the") {
            for (keyword, type) in artifactPhrases {
                if lower.contains(keyword) {
                    let title = keyword.capitalized + " Preview"
                    return (title, type)
                }
            }
        }
        
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show artifact indicator card if detected (Claude-style)
            if let artifactInfo = detectedArtifactInfo, role == .assistant {
                ArtifactIndicatorCard(title: artifactInfo.title, type: artifactInfo.type)
            }
            
            // Visualizations are now shown as artifact cards in CodeBlockView, not inline previews
            if shouldCollapse && !isExpanded {
                Markdown(previewContent + "...")
                    .markdownTextStyle(\.text) {
                        ForegroundColor(textColor)
                        FontSize(15)
                    }
                    .markdownTextStyle(\.code) {
                        FontFamilyVariant(.monospaced)
                        FontSize(14)
                        ForegroundColor(colors.accent)
                        BackgroundColor(colors.accentBackground)
                    }
                    .markdownBlockStyle(\.codeBlock) { configuration in
                        CodeBlockView(
                            language: configuration.language,
                            messageContent: content,
                            codeLabel: configuration.label,
                            messageId: messageId,
                            conversationId: conversationId
                        )
                    }
                    .markdownBlockStyle(\.blockquote) { configuration in
                        configuration.label
                            .padding(.leading, 12)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(colors.info.opacity(0.5))
                                    .frame(width: 4)
                            }
                    }
                    .markdownBlockStyle(\.table) { configuration in
                        configuration.label
                            .padding(8)
                            .background(colors.surface.opacity(0.5))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(colors.border, lineWidth: 1)
                            )
                    }
                    .textSelection(.enabled)

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Show more")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colors.accentBackground)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                Markdown(content)
                    .markdownTextStyle(\.text) {
                        ForegroundColor(textColor)
                        FontSize(15)
                    }
                    .markdownTextStyle(\.code) {
                        FontFamilyVariant(.monospaced)
                        FontSize(14)
                        ForegroundColor(colors.accent)
                        BackgroundColor(colors.accentBackground)
                    }
                    .markdownBlockStyle(\.codeBlock) { configuration in
                        CodeBlockView(
                            language: configuration.language,
                            messageContent: content,
                            codeLabel: configuration.label,
                            messageId: messageId,
                            conversationId: conversationId
                        )
                    }
                    .markdownBlockStyle(\.blockquote) { configuration in
                        configuration.label
                            .padding(.leading, 12)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(colors.info.opacity(0.5))
                                    .frame(width: 4)
                            }
                    }
                    .markdownBlockStyle(\.table) { configuration in
                        configuration.label
                            .padding(8)
                            .background(colors.surface.opacity(0.5))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(colors.border, lineWidth: 1)
                            )
                    }
                    .textSelection(.enabled)

                if shouldCollapse && isExpanded {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Show less")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.up")
                                .font(.caption2)
                        }
                        .foregroundStyle(colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colors.accentBackground)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
