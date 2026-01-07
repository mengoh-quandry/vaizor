import SwiftUI
import MarkdownUI

struct MessageBubbleView: View {
    let message: Message
    let provider: LLMProvider?
    let isPromptEnhanced: Bool
    let onCopy: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onRegenerate: (() -> Void)?
    let onRegenerateDifferent: (() -> Void)?
    let onScrollToTop: (() -> Void)?
    
    init(
        message: Message,
        provider: LLMProvider? = nil,
        isPromptEnhanced: Bool = false,
        onCopy: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onRegenerate: (() -> Void)? = nil,
        onRegenerateDifferent: (() -> Void)? = nil,
        onScrollToTop: (() -> Void)? = nil
    ) {
        self.message = message
        self.provider = provider
        self.isPromptEnhanced = isPromptEnhanced
        self.onCopy = onCopy
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onRegenerate = onRegenerate
        self.onRegenerateDifferent = onRegenerateDifferent
        self.onScrollToTop = onScrollToTop
    }

    @State private var isHovered = false
    @State private var hoverTask: Task<Void, Never>?
    @State private var scale: CGFloat = 1.0

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            // Avatar
            if message.role == .assistant || message.role == .system || message.role == .tool {
                avatarView
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    // Image attachments
                    if let attachments = message.attachments {
                        ForEach(attachments.filter { $0.isImage }) { attachment in
                            ImageAttachmentView(imageData: attachment.data)
                        }
                    }

                    // Markdown content with inline images
                    CollapsibleMessageContent(
                        content: message.content,
                        role: message.role,
                        isPromptEnhanced: isPromptEnhanced,
                        messageId: message.id,
                        conversationId: message.conversationId
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        backgroundColor
                        if message.role == .assistant && isHovered {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        }
                    }
                )
                .cornerRadius(20)
                .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .scaleEffect(scale)
                .task {
                    // Pre-render markdown for caching (non-blocking)
                    await preloadMarkdownRender()
                }

                MessageTimestampView(timestamp: message.timestamp)
                    .padding(.horizontal, 4)
                
                // Action row (shown on hover)
                if isHovered {
                    MessageActionRow(
                        message: message,
                        isUser: message.role == .user,
                        isPromptEnhanced: isPromptEnhanced && message.role == .user,
                        onCopy: { onCopy?() },
                        onEdit: message.role == .user ? onEdit : nil,
                        onDelete: { onDelete?() },
                        onRegenerate: message.role == .assistant ? onRegenerate : nil,
                        onRegenerateDifferent: message.role == .assistant ? onRegenerateDifferent : nil,
                        onScrollToTop: message.role == .assistant ? onScrollToTop : nil
                    )
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .onHover { hovering in
                // Cancel any pending hide task
                hoverTask?.cancel()

                if hovering {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isHovered = true
                        scale = 1.005
                    }
                } else {
                    // Keep visible for 2 more seconds after hover ends
                    hoverTask = Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        if !Task.isCancelled {
                            await MainActor.run {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    isHovered = false
                                    scale = 1.0
                                }
                            }
                        }
                    }
                }
            }

            // Avatar for user
            if message.role == .user {
                avatarView
            }

            if message.role == .assistant || message.role == .system || message.role == .tool {
                Spacer(minLength: 60)
            }
        }
    }

    @ViewBuilder
    private var ollamaIconView: some View {
        let fileManager = FileManager.default
        let possiblePaths = [
            Bundle.main.bundlePath + "/../../Resources/Icons/ollama.jpeg",
            Bundle.main.bundlePath + "/Resources/Icons/ollama.jpeg",
            Bundle.main.resourcePath.map { $0 + "/Resources/Icons/ollama.jpeg" },
            Bundle.main.resourcePath.map { $0 + "/../../Resources/Icons/ollama.jpeg" },
            "/Users/marcus/Downloads/vaizor/Resources/Icons/ollama.jpeg"
        ].compactMap { $0 }
        
        if let ollamaPath = possiblePaths.first(where: { fileManager.fileExists(atPath: $0) }),
           let nsImage = NSImage(contentsOfFile: ollamaPath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        } else {
            // Fallback to Vaizor green sparkles icon
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(hex: "00976d"))
                .frame(width: 32, height: 32)
        }
    }
    
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(avatarBackgroundColor)
                .frame(width: 32, height: 32)

            if message.role == .user {
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(avatarForegroundColor)
            } else if message.role == .assistant {
                // Use provider-specific icon if available
                if let provider = provider {
                    if provider == .ollama {
                        ollamaIconView
                    } else {
                        // Load provider icon (PNG images for frontier models: Anthropic, OpenAI, Gemini)
                        ProviderIconManager.icon(for: provider)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    }
                } else {
                    // Default Vaizor green icon for unknown models
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(hex: "00976d"))
                        .frame(width: 32, height: 32)
                }
            } else {
                Image(systemName: avatarIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(avatarForegroundColor)
            }
        }
    }

    private var avatarIcon: String {
        switch message.role {
        case .user:
            return "person.fill"
        case .assistant:
            return "sparkles"
        case .tool:
            return "wrench.and.screwdriver.fill"
        case .system:
            return "gearshape.fill"
        }
    }

    private var avatarBackgroundColor: Color {
        switch message.role {
        case .user:
            return Color(hex: "00976d").opacity(0.2)
        case .assistant:
            // Use Vaizor green for default, provider-specific colors can override
            return Color(hex: "00976d").opacity(0.2)
        case .tool:
            return Color.orange.opacity(0.2)
        case .system:
            return Color.gray.opacity(0.2)
        }
    }

    private var avatarForegroundColor: Color {
        switch message.role {
        case .user:
            return Color(hex: "eeeeee")
        case .assistant:
            // Use Vaizor green for default
            return Color(hex: "00976d")
        case .tool:
            return Color.orange
        case .system:
            return Color.gray
        }
    }

    private var foregroundColor: Color {
        message.role == .user ? .white : .primary
    }

    private var backgroundColor: some View {
        Group {
            switch message.role {
            case .user:
                Color(hex: "00976d")
            case .assistant:
                Color.clear
            case .system:
                Color.gray.opacity(0.2)
            case .tool:
                Color.orange.opacity(0.2)
            }
        }
    }

    private var shadowColor: Color {
        switch message.role {
        case .user:
            return Color.accentColor.opacity(isHovered ? 0.25 : 0.15)
        case .assistant:
            return Color.black.opacity(isHovered ? 0.08 : 0.03)
        case .system, .tool:
            return Color.black.opacity(0.05)
        }
    }

    private var shadowRadius: CGFloat {
        switch message.role {
        case .user:
            return isHovered ? 12 : 8
        case .assistant:
            return isHovered ? 6 : 2
        case .system, .tool:
            return 4
        }
    }

    private var shadowY: CGFloat {
        switch message.role {
        case .user:
            return isHovered ? 4 : 2
        case .assistant:
            return isHovered ? 2 : 1
        case .system, .tool:
            return 2
        }
    }
    
    @ViewBuilder
    private var markdownContentView: some View {
        Markdown(message.content)
            .markdownTextStyle(\.text) {
                ForegroundColor(message.role == .user ? Color(hex: "eeeeee") : Color(nsColor: .textColor))
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
                    messageContent: message.content,
                    codeLabel: configuration.label,
                    messageId: message.id,
                    conversationId: message.conversationId
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
            .markdownBlockStyle(\.image) { configuration in
                configuration.label
            }
            .textSelection(.enabled)
    }
    
    private func preloadMarkdownRender() async {
        // Pre-render markdown in background for caching (non-blocking)
        // This helps warm up the cache for smoother scrolling
        guard !message.content.isEmpty else { return }
        let cacheKey = "\(message.id.uuidString)-\(message.content.hashValue)"
        _ = await MarkdownRenderService.shared.render(message.content, cacheKey: cacheKey)
    }
    
}

