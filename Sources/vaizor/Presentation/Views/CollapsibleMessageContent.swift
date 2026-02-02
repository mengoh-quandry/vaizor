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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Adaptive colors helper
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    private let collapseThreshold = 2000 // Characters for text content only
    @State private var isExpanded = false

    // Calculate if we should collapse based on text content only (excluding code blocks)
    private var textContentLength: Int {
        extractTextContent(from: content).count
    }

    private var shouldCollapse: Bool {
        textContentLength > collapseThreshold
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

    // Extract text content excluding code blocks for character counting
    private func extractTextContent(from markdown: String) -> String {
        var text = markdown
        // Remove fenced code blocks (```...```)
        let codeBlockPattern = #"```[\s\S]*?```"#
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            text = regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: NSRange(text.startIndex..., in: text),
                withTemplate: ""
            )
        }
        // Remove inline code (`...`)
        let inlineCodePattern = #"`[^`]+`"#
        if let regex = try? NSRegularExpression(pattern: inlineCodePattern, options: []) {
            text = regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: NSRange(text.startIndex..., in: text),
                withTemplate: ""
            )
        }
        return text
    }

    // Smart truncation that preserves code blocks and truncates at paragraph boundaries
    private var previewContent: String {
        // Strategy: Keep all code blocks, truncate text around them
        var result = ""
        var textCharCount = 0
        var index = content.startIndex

        while index < content.endIndex && textCharCount < collapseThreshold {
            // Check if we're at the start of a code block
            let remaining = String(content[index...])
            if remaining.hasPrefix("```") {
                // Find the end of this code block
                if let endRange = remaining.range(of: "```", range: remaining.index(remaining.startIndex, offsetBy: 3)..<remaining.endIndex) {
                    let codeBlockEnd = content.index(index, offsetBy: remaining.distance(from: remaining.startIndex, to: endRange.upperBound))
                    result += String(content[index..<codeBlockEnd])
                    index = codeBlockEnd
                    continue
                }
            }

            // Regular character - count towards text limit
            result.append(content[index])
            textCharCount += 1
            index = content.index(after: index)
        }

        // If we stopped mid-content, try to end at a natural break
        if index < content.endIndex {
            // Look for the last paragraph break, sentence end, or word boundary
            if let paragraphRange = result.range(of: "\n\n", options: .backwards) {
                let distance = result.distance(from: result.startIndex, to: paragraphRange.lowerBound)
                if distance > collapseThreshold / 2 {
                    result = String(result[..<paragraphRange.upperBound])
                }
            } else if let lastNewline = result.lastIndex(of: Character("\n")) {
                let distance = result.distance(from: result.startIndex, to: lastNewline)
                if distance > collapseThreshold * 3 / 4 {
                    result = String(result[...lastNewline])
                }
            } else if let lastPeriod = result.lastIndex(of: Character(".")) {
                let distance = result.distance(from: result.startIndex, to: lastPeriod)
                if distance > collapseThreshold * 3 / 4 {
                    result = String(result[...lastPeriod])
                }
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Calculate remaining content info for "Show more" button
    private var remainingInfo: (charCount: Int, hasMore: Bool) {
        let previewLen = previewContent.count
        let totalLen = content.count
        let remaining = totalLen - previewLen
        return (remaining, remaining > 0)
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

    // Animation for smooth expand/collapse
    private var expandAnimation: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.35, dampingFraction: 0.8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show artifact indicator card if detected (Claude-style)
            if let artifactInfo = detectedArtifactInfo, role == .assistant {
                ArtifactIndicatorCard(title: artifactInfo.title, type: artifactInfo.type)
            }

            // Visualizations are now shown as artifact cards in CodeBlockView, not inline previews
            if shouldCollapse && !isExpanded {
                // Collapsed state - show preview with truncation indicator
                VStack(alignment: .leading, spacing: 0) {
                    Markdown(previewContent)
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
                                codeContent: configuration.content,
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

                    // Fade-out gradient overlay to indicate more content
                    if remainingInfo.hasMore {
                        LinearGradient(
                            colors: [
                                Color.clear,
                                colors.background.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 40)
                        .allowsHitTesting(false)
                        .padding(.top, -40)
                    }
                }

                // Show more button
                Button {
                    withAnimation(expandAnimation) {
                        isExpanded = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 14))
                            .symbolRenderingMode(.hierarchical)
                        Text("Show more")
                            .font(.caption)
                            .fontWeight(.medium)
                        if remainingInfo.charCount > 0 {
                            Text("(\(formatCharCount(remainingInfo.charCount)) more)")
                                .font(.caption2)
                                .foregroundStyle(colors.textSecondary)
                        }
                    }
                    .foregroundStyle(colors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(colors.accentBackground)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                // Expanded or not needing collapse
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
                            codeContent: configuration.content,
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

                // Show less button (only if message was collapsible)
                if shouldCollapse && isExpanded {
                    Button {
                        withAnimation(expandAnimation) {
                            isExpanded = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.system(size: 14))
                                .symbolRenderingMode(.hierarchical)
                            Text("Show less")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(colors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(colors.accentBackground)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
        }
        .animation(expandAnimation, value: isExpanded)
    }

    // Format character count for display
    private func formatCharCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}
