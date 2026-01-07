import SwiftUI
import MarkdownUI

struct CollapsibleMessageContent: View {
    let content: String
    let role: MessageRole
    let isPromptEnhanced: Bool
    let messageId: UUID
    let conversationId: UUID
    
    private let collapseThreshold = 2000 // Characters
    @State private var isExpanded = false
    @State private var detectedVisualizations: [(type: VisualizationType, content: String, range: Range<String.Index>)] = []
    
    private var shouldCollapse: Bool {
        content.count > collapseThreshold
    }
    
    private var previewContent: String {
        String(content.prefix(collapseThreshold))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Render visualizations first
            if !detectedVisualizations.isEmpty {
                ForEach(Array(detectedVisualizations.enumerated()), id: \.offset) { index, viz in
                    VisualizationView(type: viz.type, content: viz.content, messageId: messageId)
                        .padding(.vertical, 8)
                }
            }
            
            if shouldCollapse && !isExpanded {
                Markdown(previewContent + "...")
                    .markdownTextStyle(\.text) {
                        ForegroundColor(role == .user ? Color(hex: "eeeeee") : Color(nsColor: .textColor))
                        FontSize(15)
                    }
                    .markdownTextStyle(\.code) {
                        FontFamilyVariant(.monospaced)
                        FontSize(14)
                        ForegroundColor(Color(hex: "00976d"))
                        BackgroundColor(Color(hex: "00976d").opacity(0.12))
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
                                    .fill(Color.blue.opacity(0.5))
                                    .frame(width: 4)
                            }
                    }
                    .markdownBlockStyle(\.table) { configuration in
                        configuration.label
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .textSelection(.enabled)
                
                // Render visualizations in preview
                if !detectedVisualizations.isEmpty {
                    ForEach(Array(detectedVisualizations.enumerated()), id: \.offset) { index, viz in
                        VisualizationView(type: viz.type, content: viz.content, messageId: messageId)
                            .padding(.vertical, 8)
                    }
                }
                
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
                    .foregroundStyle(Color(hex: "00976d"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "00976d").opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                Markdown(content)
                    .markdownTextStyle(\.text) {
                        ForegroundColor(role == .user ? Color(hex: "eeeeee") : Color(nsColor: .textColor))
                        FontSize(15)
                    }
                    .markdownTextStyle(\.code) {
                        FontFamilyVariant(.monospaced)
                        FontSize(14)
                        ForegroundColor(Color(hex: "00976d"))
                        BackgroundColor(Color(hex: "00976d").opacity(0.12))
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
                                    .fill(Color.blue.opacity(0.5))
                                    .frame(width: 4)
                            }
                    }
                    .markdownBlockStyle(\.table) { configuration in
                        configuration.label
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .textSelection(.enabled)
                
                // Render visualizations
                if !detectedVisualizations.isEmpty {
                    ForEach(Array(detectedVisualizations.enumerated()), id: \.offset) { index, viz in
                        VisualizationView(type: viz.type, content: viz.content, messageId: messageId)
                            .padding(.vertical, 8)
                    }
                }
                
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
                        .foregroundStyle(Color(hex: "00976d"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "00976d").opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            detectVisualizations()
        }
    }
    
    private func detectVisualizations() {
        // Detect all visualizations in the content
        var visualizations: [(type: VisualizationType, content: String, range: Range<String.Index>)] = []
        
        // Check for each visualization type
        if let html = VisualizationService.shared.extractVisualization(from: content, type: .html) {
            if let range = content.range(of: #"```html\s*\n([\s\S]*?)```"#, options: .regularExpression) {
                visualizations.append((.html, html, range))
            }
        }
        
        if let mermaid = VisualizationService.shared.extractVisualization(from: content, type: .mermaid) {
            if let range = content.range(of: #"```mermaid\s*\n([\s\S]*?)```"#, options: .regularExpression) {
                visualizations.append((.mermaid, mermaid, range))
            }
        }
        
        if let excalidraw = VisualizationService.shared.extractVisualization(from: content, type: .excalidraw) {
            if let range = content.range(of: #"```excalidraw\s*\n([\s\S]*?)```"#, options: .regularExpression) {
                visualizations.append((.excalidraw, excalidraw, range))
            }
        }
        
        if let svg = VisualizationService.shared.extractVisualization(from: content, type: .svg) {
            if let range = content.range(of: #"```svg\s*\n([\s\S]*?)```"#, options: .regularExpression) {
                visualizations.append((.svg, svg, range))
            }
        }
        
        detectedVisualizations = visualizations
    }
}