// Code block view with copy button and execution
struct CodeBlockView<CodeLabel: View>: View {
    let language: String?
    let messageContent: String
    let codeLabel: CodeLabel
    let messageId: UUID
    let conversationId: UUID
    
    @State private var isHovered = false
    @State private var showCopiedFeedback = false
    @State private var codeContent: String = ""
    @State private var showExecution = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Code block header with language indicator and copy button
            HStack {
                Text(language ?? "code")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                
                if isHovered && !codeContent.isEmpty {
                    HStack(spacing: 4) {
                        // Copy button
                        Button {
                            copyCode()
                        } label: {
                            HStack(spacing: 4) {
                                if showCopiedFeedback {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if showCopiedFeedback {
                                    Text("Copied")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        
                        // Run button (for executable languages)
                        if detectCodeLanguage(language) != nil {
                            Button {
                                showExecution = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                        .font(.caption2)
                                    Text("Run")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "00976d").opacity(0.15))
                                .foregroundStyle(Color(hex: "00976d"))
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            // Use MarkdownUI's rendered code block
            codeLabel
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
        }
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            extractCodeContent()
        }
        .sheet(isPresented: $showExecution) {
            if let codeLang = detectCodeLanguage(language) {
                CodeExecutionView(
                    code: codeContent,
                    language: codeLang,
                    conversationId: conversationId
                )
                .frame(minWidth: 600, minHeight: 500)
            }
        }
    }
    
    private func detectCodeLanguage(_ lang: String?) -> CodeLanguage? {
        guard let lang = lang?.lowercased() else { return nil }
        
        if lang.contains("python") || lang == "py" {
            return .python
        } else if lang.contains("javascript") || lang.contains("js") || lang == "node" {
            return .javascript
        } else if lang.contains("swift") {
            return .swift
        }
        
        return nil
    }
    
    private func extractCodeContent() {
        // Extract code content from markdown code blocks
        // Match code blocks with optional language: ```language\ncode\n```
        let pattern = "```(?:[a-zA-Z0-9+_-]+)?\\n([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: messageContent, options: [], range: NSRange(messageContent.startIndex..., in: messageContent)),
           match.range(at: 1).location != NSNotFound,
           let codeRange = Range(match.range(at: 1), in: messageContent) {
            codeContent = String(messageContent[codeRange])
        }
    }
    
    private func copyCode() {
        guard !codeContent.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(codeContent, forType: .string)
        
        withAnimation {
            showCopiedFeedback = true
        }
        
        // Reset feedback after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation {
                    showCopiedFeedback = false
                }
            }
        }
    }
}

// Message timestamp view with full date/time on hover
struct MessageTimestampView: View {
    let timestamp: Date
    @State private var isHovered = false
    
    private var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }
    
    private var absoluteFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        Text(isHovered ? absoluteFormatter.string(from: timestamp) : relativeFormatter.localizedString(for: timestamp, relativeTo: Date()))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}
