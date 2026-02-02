import SwiftUI
import MarkdownUI

struct MessageBubbleView: View {
    let message: Message
    let provider: LLMProvider?
    let isPromptEnhanced: Bool
    let onCopy: (() -> Void)?
    let onEdit: ((String) -> Void)?  // Changed: passes the new content when saved
    let onDelete: (() -> Void)?
    let onRegenerate: (() -> Void)?
    let onRegenerateDifferent: (() -> Void)?
    let onScrollToTop: (() -> Void)?
    let animationIndex: Int
    let shouldAnimateAppear: Bool

    init(
        message: Message,
        provider: LLMProvider? = nil,
        isPromptEnhanced: Bool = false,
        onCopy: (() -> Void)? = nil,
        onEdit: ((String) -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onRegenerate: (() -> Void)? = nil,
        onRegenerateDifferent: (() -> Void)? = nil,
        onScrollToTop: (() -> Void)? = nil,
        animationIndex: Int = 0,
        shouldAnimateAppear: Bool = true
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
        self.animationIndex = animationIndex
        self.shouldAnimateAppear = shouldAnimateAppear
    }

    // Editing state
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isEditFocused: Bool

    @State private var isHovered = false
    @State private var hoverTask: Task<Void, Never>?
    @State private var scale: CGFloat = 1.0
    @State private var hasAppeared = false
    @State private var appearOffset: CGFloat = 8
    @State private var appearOpacity: Double = 0
    @State private var appearScale: CGFloat = 0.95
    @State private var toolRuns: [ToolRun] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // Adaptive colors helper
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    // Animation stability: Use consistent timing constants
    private let hoverShowDuration: Double = 0.15
    private let hoverHideDuration: Double = 0.2
    private let hoverDismissDelay: UInt64 = 800_000_000 // 0.8s - reduced from 1.5s for snappier feel

    var body: some View {
        HStack(alignment: .top, spacing: VaizorSpacing.sm) {
            // Left spacer for user messages - 25% minimum to constrain width
            if message.role == .user {
                Spacer(minLength: 0)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .layoutPriority(-1)
            }

            // Avatar
            if message.role == .assistant || message.role == .system || message.role == .tool {
                avatarView
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: VaizorSpacing.xs) {
                VStack(alignment: .leading, spacing: VaizorSpacing.xs) {
                    // Tool calls for this message (assistant messages only)
                    if message.role == .assistant && !toolRuns.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(toolRuns) { toolRun in
                                CollapsibleToolCallView(toolRun: toolRun)
                            }
                        }
                        .padding(.bottom, 8)
                    }

                    // Mention references (for user messages)
                    if let refs = message.mentionReferences, !refs.isEmpty {
                        MessageMentionReferencesView(references: refs)
                    }

                    // Image attachments
                    if let attachments = message.attachments {
                        ForEach(attachments.filter { $0.isImage }) { attachment in
                            ImageAttachmentView(imageData: attachment.data)
                        }
                    }

                    // Show editing UI or regular content
                    if isEditing && message.role == .user {
                        // Inline editing view
                        VStack(alignment: .trailing, spacing: VaizorSpacing.xs) {
                            TextEditor(text: $editText)
                                .font(.system(size: 15))
                                .scrollContentBackground(.hidden)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(VaizorSpacing.radiusMd)
                                .frame(minHeight: 60, maxHeight: 200)
                                .focused($isEditFocused)
                                .overlay(
                                    RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd)
                                        .stroke(colors.accent.opacity(0.5), lineWidth: 1)
                                )

                            // Save/Cancel buttons
                            HStack(spacing: VaizorSpacing.xs) {
                                Button {
                                    cancelEditing()
                                } label: {
                                    Text("Cancel")
                                        .font(VaizorTypography.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, VaizorSpacing.sm)
                                        .padding(.vertical, VaizorSpacing.xxs)
                                }
                                .buttonStyle(.plain)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(VaizorSpacing.radiusSm)
                                .keyboardShortcut(.escape, modifiers: [])

                                Button {
                                    saveEdit()
                                } label: {
                                    Text("Save & Regenerate")
                                        .font(VaizorTypography.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, VaizorSpacing.sm)
                                        .padding(.vertical, VaizorSpacing.xxs)
                                }
                                .buttonStyle(.plain)
                                .background(colors.accent)
                                .cornerRadius(VaizorSpacing.radiusSm)
                                .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .keyboardShortcut(.return, modifiers: .command)
                            }
                        }
                    } else {
                        // Markdown content with inline images
                        CollapsibleMessageContent(
                            content: message.content,
                            role: message.role,
                            isPromptEnhanced: isPromptEnhanced,
                            messageId: message.id,
                            conversationId: message.conversationId
                        )
                    }
                }
                .padding(.horizontal, VaizorSpacing.md)
                .padding(.vertical, VaizorSpacing.sm)
                // Clean design: No background or border on bubbles
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityMessageLabel)
                .task {
                    await preloadMarkdownRender()
                }

                MessageTimestampView(timestamp: message.timestamp)
                    .padding(.horizontal, VaizorSpacing.xxs)

                // Action row - always present but hidden until hover (prevents layout shift)
                // Hide when editing
                if !isEditing {
                    MessageActionRow(
                        message: message,
                        isUser: message.role == .user,
                        isPromptEnhanced: isPromptEnhanced && message.role == .user,
                        onCopy: { onCopy?() },
                        onEdit: message.role == .user ? { startEditing() } : nil,
                        onDelete: { onDelete?() },
                        onRegenerate: message.role == .assistant ? onRegenerate : nil,
                        onRegenerateDifferent: message.role == .assistant ? onRegenerateDifferent : nil,
                        onScrollToTop: message.role == .assistant ? onScrollToTop : nil
                    )
                    .opacity(isHovered ? 1 : 0)
                }
            }
            // Constrain message width to ~75% of container
            .frame(maxWidth: 800)
            .onHover { hovering in
                // Cancel any pending hover task immediately
                hoverTask?.cancel()
                hoverTask = nil

                if hovering {
                    // Show immediately with animation (respect reduce motion)
                    if reduceMotion {
                        isHovered = true
                    } else {
                        withAnimation(.easeInOut(duration: hoverShowDuration)) {
                            isHovered = true
                        }
                    }
                } else {
                    // Delay hiding to prevent flickering when moving between elements
                    hoverTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: hoverDismissDelay)
                        guard !Task.isCancelled else { return }
                        if reduceMotion {
                            isHovered = false
                        } else {
                            withAnimation(.easeOut(duration: hoverHideDuration)) {
                                isHovered = false
                            }
                        }
                    }
                }
            }
            .onDisappear {
                // Clean up any pending tasks when view disappears
                hoverTask?.cancel()
                hoverTask = nil
            }

            // Avatar for user
            if message.role == .user {
                avatarView
            }

            // Right spacer for assistant messages - 25% minimum to constrain width
            if message.role == .assistant || message.role == .system || message.role == .tool {
                Spacer(minLength: 0)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .layoutPriority(-1)
            }
        }
        // Premium appear animation
        .scaleEffect(hasAppeared || reduceMotion || !shouldAnimateAppear ? 1.0 : appearScale)
        .opacity(hasAppeared || reduceMotion || !shouldAnimateAppear ? 1.0 : appearOpacity)
        .offset(y: hasAppeared || reduceMotion || !shouldAnimateAppear ? 0 : appearOffset)
        .onAppear {
            guard shouldAnimateAppear && !reduceMotion && !hasAppeared else {
                hasAppeared = true
                appearOpacity = 1
                appearScale = 1
                appearOffset = 0
                return
            }

            // Staggered appear animation
            let delay = VaizorAnimations.staggerDelay(for: animationIndex)
            withAnimation(VaizorAnimations.messageAppear.delay(delay)) {
                hasAppeared = true
                appearOpacity = 1
                appearScale = 1
                appearOffset = 0
            }
        }
        .task {
            // Load tool runs for assistant messages
            guard message.role == .assistant else { return }
            let repository = ToolRunRepository()
            toolRuns = await repository.loadToolRuns(for: message.id)
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
                .frame(width: 30, height: 30)
                .clipShape(Circle())
        } else {
            // Fallback to system icon
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(colors.accent)
                .frame(width: 30, height: 30)
        }
    }
    
    private var avatarView: some View {
        ZStack {
            // Tahoe-style: Subtle background with refined shape
            Circle()
                .fill(avatarBackgroundColor)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(colors.border, lineWidth: 0.5)
                )

            if message.role == .user {
                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
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
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    }
                } else {
                    // Default icon for unknown models
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(colors.accent)
                        .frame(width: 30, height: 30)
                }
            } else {
                Image(systemName: avatarIcon)
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
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
            return colors.accentBackground
        case .assistant:
            return colors.accentBackground
        case .tool:
            return colors.toolBackground
        case .system:
            return colors.systemBubble
        }
    }

    private var avatarForegroundColor: Color {
        switch message.role {
        case .user:
            return colors.textPrimary
        case .assistant:
            return colors.accent
        case .tool:
            return colors.toolAccent
        case .system:
            return colors.textSecondary
        }
    }

    private var foregroundColor: Color {
        message.role == .user ? .white : .primary
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        switch message.role {
        case .user:
            // Tahoe-style: subtle accent tint with continuous corners
            RoundedRectangle(cornerRadius: VaizorSpacing.bubbleRadius, style: .continuous)
                .fill(colors.userBubble)
        case .assistant:
            // Tahoe-style: clean surface with subtle material effect
            RoundedRectangle(cornerRadius: VaizorSpacing.bubbleRadius, style: .continuous)
                .fill(colors.surface)
        case .system:
            RoundedRectangle(cornerRadius: VaizorSpacing.bubbleRadius, style: .continuous)
                .fill(colors.systemBubble)
        case .tool:
            RoundedRectangle(cornerRadius: VaizorSpacing.bubbleRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [colors.toolBackground, colors.toolBackground.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    @ViewBuilder
    private var bubbleBorderOverlay: some View {
        // Tahoe-style: Clean, minimal borders with subtle hover states
        switch message.role {
        case .user:
            ZStack {
                // Base border - subtle accent tint
                RoundedRectangle(cornerRadius: VaizorSpacing.bubbleRadius, style: .continuous)
                    .stroke(colors.userBubbleBorder, lineWidth: 1)
                // Hover glow - refined
                if isHovered {
                    RoundedRectangle(cornerRadius: VaizorSpacing.bubbleRadius, style: .continuous)
                        .stroke(colors.accent.opacity(0.5), lineWidth: 1.5)
                }
            }
        case .assistant:
            ZStack {
                // Subtle border
                RoundedRectangle(cornerRadius: VaizorSpacing.bubbleRadius, style: .continuous)
                    .stroke(colors.border, lineWidth: 1)
                // Hover state
                if isHovered {
                    RoundedRectangle(cornerRadius: VaizorSpacing.bubbleRadius, style: .continuous)
                        .stroke(colors.accent.opacity(0.35), lineWidth: 1)
                }
            }
        case .system:
            RoundedRectangle(cornerRadius: VaizorSpacing.bubbleRadius, style: .continuous)
                .stroke(colors.border, lineWidth: 0.5)
        case .tool:
            RoundedRectangle(cornerRadius: VaizorSpacing.bubbleRadius, style: .continuous)
                .stroke(colors.toolAccent.opacity(0.30), lineWidth: 1)
        }
    }

    private var shadowColor: Color {
        // Tahoe-style: Very subtle shadows, slightly more visible on hover
        switch message.role {
        case .user:
            return isHovered ? colors.accent.opacity(0.15) : colors.shadowLight
        case .assistant:
            return isHovered ? colors.shadowMedium : colors.shadowLight
        case .system:
            return .clear
        case .tool:
            return colors.shadowLight.opacity(0.5)
        }
    }

    private var shadowRadius: CGFloat {
        // Tahoe-style: Softer, more diffuse shadows
        switch message.role {
        case .user:
            return isHovered ? 12 : 6
        case .assistant:
            return isHovered ? 10 : 4
        case .system:
            return 0
        case .tool:
            return 3
        }
    }

    private var shadowY: CGFloat {
        let base: CGFloat = isHovered ? 4 : 2
        return colorScheme == .light ? base * 1.2 : base
    }

    private var accessibilityMessageLabel: String {
        let roleLabel: String
        switch message.role {
        case .user:
            roleLabel = "You said"
        case .assistant:
            roleLabel = "Assistant said"
        case .system:
            roleLabel = "System message"
        case .tool:
            roleLabel = "Tool result"
        }
        return "\(roleLabel): \(message.content)"
    }
    
    @ViewBuilder
    private var markdownContentView: some View {
        Markdown(message.content)
            .markdownTextStyle(\.text) {
                ForegroundColor(message.role == .user ? Color(hex: "eeeeee") : Color(nsColor: .textColor))
                FontSize(15) // VaizorTypography.bodyLarge equivalent
            }
            .markdownTextStyle(\.code) {
                FontFamilyVariant(.monospaced)
                FontSize(13) // VaizorTypography.code equivalent
                ForegroundColor(Color(hex: "00976d"))
                BackgroundColor(Color(hex: "00976d").opacity(0.12))
            }
            .markdownBlockStyle(\.codeBlock) { configuration in
                CodeBlockView(
                    language: configuration.language,
                    codeContent: configuration.content,
                    codeLabel: configuration.label,
                    messageId: message.id,
                    conversationId: message.conversationId
                )
            }
            .markdownBlockStyle(\.blockquote) { configuration in
                configuration.label
                    .padding(.leading, VaizorSpacing.sm)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(ThemeColors.info.opacity(0.5))
                            .frame(width: VaizorSpacing.xxs)
                    }
            }
            .markdownBlockStyle(\.table) { configuration in
                configuration.label
                    .padding(VaizorSpacing.xs)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .cornerRadius(VaizorSpacing.radiusMd)
                    .overlay(
                        RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd)
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

    // MARK: - Editing Methods

    private func startEditing() {
        editText = message.content
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = true
        }
        // Focus the text editor after a brief delay to allow the view to appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isEditFocused = true
        }
    }

    private func cancelEditing() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
        editText = ""
        isEditFocused = false
    }

    private func saveEdit() {
        let trimmedText = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        // Only save if the text actually changed
        if trimmedText != message.content {
            onEdit?(trimmedText)
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
        editText = ""
        isEditFocused = false
    }

}

// Code block view with copy button, execution, and artifact preview
struct CodeBlockView<CodeLabel: View>: View {
    let language: String?
    let codeContent: String
    let codeLabel: CodeLabel
    let messageId: UUID
    let conversationId: UUID

    @State private var isHovered = false
    @State private var showCopiedFeedback = false
    @State private var copyButtonScale: CGFloat = 1.0
    @State private var showExecution = false
    @State private var showArtifactPreview = false
    @State private var isArtifactExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // Adaptive colors helper
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    private var detectedLanguage: CodeLanguage? {
        detectCodeLanguage(language)
    }

    private var detectedArtifact: Artifact? {
        guard !codeContent.isEmpty else { return nil }
        return ArtifactDetector.detectArtifact(code: codeContent, language: language)
    }

    // Language display name with icon
    private var languageDisplay: (name: String, icon: String) {
        guard let lang = language?.lowercased() else {
            return ("code", "chevron.left.forwardslash.chevron.right")
        }

        switch lang {
        case "python", "py":
            return ("Python", "circle.hexagonpath.fill")
        case "javascript", "js":
            return ("JavaScript", "curlybraces")
        case "typescript", "ts":
            return ("TypeScript", "curlybraces")
        case "swift":
            return ("Swift", "swift")
        case "html", "htm":
            return ("HTML", "chevron.left.forwardslash.chevron.right")
        case "css", "scss", "sass":
            return ("CSS", "paintbrush.fill")
        case "json":
            return ("JSON", "doc.text")
        case "bash", "sh", "shell", "zsh":
            return ("Shell", "terminal.fill")
        case "sql":
            return ("SQL", "cylinder.fill")
        case "rust", "rs":
            return ("Rust", "gearshape.2.fill")
        case "go", "golang":
            return ("Go", "forward.fill")
        case "java":
            return ("Java", "cup.and.saucer.fill")
        case "kotlin", "kt":
            return ("Kotlin", "k.circle.fill")
        case "ruby", "rb":
            return ("Ruby", "diamond.fill")
        case "php":
            return ("PHP", "p.circle.fill")
        case "c":
            return ("C", "c.circle.fill")
        case "cpp", "c++":
            return ("C++", "plus.circle.fill")
        case "csharp", "c#", "cs":
            return ("C#", "number.circle.fill")
        case "react", "jsx", "tsx":
            return ("React", "atom")
        case "vue":
            return ("Vue", "v.circle.fill")
        case "yaml", "yml":
            return ("YAML", "list.bullet.rectangle")
        case "xml":
            return ("XML", "chevron.left.forwardslash.chevron.right")
        case "markdown", "md":
            return ("Markdown", "doc.richtext")
        default:
            return (lang.capitalized, "chevron.left.forwardslash.chevron.right")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Artifact inline preview (if detected)
            if let artifact = detectedArtifact {
                artifactPreviewSection(artifact)
            } else {
                // Standard code block
                standardCodeBlock
            }
        }
        .cornerRadius(VaizorSpacing.radiusMd + 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .sheet(isPresented: $showArtifactPreview) {
            if let artifact = detectedArtifact {
                ArtifactView(artifact: artifact) {
                    showArtifactPreview = false
                }
                .frame(minWidth: 700, minHeight: 500)
            }
        }
        .sheet(isPresented: $showExecution) {
            if let codeLang = detectedLanguage, codeLang.isExecutable {
                CodeExecutionView(
                    code: codeContent,
                    language: codeLang,
                    conversationId: conversationId
                )
                .frame(minWidth: 600, minHeight: 500)
            }
        }
    }

    @ViewBuilder
    private func artifactPreviewSection(_ artifact: Artifact) -> some View {
        // Compact artifact card - clicking opens in side panel
        Button {
            // Post notification to open artifact in side panel
            NotificationCenter.default.post(
                name: .openArtifactInPanel,
                object: artifact
            )
        } label: {
            HStack(spacing: VaizorSpacing.xs + 2) {
                // Artifact icon
                ZStack {
                    RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: VaizorSpacing.xl, height: VaizorSpacing.xl)

                    Image(systemName: artifact.type.icon)
                        .font(VaizorTypography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: VaizorSpacing.xxxs) {
                    Text(artifact.title)
                        .font(VaizorTypography.bodySmall)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(artifact.type.displayName)
                        .font(VaizorTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Action buttons (stop propagation)
                HStack(spacing: VaizorSpacing.xxs + 2) {
                    // Copy button
                    Button {
                        copyCode()
                    } label: {
                        Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(VaizorTypography.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(showCopiedFeedback ? .green : .secondary)
                            .padding(VaizorSpacing.xxs + 2)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(VaizorSpacing.radiusSm)
                    }
                    .buttonStyle(.plain)
                    .help("Copy code")

                    // Open arrow
                    Image(systemName: "chevron.right")
                        .font(VaizorTypography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(VaizorSpacing.sm)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(VaizorSpacing.radiusMd + 2)
        }
        .buttonStyle(.plain)
        .help("Click to open in preview panel")
    }

    private var standardCodeBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Code block header with language badge - adapts to color scheme
            HStack(spacing: VaizorSpacing.xs) {
                // Language badge with icon
                HStack(spacing: VaizorSpacing.xxs) {
                    Image(systemName: languageDisplay.icon)
                        .font(VaizorTypography.tiny)
                        .foregroundStyle(colors.accent)
                    Text(languageDisplay.name)
                        .font(VaizorTypography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(colors.textSecondary)
                }
                .padding(.horizontal, VaizorSpacing.xs)
                .padding(.vertical, VaizorSpacing.xxs)
                .background(colors.accentBackground)
                .cornerRadius(VaizorSpacing.radiusSm)

                Spacer()

                if isHovered && !codeContent.isEmpty {
                    HStack(spacing: VaizorSpacing.xxs + 2) {
                        // Animated copy button with checkmark feedback
                        Button {
                            copyCode()
                        } label: {
                            HStack(spacing: VaizorSpacing.xxs) {
                                Image(systemName: showCopiedFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                                    .font(VaizorTypography.label)
                                    .foregroundStyle(showCopiedFeedback ? colors.success : colors.textSecondary)
                                    .contentTransition(.symbolEffect(.replace))
                                Text(showCopiedFeedback ? "Copied!" : "Copy")
                                    .font(VaizorTypography.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(showCopiedFeedback ? colors.success : colors.textSecondary)
                            }
                            .padding(.horizontal, VaizorSpacing.xs)
                            .padding(.vertical, VaizorSpacing.xxs)
                            .background(showCopiedFeedback ? colors.successBackground : colors.surface)
                            .cornerRadius(VaizorSpacing.radiusSm)
                            .scaleEffect(copyButtonScale)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Copy code to clipboard")

                        // Run button for executable languages
                        if let lang = detectedLanguage, lang.isExecutable {
                            Button {
                                showExecution = true
                            } label: {
                                HStack(spacing: VaizorSpacing.xxs) {
                                    Image(systemName: "play.fill")
                                        .font(VaizorTypography.tiny)
                                    Text("Run")
                                        .font(VaizorTypography.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, VaizorSpacing.xs)
                                .padding(.vertical, VaizorSpacing.xxs)
                                .background(colors.successBackground)
                                .foregroundStyle(colors.success)
                                .cornerRadius(VaizorSpacing.radiusSm)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Run code")
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.horizontal, VaizorSpacing.xs + 2)
            .padding(.vertical, VaizorSpacing.xs)
            .background(colors.codeBlockHeaderBackground)

            // Code content with syntax highlighting
            codeLabel
                .padding(VaizorSpacing.sm)
                .background(colors.codeBlockBackground)
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
        } else if lang.contains("html") || lang == "htm" {
            return .html
        } else if lang.contains("css") || lang == "scss" || lang == "sass" {
            return .css
        } else if lang.contains("react") || lang.contains("jsx") || lang.contains("tsx") {
            return .react
        }

        return nil
    }
    
    private func copyCode() {
        guard !codeContent.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(codeContent, forType: .string)

        // Animated feedback with scale bounce
        if reduceMotion {
            showCopiedFeedback = true
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showCopiedFeedback = true
                copyButtonScale = 1.1
            }

            // Bounce back
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    copyButtonScale = 1.0
                }
            }
        }

        // Reset feedback after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if reduceMotion {
                    showCopiedFeedback = false
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showCopiedFeedback = false
                    }
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
            .font(VaizorTypography.tiny)
            .foregroundStyle(.secondary)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Mention References Display

/// Displays mention references attached to a message
struct MessageMentionReferencesView: View {
    let references: [MentionReference]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VaizorSpacing.xxs + 2) {
                ForEach(references) { ref in
                    MentionReferenceChip(reference: ref)
                }
            }
        }
        .padding(.bottom, VaizorSpacing.xxs)
    }
}

/// Individual chip for a mention reference
struct MentionReferenceChip: View {
    let reference: MentionReference
    @State private var isHovered = false

    private var chipColor: Color {
        Color(hex: reference.type.color)
    }

    var body: some View {
        Button {
            openReference()
        } label: {
            HStack(spacing: VaizorSpacing.xxs) {
                Image(systemName: MentionableItem.iconForPath(reference.value, type: reference.type))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(chipColor)

                Text(reference.displayName)
                    .font(VaizorTypography.tiny)
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(1)

                if let tokens = reference.tokenCount, tokens > 0 {
                    Text("~\(tokens)")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, VaizorSpacing.xxs + 2)
            .padding(.vertical, VaizorSpacing.xxxs + 1)
            .background(
                Capsule()
                    .fill(chipColor.opacity(isHovered ? 0.18 : 0.1))
            )
            .overlay(
                Capsule()
                    .stroke(chipColor.opacity(isHovered ? 0.35 : 0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .help("\(reference.type.displayName): \(reference.value)")
    }

    private func openReference() {
        switch reference.type {
        case .file:
            let expandedPath = (reference.value as NSString).expandingTildeInPath
            NSWorkspace.shared.selectFile(expandedPath, inFileViewerRootedAtPath: "")
        case .folder:
            let expandedPath = (reference.value as NSString).expandingTildeInPath
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: expandedPath)
        case .url:
            if let url = URL(string: reference.value) {
                NSWorkspace.shared.open(url)
            }
        case .project:
            let expandedPath = (reference.value as NSString).expandingTildeInPath
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: expandedPath)
        }
    }
}
