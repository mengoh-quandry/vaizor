import SwiftUI
import MarkdownUI

struct ChatView: View {
    let conversationId: UUID
    @ObservedObject var conversationManager: ConversationManager
    @EnvironmentObject var container: DependencyContainer
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.colorScheme) private var colorScheme

    // Adaptive colors helper
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }
    @State private var messageText: String = ""
    @State private var selectedModel: String = ""
    @State private var showSlashCommands: Bool = false
    @State private var slashCommandTimer: Task<Void, Never>?
    @State private var showWhiteboard: Bool = false
    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""
    @AppStorage("chatFontZoom") private var chatFontZoom: Double = 1.0
    @AppStorage("chatInputFontZoom") private var chatInputFontZoom: Double = 1.0
    @AppStorage("enablePromptEnhancement") private var enablePromptEnhancement: Bool = true
    @AppStorage("system_prompt_prefix") private var systemPromptPrefix: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    @StateObject private var scrollState = ScrollStateManager()
    @State private var showCommandPalette: Bool = false
    @State private var editingMessageId: UUID? = nil
    @State private var editingMessageText: String = ""
    @State private var droppedFiles: [URL] = []
    @State private var isDraggingOver: Bool = false

    // Mention states
    @State private var activeMentions: [Mention] = []
    @State private var showMentionSuggestions: Bool = false
    @State private var mentionSuggestions: [MentionableItem] = []
    @State private var selectedMentionIndex: Int = 0
    @State private var currentMentionType: MentionType? = nil
    @State private var mentionSearchText: String = ""
    @State private var mentionContext: MentionContext? = nil
    @ObservedObject private var mentionService = MentionService.shared

    // New feature states
    @State private var showTemplates: Bool = false
    @State private var showImporter: Bool = false
    @State private var showCostDetails: Bool = false
    @State private var showArtifactPanel: Bool = false
    @State private var showBrowserPanel: Bool = false
    @ObservedObject private var browserService = BrowserService.shared

    // Virtualization state
    @State private var visibleMessageRange: Range<Int> = 0..<50
    @State private var messageBufferSize: Int = 10 // Messages above/below viewport

    // Keyboard navigation state
    @State private var focusedMessageIndex: Int? = nil

    init(conversationId: UUID, conversationManager: ConversationManager) {
        self.conversationId = conversationId
        self.conversationManager = conversationManager
        // Note: container will be injected via @EnvironmentObject
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversationId: conversationId,
            conversationRepository: conversationManager.conversationRepository,
            container: nil // Will be set in onAppear
        ))
    }

    private var isInputActive: Bool {
        !messageText.isEmpty || viewModel.isStreaming
    }

    private var inputBorderColor: Color {
        isInputFocused ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor)
    }

    private func inputBorderOverlay() -> some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(inputBorderColor, lineWidth: isInputFocused ? 1.5 : 0.5)
    }

    // Computed properties for virtualization (extracted from ViewBuilder)
    private var messageIndices: (start: Int, end: Int, total: Int) {
        let total = viewModel.messages.count
        let start = max(0, visibleMessageRange.lowerBound - messageBufferSize)
        let end = min(total, visibleMessageRange.upperBound + messageBufferSize)
        return (start, end, total)
    }

    private var visibleMessages: ArraySlice<Message> {
        let indices = messageIndices
        guard indices.start < indices.end, indices.end <= viewModel.messages.count else {
            return []
        }
        return viewModel.messages[indices.start..<indices.end]
    }

    @ViewBuilder
    private func messagesList(proxy: ScrollViewProxy) -> some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollReader in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        loadingIndicatorView
                        loadMoreTriggerView
                        topSpacerView
                        messagesForEachView(maxWidth: computeMaxWidth(for: geometry.size.width))
                        bottomSpacerView
                        streamingView
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    scrollProxy = scrollReader
                }
            }
        }
    }

    private func computeMaxWidth(for width: CGFloat) -> CGFloat {
        min(width - 32, max(400, width * 0.88))
    }

    @ViewBuilder
    private var loadingIndicatorView: some View {
        if viewModel.isLoadingMore {
            VStack(spacing: 12) {
                // Skeleton messages for loading state with stagger animation
                MessageSkeleton(isUser: true, animationIndex: 0)
                MessageSkeleton(isUser: false, animationIndex: 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .id("loading-more")
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .accessibilityLabel("Loading more messages")
        }
    }

    @ViewBuilder
    private var loadMoreTriggerView: some View {
        Color.clear
            .frame(height: 1)
            .id("load-more-trigger")
            .onAppear {
                if viewModel.hasMoreMessages && !viewModel.isLoadingMore {
                    Task { await viewModel.loadMoreMessages() }
                }
            }
    }

    @ViewBuilder
    private var topSpacerView: some View {
        let indices = messageIndices
        if indices.start > 0 {
            Color.clear
                .frame(height: CGFloat(indices.start) * 80)
                .id("spacer-top")
        }
    }

    @ViewBuilder
    private var bottomSpacerView: some View {
        let indices = messageIndices
        if indices.end < indices.total {
            Color.clear
                .frame(height: CGFloat(indices.total - indices.end) * 80)
                .id("spacer-bottom")
        }
    }

    @ViewBuilder
    private func messagesForEachView(maxWidth: CGFloat) -> some View {
        let indices = messageIndices
        ForEach(Array(visibleMessages.enumerated()), id: \.element.id) { offset, message in
            messageRowView(message: message, actualIndex: indices.start + offset, animationIndex: offset, maxWidth: maxWidth)
        }
    }

    @ViewBuilder
    private func messageRowView(message: Message, actualIndex: Int, animationIndex: Int, maxWidth: CGFloat) -> some View {
        Group {
            if editingMessageId == message.id && message.role == .user {
                EditableMessageView(
                    message: message,
                    text: $editingMessageText,
                    onSave: { saveEditedMessage(messageId: message.id, newText: editingMessageText) },
                    onCancel: { editingMessageId = nil; editingMessageText = "" }
                )
            } else {
                messageContentView(message: message, animationIndex: animationIndex)
            }
        }
        .id(message.id)
        .frame(maxWidth: maxWidth, alignment: message.role == .user ? .trailing : .leading)
        .onAppear { updateVisibleRange(actualIndex) }
    }

    @ViewBuilder
    private func messageContentView(message: Message, animationIndex: Int = 0) -> some View {
        MessageBubbleView(
            message: message,
            provider: container.currentProvider,
            isPromptEnhanced: enablePromptEnhancement && message.role == .user,
            onCopy: { copyMessageToClipboard(message) },
            onEdit: message.role == .user ? { startEditingMessage(message) } : nil,
            onDelete: { deleteMessageAndResponse(message) },
            onRegenerate: message.role == .assistant ? { regenerateResponse(for: message) } : nil,
            onRegenerateDifferent: message.role == .assistant ? { regenerateWithDifferentModel(for: message) } : nil,
            onScrollToTop: message.role == .assistant ? { scrollToMessage(message) } : nil,
            animationIndex: animationIndex,
            shouldAnimateAppear: animationIndex < 10 // Only animate first 10 messages
        )
    }

    @ViewBuilder
    private var streamingView: some View {
        if viewModel.isStreaming {
            VStack(alignment: .leading, spacing: 8) {
                // Show context enhancement indicator if applicable
                if viewModel.contextWasEnhanced {
                    ContextEnhancementIndicator(details: viewModel.contextEnhancementDetails)
                        .padding(.horizontal, 60)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if viewModel.currentStreamingText.isEmpty {
                    ThinkingIndicator(status: viewModel.thinkingStatus)
                        .id("thinking")
                } else {
                    StreamingMessageView(text: viewModel.currentStreamingText)
                        .id("streaming")
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.contextWasEnhanced)
        }
    }

    // Helper functions for cleaner callbacks
    private func copyMessageToClipboard(_ message: Message) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.content, forType: .string)
    }

    private func startEditingMessage(_ message: Message) {
        editingMessageId = message.id
        editingMessageText = message.content
    }

    private func scrollToMessage(_ message: Message) {
        if let proxy = scrollProxy {
            withAnimation(VaizorAnimations.smoothScroll) {
                proxy.scrollTo(message.id, anchor: .top)
            }
            scrollState.autoScrollEnabled = false
        }
    }
    
    private func updateVisibleRange(_ index: Int) {
        // Update visible range based on which messages are visible
        // This is a simplified version - in production, use proper scroll position tracking
        let buffer = messageBufferSize
        let newLower = max(0, index - buffer)
        let newUpper = min(viewModel.messages.count, index + buffer + 50)

        if newLower != visibleMessageRange.lowerBound || newUpper != visibleMessageRange.upperBound {
            visibleMessageRange = newLower..<newUpper
        }
    }

    private func navigateMessages(direction: Int) {
        let messageCount = viewModel.messages.count
        guard messageCount > 0 else { return }

        let currentIndex = focusedMessageIndex ?? (direction > 0 ? -1 : messageCount)
        let newIndex = max(0, min(messageCount - 1, currentIndex + direction))

        guard newIndex != focusedMessageIndex else { return }

        focusedMessageIndex = newIndex
        let message = viewModel.messages[newIndex]

        if let proxy = scrollProxy {
            withAnimation(VaizorAnimations.smoothScroll) {
                proxy.scrollTo(message.id, anchor: direction > 0 ? .bottom : .top)
            }
        }
    }

    @ViewBuilder
    private func inputRow() -> some View {
        // Unified capsule input: text field and send button in one seamless container
        HStack(spacing: 0) {
            TextField(
                viewModel.isParallelMode ? "Ask multiple models..." : "Ask anything, type / for commands, @ for context",
                text: $messageText,
                axis: .vertical
            )
                .textFieldStyle(.plain)
                .font(VaizorTypography.body)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1...6)
                .disabled(viewModel.isStreaming)
                .focused($isInputFocused)
                .padding(.leading, VaizorSpacing.md)
                .padding(.vertical, VaizorSpacing.xs + 2)
                .onHover { isHovering in
                    if isHovering {
                        isInputFocused = true
                    }
                }
                .onPasteCommand(of: [.image]) { providers in
                    handlePastedImages(providers: providers)
                }
                .onChange(of: messageText) { _, newValue in
                    // Cancel any existing timer
                    slashCommandTimer?.cancel()

                    // Check for slash commands
                    if newValue.hasPrefix("/") {
                        showMentionSuggestions = false
                        // Show menu immediately if "/" is typed
                        if newValue == "/" {
                            showSlashCommands = true
                            // Start timer: if no character follows for 1 second, keep showing menu
                            slashCommandTimer = Task {
                                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                                if !Task.isCancelled && messageText == "/" {
                                    await MainActor.run {
                                        showSlashCommands = true
                                    }
                                }
                            }
                        } else {
                            // User is typing after "/", show menu with filtering
                            showSlashCommands = true
                        }
                    } else {
                        // No "/" prefix, hide menu
                        showSlashCommands = false

                        // Check for @-mentions
                        checkForMentionTrigger(in: newValue)
                    }
                }
                .onSubmit {
                    // Plain Enter: send message (unless mention suggestions are shown)
                    if showMentionSuggestions && !mentionSuggestions.isEmpty {
                        selectMention(at: selectedMentionIndex)
                    } else {
                        Task { await sendMessage() }
                    }
                }

            // Send button integrated into the capsule with gradient
            Button {
                if viewModel.isStreaming {
                    viewModel.stopStreaming()
                } else {
                    Task { await sendMessage() }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(sendButtonGradient)
                        .frame(width: VaizorSpacing.xl, height: VaizorSpacing.xl)
                        .shadow(color: sendButtonShadow, radius: 4, y: 2)

                    Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up")
                        .font(VaizorTypography.body)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isStreaming && messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.trailing, VaizorSpacing.xxs + 2)
            .padding(.vertical, VaizorSpacing.xxs + 2)
        }
        .background(
            Capsule()
                .fill(colors.inputBackground)
        )
        // Inner shadow for recessed effect (subtle in light mode)
        .overlay(
            colorScheme == .dark ?
            Capsule()
                .stroke(ThemeColors.innerShadow, lineWidth: 1)
                .blur(radius: 1)
                .mask(Capsule())
            : nil
        )
        // Focus glow ring
        .overlay(
            Capsule()
                .stroke(isInputFocused ? colors.accent : colors.borderSubtle, lineWidth: isInputFocused ? 1.5 : 0.5)
        )
        .shadow(color: isInputFocused ? (colorScheme == .light ? colors.accent.opacity(0.25) : ThemeColors.focusGlow) : .clear, radius: colorScheme == .light ? 6 : 8, y: 0)
        .animation(.easeInOut(duration: 0.15), value: isInputFocused)
    }

    private var sendButtonGradient: LinearGradient {
        if viewModel.isStreaming {
            return LinearGradient(colors: [Color(hex: "e53935"), Color(hex: "c62828")], startPoint: .top, endPoint: .bottom)
        } else if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return LinearGradient(colors: [ThemeColors.disabledText], startPoint: .top, endPoint: .bottom)
        } else {
            return ThemeColors.accentGradient
        }
    }

    private var sendButtonShadow: Color {
        if viewModel.isStreaming {
            return Color(hex: "e53935").opacity(0.3)
        } else if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .clear
        } else {
            return ThemeColors.accentGlow
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.error {
            ErrorCard(
                error: error,
                onDismiss: { viewModel.error = nil },
                onRetry: {
                    viewModel.error = nil
                    // Retry last action if possible
                },
                onOpenSettings: {
                    viewModel.error = nil
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
            )
            .padding(.horizontal, VaizorSpacing.md)
            .padding(.vertical, VaizorSpacing.xs)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            messagesList(proxy: proxy)
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if scrollState.autoScrollEnabled, let lastMessage = viewModel.messages.last {
                        withAnimation(VaizorAnimations.smoothScroll) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.currentStreamingText) { _, _ in
                    if scrollState.autoScrollEnabled {
                        withAnimation(VaizorAnimations.smoothScroll) {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { _ in
                    if let firstMessage = viewModel.messages.first {
                        withAnimation(VaizorAnimations.smoothScroll) {
                            proxy.scrollTo(firstMessage.id, anchor: .top)
                        }
                        scrollState.autoScrollEnabled = false
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .scrollToBottom)) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(VaizorAnimations.smoothScroll) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                        scrollState.autoScrollEnabled = true
                    }
                }
        }
    }

    @ViewBuilder
    private var inputBar: some View {
        VStack(spacing: 0) {
            // Mention suggestions popup
            if showMentionSuggestions && !mentionSuggestions.isEmpty {
                MentionSuggestionView(
                    suggestions: mentionSuggestions,
                    selectedIndex: selectedMentionIndex,
                    onSelect: { item in
                        insertMention(item)
                    },
                    onDismiss: {
                        showMentionSuggestions = false
                    }
                )
                .padding(.horizontal, VaizorSpacing.md)
                .padding(.bottom, VaizorSpacing.xs)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Slash command suggestions
            if showSlashCommands && messageText.hasPrefix("/") {
                SlashCommandView(
                    searchText: messageText.count > 1 ? String(messageText.dropFirst()) : "",
                    onSelect: { command in
                        handleSlashCommand(command)
                    },
                    conversationManager: conversationManager
                )
                .environmentObject(container)
                .padding(.horizontal, VaizorSpacing.md)
                .padding(.bottom, VaizorSpacing.xs)
            }

            // Active mentions pills
            if !activeMentions.isEmpty {
                VStack(spacing: VaizorSpacing.xxs) {
                    MentionPillsView(
                        mentions: activeMentions,
                        onRemove: { mention in
                            removeMention(mention)
                        },
                        onTap: { mention in
                            // Show mention details (could open file, etc.)
                            showMentionDetails(mention)
                        }
                    )

                    // Token count warning if context is large
                    if let context = mentionContext, context.totalTokens > 5000 {
                        MentionContextWarningView(
                            totalTokens: context.totalTokens,
                            warnings: context.warnings
                        )
                    }
                }
                .padding(.horizontal, VaizorSpacing.md)
                .padding(.top, VaizorSpacing.xs)
            }

            // Dropped files preview
            if !droppedFiles.isEmpty {
                DroppedFilesView(
                    files: droppedFiles,
                    onClear: { droppedFiles.removeAll() },
                    onRemoveFile: { file in
                        droppedFiles.removeAll { $0 == file }
                    }
                )
                .padding(.horizontal, VaizorSpacing.md)
                .padding(.top, VaizorSpacing.xs)
            }

            // Top row: Icons and model selector (with more vertical spacing)
            topInputRow
                .padding(.horizontal, VaizorSpacing.md)
                .padding(.top, VaizorSpacing.sm)
                .padding(.bottom, VaizorSpacing.xs)

            // Bottom row: Unified capsule input
            inputRow()
                .padding(.horizontal, VaizorSpacing.sm)
                .padding(.bottom, VaizorSpacing.sm)
                .overlay(
                    Group {
                        if isDraggingOver {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.accentColor, lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color.accentColor.opacity(0.05))
                                )
                                .padding(.horizontal, 12)
                        }
                    }
                )
                .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
                    handleDroppedFiles(providers: providers)
                }
        }
        .background(
            ZStack {
                // Base background (gradient in dark mode, solid in light)
                colors.surface
                // Subtle top border highlight (dark mode only)
                if colorScheme == .dark {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(ThemeColors.borderHighlight)
                            .frame(height: 0.5)
                        Spacer()
                    }
                } else {
                    // Light mode: subtle top border
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(colors.border)
                            .frame(height: 0.5)
                        Spacer()
                    }
                }
            }
        )
    }

    @ViewBuilder
    private var topInputRow: some View {
        HStack(spacing: 8) {
            // Left icons
            HStack(spacing: 6) {
                Button {
                    selectFiles()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Attach Files")
                .accessibilityLabel("Attach files")

                Button {
                    NotificationCenter.default.post(
                        name: .showUnderConstructionToast,
                        object: "Add Image"
                    )
                } label: {
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Add image")
                .accessibilityLabel("Add image")

                Button {
                    showWhiteboard.toggle()
                } label: {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 18))
                        .foregroundStyle(showWhiteboard ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .help("Open whiteboard")
                .accessibilityLabel(showWhiteboard ? "Close whiteboard" : "Open whiteboard")

                // Browser toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBrowserPanel.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 18))
                            .foregroundStyle(showBrowserPanel ? ThemeColors.accent : .secondary)

                        if browserService.isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("AI Browser")
                .accessibilityLabel(showBrowserPanel ? "Close browser" : "Open AI browser")

                // Built-in tools toggle
                BuiltInToolsButton()

                // MCP Servers indicator
                mcpServersMenu

                Divider()
                    .frame(height: 16)

                // Templates button
                Button {
                    showTemplates = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Browse templates")
                .accessibilityLabel("Browse project templates")

                // Import chat button
                Button {
                    showImporter = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Import chat")
                .accessibilityLabel("Import chat history")
            }

            Spacer()

            // Right icons
            HStack(spacing: 6) {
                // Cost display
                CostDisplayView()
                    .onTapGesture {
                        showCostDetails = true
                    }
                    .help("Click to view cost details")
                    .accessibilityLabel("View cost details")

                // Prompt enhancement indicator
                if enablePromptEnhancement {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "00976d"))
                        .help("Prompt enhancement enabled")
                        .accessibilityLabel("Prompt enhancement is enabled")
                }

                // Parallel mode toggle
                parallelModeButton

                // Model selector - moved to right side
                ModelSelectorMenu(selectedModel: $selectedModel)
                    .layoutPriority(1)
                    .accessibilityLabel("Select AI model: \(selectedModel.isEmpty ? "default" : selectedModel)")

                Button {
                    NotificationCenter.default.post(
                        name: .showUnderConstructionToast,
                        object: "Voice Input"
                    )
                } label: {
                    Image(systemName: "mic")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Voice input")
                .accessibilityLabel("Voice input")
            }
        }
    }

    @ViewBuilder
    private var parallelModeButton: some View {
        Menu {
            Toggle("Enable Parallel Mode", isOn: $viewModel.isParallelMode)
                .toggleStyle(.checkbox)
            
            if viewModel.isParallelMode {
                Divider()
                
                Text("Select models to compare:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                
                ForEach(container.configuredProviders.filter { provider in
                    provider == .ollama || container.apiKeys[provider] != nil
                }, id: \.self) { provider in
                    Button {
                        if viewModel.selectedModels.contains(provider) {
                            viewModel.selectedModels.remove(provider)
                        } else {
                            viewModel.selectedModels.insert(provider)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.selectedModels.contains(provider) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(viewModel.selectedModels.contains(provider) ? Color(hex: "00976d") : .secondary)
                                .font(.system(size: 12))
                            
                            Text(provider.shortDisplayName)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                
                if viewModel.selectedModels.isEmpty {
                    Divider()
                    Text("Select at least one model")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isParallelMode ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                    .font(.system(size: 18))
                    .foregroundStyle(viewModel.isParallelMode ? Color(hex: "00976d") : .secondary)
                    .symbolEffect(.bounce, value: viewModel.isParallelMode)
                
                if viewModel.isParallelMode && !viewModel.selectedModels.isEmpty {
                    Text("\(viewModel.selectedModels.count)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(hex: "00976d"))
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .help(viewModel.isParallelMode ? "Parallel mode: \(viewModel.selectedModels.count) models selected" : "Enable parallel mode")
    }
    
    @ViewBuilder
    private var mcpServersMenu: some View {
        Menu {
            if container.mcpManager.availableServers.isEmpty {
                Text("No MCP servers configured")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(container.mcpManager.availableServers) { server in
                    let isEnabled = container.mcpManager.enabledServers.contains(server.id)
                    
                    Button {
                        Task { @MainActor in
                            if isEnabled {
                                container.mcpManager.stopServer(server)
                            } else {
                                do {
                                    try await container.mcpManager.startServer(server)
                                } catch {
                                    AppLogger.shared.logError(error, context: "Failed to start MCP server \(server.name) from chat view")
                                    // Error is stored in serverErrors and state is cleaned up automatically
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(isEnabled ? ThemeColors.success : ThemeColors.textMuted)
                                .frame(width: 6, height: 6)

                            Text(server.name)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "power")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isEnabled ? ThemeColors.accent : Color.secondary)
                        }
                        .frame(minWidth: 120)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                MCPIconManager.icon()
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .foregroundStyle(container.mcpManager.enabledServers.isEmpty ? Color.secondary : ThemeColors.accent)

                if !container.mcpManager.enabledServers.isEmpty {
                    Text("\(container.mcpManager.enabledServers.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .help("MCP Servers status")
    }

    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        let navTitle = conversationManager.conversations.first(where: { $0.id == conversationId })?.title ?? "Chat"
        
        return ZStack {
            // Main content
            mainContentView
            
            // Command Palette overlay
            if showCommandPalette {
                commandPaletteOverlay
            }
        }
        .navigationTitle(navTitle)
        .onAppear {
            AppLogger.shared.log("ChatView appeared for conversation \(conversationId)", level: .info)
            viewModel.setContainer(container)

            // Load conversation-specific model settings if available
            if let conversation = conversationManager.conversations.first(where: { $0.id == conversationId }) {
                if let convProvider = conversation.selectedProvider {
                    container.currentProvider = convProvider
                }
                if let convModel = conversation.selectedModel {
                    selectedModel = convModel
                }

                // Load project context if conversation belongs to a project
                if let projectId = conversation.projectId,
                   let project = container.projectManager.getProject(by: projectId) {
                    viewModel.setProjectContext(project.context, projectId: projectId)
                    AppLogger.shared.log("Loaded project context for project: \(project.name)", level: .info)
                }
            }

            viewModel.updateProvider(container.createLLMProvider())
            Task {
                await container.loadModelsForCurrentProvider()
                if selectedModel.isEmpty {
                    selectedModel = container.availableModels.first ?? container.currentProvider.defaultModels.first ?? ""
                }
            }
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
            // Auto-scroll to bottom on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let lastMessage = viewModel.messages.last, let proxy = scrollProxy {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
            // Initialize visible range (start from bottom, most recent messages)
            let messageCount = viewModel.messages.count
            visibleMessageRange = max(0, messageCount - 50)..<messageCount
            
            // Auto-scroll to bottom after initial load completes
            if viewModel.isLoadingInitial {
                // Wait for loading to complete
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    if let lastMessage = viewModel.messages.last, let proxy = scrollProxy {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .onDisappear {
            // Clean up any pending tasks to prevent memory leaks
            slashCommandTimer?.cancel()
            slashCommandTimer = nil
            scrollState.reset()
        }
        .onKeyPress { press in
            // Command+K to open palette
            if press.modifiers.contains(.command) && press.key.character == "k" {
                showCommandPalette = true
                return .handled
            }

            // Handle mention suggestion navigation when suggestions are shown
            if showMentionSuggestions && !mentionSuggestions.isEmpty {
                switch press.key {
                case .upArrow:
                    selectedMentionIndex = max(0, selectedMentionIndex - 1)
                    return .handled
                case .downArrow:
                    selectedMentionIndex = min(mentionSuggestions.count - 1, selectedMentionIndex + 1)
                    return .handled
                case .return:
                    selectMention(at: selectedMentionIndex)
                    return .handled
                case .escape:
                    showMentionSuggestions = false
                    return .handled
                case .tab:
                    selectMention(at: selectedMentionIndex)
                    return .handled
                default:
                    break
                }
            }

            // Arrow key navigation for messages (when not typing)
            if !isInputFocused {
                switch press.key {
                case .upArrow:
                    navigateMessages(direction: -1)
                    return .handled
                case .downArrow:
                    navigateMessages(direction: 1)
                    return .handled
                case .home:
                    // Jump to first message
                    if let firstMessage = viewModel.messages.first, let proxy = scrollProxy {
                        focusedMessageIndex = 0
                        withAnimation(VaizorAnimations.smoothScroll) {
                            proxy.scrollTo(firstMessage.id, anchor: .top)
                        }
                    }
                    return .handled
                case .end:
                    // Jump to last message
                    if let lastMessage = viewModel.messages.last, let proxy = scrollProxy {
                        focusedMessageIndex = viewModel.messages.count - 1
                        withAnimation(VaizorAnimations.smoothScroll) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                    return .handled
                default:
                    break
                }
            }

            return .ignored
        }
        .onReceive(NotificationCenter.default.publisher(for: .showUnderConstructionToast)) { notification in
            if let featureName = notification.object as? String {
                toastMessage = "\(featureName) is under construction"
                withAnimation {
                    showToast = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatFontZoomChanged)) { notification in
            if let newZoom = notification.object as? Double {
                withAnimation {
                    chatFontZoom = newZoom
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatInputFontZoomChanged)) { notification in
            if let newZoom = notification.object as? Double {
                withAnimation {
                    chatInputFontZoom = newZoom
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openArtifactInPanel)) { notification in
            if let artifact = notification.object as? Artifact {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.currentArtifact = artifact
                    showArtifactPanel = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleArtifactPanel)) { notification in
            if let isShown = notification.object as? Bool {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showArtifactPanel = isShown
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showArtifactPanel.toggle()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sendInitialMessage)) { notification in
            if let message = notification.object as? String {
                messageText = message
                Task {
                    await sendMessage()
                }
            }
        }
        .onChange(of: container.currentProvider) { _, newProvider in
            viewModel.updateProvider(container.createLLMProvider())
            if !newProvider.defaultModels.contains(selectedModel) {
                selectedModel = newProvider.defaultModels.first ?? ""
            }
        }
        .onChange(of: container.apiKeys) { _, _ in
            viewModel.updateProvider(container.createLLMProvider())
        }
        .sheet(isPresented: $showWhiteboard) {
            WhiteboardView(isPresented: $showWhiteboard)
        }
        .sheet(isPresented: $showTemplates) {
            ProjectTemplatePickerView { template in
                // Use the first starter prompt if available
                messageText = template.starterPrompts.first ?? ""
                showTemplates = false
            }
        }
        .sheet(isPresented: $showImporter) {
            ChatImportView()
        }
        .sheet(isPresented: $showCostDetails) {
            CostDetailsView()
        }
    }
    
    @ViewBuilder
    private var mainContentView: some View {
        HSplitView {
            // Left: Chat content
            chatContentView

            // Middle: Browser panel (when shown)
            if showBrowserPanel {
                BrowserView(
                    browserService: browserService,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showBrowserPanel = false
                        }
                    },
                    onSendToAI: { screenshot, content in
                        handleBrowserContentSentToAI(screenshot: screenshot, content: content)
                    }
                )
                .frame(minWidth: 400, idealWidth: 550, maxWidth: 900)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // Right: Artifact panel (when panel is shown)
            if showArtifactPanel {
                if let artifact = viewModel.currentArtifact {
                    ArtifactPanelView(artifact: artifact, onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showArtifactPanel = false
                        }
                    })
                    .id(artifact.id) // Force refresh when artifact changes
                    .frame(minWidth: 350, idealWidth: 450, maxWidth: 700)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    // Empty artifact panel placeholder
                    emptyArtifactPanel
                        .frame(minWidth: 350, idealWidth: 450, maxWidth: 700)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
    }

    /// Handle content sent from browser to AI for analysis
    private func handleBrowserContentSentToAI(screenshot: NSImage?, content: PageContent?) {
        var contextText = ""

        if let content = content {
            contextText = """
            I'm viewing a web page and would like your help analyzing it.

            **Page Title:** \(content.title)
            **URL:** \(content.url.absoluteString)

            **Page Content:**
            \(String(content.text.prefix(3000)))
            \(content.text.count > 3000 ? "\n...[truncated]" : "")

            """
        }

        if screenshot != nil {
            contextText += "\n\nI've also included a screenshot of the page."
            // Note: For vision models, the screenshot would be added as an attachment
            // This would require extending the message sending to support images
        }

        if contextText.isEmpty {
            contextText = "What's on this web page?"
        } else {
            contextText += "\n\nWhat can you tell me about this page?"
        }

        messageText = contextText
        isInputFocused = true
    }

    @ViewBuilder
    private var emptyArtifactPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "cube.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ThemeColors.accent)

                    Text("Artifacts")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ThemeColors.textPrimary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showArtifactPanel = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ThemeColors.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(ThemeColors.darkSurface)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ThemeColors.darkBase)

            Divider()
                .background(ThemeColors.darkBorder)

            // Empty state
            VStack(spacing: 20) {
                Spacer()

                // Animated illustration
                ArtifactEmptyStateIllustration()

                VStack(spacing: 8) {
                    Text("No artifacts yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeColors.textPrimary)

                    Text("Interactive content will appear here")
                        .font(.system(size: 13))
                        .foregroundStyle(ThemeColors.textSecondary)
                }

                // Examples
                VStack(spacing: 8) {
                    ArtifactExampleRow(icon: "chevron.left.forwardslash.chevron.right", text: "React components")
                    ArtifactExampleRow(icon: "chart.bar.fill", text: "Charts & visualizations")
                    ArtifactExampleRow(icon: "doc.richtext", text: "HTML previews")
                    ArtifactExampleRow(icon: "square.grid.3x3", text: "Interactive diagrams")
                }
                .padding(.top, 8)

                Text("Ask me to create something!")
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColors.accent)
                    .padding(.top, 8)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
        }
        .background(ThemeColors.darkBase)
    }

    @ViewBuilder
    private var chatContentView: some View {
        VStack(spacing: 0) {
            // Toast notification
            if showToast {
                ToastView(message: toastMessage, isPresented: $showToast)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            errorBanner

            // Show parallel comparison view if in parallel mode with responses
            if viewModel.isParallelMode && (!viewModel.parallelResponses.isEmpty || viewModel.isStreaming) {
                ModelComparisonView(
                    responses: viewModel.parallelResponses,
                    errors: viewModel.parallelErrors,
                    isStreaming: viewModel.isStreaming
                )
            } else if viewModel.messages.isEmpty && !viewModel.isStreaming && !viewModel.isLoadingInitial {
                // Empty conversation state
                emptyConversationView
            } else {
                messagesScrollView
                    .overlay(alignment: .bottomTrailing) {
                        scrollToBottomButton
                    }
            }

            Divider()

            inputBar
                .font(.system(size: 14 * chatInputFontZoom))
        }
    }

    @ViewBuilder
    private var emptyConversationView: some View {
        let conversation = conversationManager.conversations.first(where: { $0.id == conversationId })
        let title = conversation?.title ?? ""
        let modelName = selectedModel.isEmpty ? container.currentProvider.displayName : selectedModel

        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 40)

                // Animated illustration
                ChatEmptyStateIllustration()

                // Title and model info
                VStack(spacing: 10) {
                    Text(title.isEmpty ? "Start a Conversation" : title)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(ThemeColors.textPrimary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(ThemeColors.accent)
                            .frame(width: 6, height: 6)

                        Text("Using \(modelName)")
                            .font(.system(size: 13))
                            .foregroundStyle(ThemeColors.textSecondary)
                    }
                }

                // Helpful hints
                VStack(spacing: 10) {
                    ChatHintRow(
                        icon: "lightbulb.fill",
                        title: "Ask anything",
                        subtitle: "Questions, ideas, code help, writing assistance",
                        color: ThemeColors.warning
                    )
                    ChatHintRow(
                        icon: "at",
                        title: "Mention files with @",
                        subtitle: "@filename.swift to include code context",
                        color: ThemeColors.info
                    )
                    ChatHintRow(
                        icon: "slash.circle",
                        title: "Use / for commands",
                        subtitle: "/help, /clear, /template, and more",
                        color: ThemeColors.codeAccent
                    )
                    ChatHintRow(
                        icon: "paperclip",
                        title: "Attach files",
                        subtitle: "Drop files or click + to add context",
                        color: ThemeColors.accent
                    )
                }
                .frame(maxWidth: 400)

                // Keyboard shortcuts
                HStack(spacing: 20) {
                    EmptyStateKeyboardHint(keys: ["Return"], label: "Send message")
                    EmptyStateKeyboardHint(keys: ["K"], label: "Commands", hasCommand: true)
                    EmptyStateKeyboardHint(keys: ["N"], label: "New chat", hasCommand: true)
                }
                .padding(.top, 8)

                Spacer()
                    .frame(height: 80)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
        }
        .background(ThemeColors.darkBase)
    }

    @ViewBuilder
    private var scrollToBottomButton: some View {
        SmartScrollButton(scrollState: scrollState) {
            if let lastMessage = viewModel.messages.last, let proxy = scrollProxy {
                withAnimation(VaizorAnimations.smoothScroll) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 50)
        .accessibilityLabel("Scroll to bottom")
        .accessibilityHint("Double tap to scroll to the most recent message")
    }
    
    @ViewBuilder
    private var commandPaletteOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture {
                showCommandPalette = false
            }
        
        CommandPaletteView(isPresented: $showCommandPalette)
            .environmentObject(container)
            .transition(.scale.combined(with: .opacity))
    }

    private func handleSlashCommand(_ command: SlashCommand) {
        // Cancel timer and hide menu
        slashCommandTimer?.cancel()
        showSlashCommands = false

        switch command.name {
        case "whiteboard":
            showWhiteboard = true
            messageText = ""
        case "clear":
            // Clear conversation
            messageText = ""
        case "template":
            // Load template
            if let template = conversationManager.templates.first(where: { $0.name.lowercased() == command.value?.lowercased() }) {
                messageText = template.prompt
                if let systemPrompt = template.systemPrompt, !systemPrompt.isEmpty {
                    systemPromptPrefix = systemPrompt
                }
            } else {
                messageText = "/template "
            }
        default:
            // Handle MCP commands
            if command.name.hasPrefix("mcp-") {
                let serverName = String(command.name.dropFirst(4)).replacingOccurrences(of: "-", with: " ")
                if let server = container.mcpManager.availableServers.first(where: { 
                    $0.name.lowercased() == serverName 
                }) {
                    messageText = "/mcp \(server.name) "
                } else {
                    messageText = "/\(command.name) "
                }
            } else {
                messageText = "/\(command.name) "
            }
        }
    }

    private func handlePastedImages(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, error in
                    guard error == nil else { return }
                    
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            droppedFiles.append(url)
                        }
                    } else if let image = item as? NSImage,
                              let tiffData = image.tiffRepresentation,
                              let bitmapImage = NSBitmapImageRep(data: tiffData),
                              let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                        // Create temporary file for pasted image
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension("png")
                        
                        do {
                            try pngData.write(to: tempURL)
                            DispatchQueue.main.async {
                                droppedFiles.append(tempURL)
                            }
                        } catch {
                            Task { @MainActor in
                                AppLogger.shared.logError(error, context: "Failed to save pasted image")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Mention Handling

    private func checkForMentionTrigger(in text: String) {
        // Get cursor position (approximate - use end of text)
        let cursorPosition = text.count

        if let result = mentionService.detectIncompleteMention(in: text, cursorPosition: cursorPosition) {
            currentMentionType = result.type
            mentionSearchText = result.searchText

            // Generate suggestions asynchronously
            Task {
                let suggestions = await mentionService.generateSuggestions(
                    type: result.type,
                    searchText: result.searchText
                )

                await MainActor.run {
                    mentionSuggestions = suggestions
                    selectedMentionIndex = 0
                    showMentionSuggestions = !suggestions.isEmpty
                }
            }
        } else {
            showMentionSuggestions = false
            mentionSuggestions = []
        }
    }

    private func selectMention(at index: Int) {
        guard index >= 0 && index < mentionSuggestions.count else { return }
        let item = mentionSuggestions[index]
        insertMention(item)
    }

    private func insertMention(_ item: MentionableItem) {
        // If item is a type suggestion (no specific value), insert the prefix
        if item.value == item.type.prefix {
            // Replace incomplete mention with the type prefix
            replaceIncompleteMentionWith(item.type.prefix)
        } else {
            // Create a mention and add it to active mentions
            let mention = Mention(
                type: item.type,
                value: item.value,
                displayName: item.displayName
            )

            activeMentions.append(mention)

            // Remove the mention text from the input (replace with empty)
            replaceIncompleteMentionWith("")

            // Update mention context
            Task {
                await resolveMentionContext()
            }
        }

        showMentionSuggestions = false
        mentionSuggestions = []
    }

    private func replaceIncompleteMentionWith(_ replacement: String) {
        // Find and replace the incomplete mention in the text
        // Pattern: @type:search or just @search
        let patterns = [
            #"@file:[^\s]*$"#,
            #"@folder:[^\s]*$"#,
            #"@url:[^\s]*$"#,
            #"@project:[^\s]*$"#,
            #"@[^\s:]*$"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: messageText, options: [], range: NSRange(messageText.startIndex..., in: messageText)),
               let range = Range(match.range, in: messageText) {
                messageText = messageText.replacingCharacters(in: range, with: replacement)
                return
            }
        }
    }

    private func removeMention(_ mention: Mention) {
        activeMentions.removeAll { $0.id == mention.id }

        // Update mention context
        Task {
            await resolveMentionContext()
        }
    }

    private func showMentionDetails(_ mention: Mention) {
        // For files, could open in Finder or show content preview
        switch mention.type {
        case .file:
            let expandedPath = (mention.value as NSString).expandingTildeInPath
            NSWorkspace.shared.selectFile(expandedPath, inFileViewerRootedAtPath: "")
        case .folder:
            let expandedPath = (mention.value as NSString).expandingTildeInPath
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: expandedPath)
        case .url:
            if let url = URL(string: mention.value) {
                NSWorkspace.shared.open(url)
            }
        case .project:
            let expandedPath = (mention.value as NSString).expandingTildeInPath
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: expandedPath)
        }
    }

    private func resolveMentionContext() async {
        guard !activeMentions.isEmpty else {
            mentionContext = nil
            return
        }

        let context = await mentionService.resolveMentions(activeMentions)

        await MainActor.run {
            mentionContext = context
            // Update mentions with resolved content
            activeMentions = context.mentions
        }
    }

    // MARK: - File Handling

    private func handleDroppedFiles(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            droppedFiles.append(url)
                        }
                    } else if let url = item as? URL {
                        DispatchQueue.main.async {
                            droppedFiles.append(url)
                        }
                    }
                }
            }
        }
        return !providers.isEmpty
    }
    
    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !text.isEmpty || !droppedFiles.isEmpty || !activeMentions.isEmpty else { return }

        // Check API keys for parallel mode
        if viewModel.isParallelMode {
            for provider in viewModel.selectedModels {
                if let apiKeyError = missingAPIKeyError(for: provider) {
                    viewModel.error = apiKeyError
                    return
                }
            }
        } else {
            if let apiKeyError = missingAPIKeyError(for: container.currentProvider) {
                viewModel.error = apiKeyError
                return
            }
        }

        viewModel.error = nil

        let isFirstMessage = viewModel.messages.isEmpty

        // Resolve mentions if we have any
        var contextPrefix = ""
        var mentionReferences: [Mention] = []
        if !activeMentions.isEmpty {
            // Ensure mentions are resolved
            if mentionContext == nil {
                await resolveMentionContext()
            }

            if let context = mentionContext {
                contextPrefix = context.generateContextString()
                mentionReferences = context.mentions

                // Show warnings if any
                for warning in context.warnings {
                    AppLogger.shared.log("Mention warning: \(warning)", level: .warning)
                }
            }
        }

        // Process dropped files as attachments
        var attachments: [MessageAttachment] = []
        for fileURL in droppedFiles {
            if let data = try? Data(contentsOf: fileURL),
               let mimeType = getMimeType(for: fileURL) {
                let attachment = MessageAttachment(
                    id: UUID(),
                    data: data,
                    mimeType: mimeType,
                    filename: fileURL.lastPathComponent
                )
                attachments.append(attachment)
            }
        }

        // Use text or default message if only files attached
        var messageContent = text.isEmpty && !attachments.isEmpty ? "Attached \(attachments.count) file\(attachments.count == 1 ? "" : "s")" : text

        // Prepend mention context to the message content
        if !contextPrefix.isEmpty {
            messageContent = contextPrefix + messageContent
        }

        // Clear input state
        messageText = ""
        droppedFiles = []
        activeMentions = []
        mentionContext = nil
        showMentionSuggestions = false

        // Use conversation-specific model if set, otherwise use global
        let conversation = conversationManager.conversations.first(where: { $0.id == conversationId })
        let effectiveProvider = conversation?.selectedProvider ?? container.currentProvider
        let effectiveModel = conversation?.selectedModel ?? selectedModel

        // Build system prompt with project context if available
        let baseSystemPrompt = systemPromptPrefix.isEmpty ? nil : systemPromptPrefix
        let enhancedSystemPrompt = viewModel.buildSystemPromptWithProjectContext(basePrompt: baseSystemPrompt)

        let configuration = LLMConfiguration(
            provider: effectiveProvider,
            model: effectiveModel,
            temperature: 0.7,
            maxTokens: 4096,
            systemPrompt: enhancedSystemPrompt,
            enableChainOfThought: viewModel.showChainOfThought,
            enablePromptEnhancement: enablePromptEnhancement
        )

        // Store the original text (without context prefix) for title generation
        let originalUserText = text.isEmpty && !attachments.isEmpty
            ? "Attached \(attachments.count) file\(attachments.count == 1 ? "" : "s")"
            : text

        // Store mention references with the message for history display
        await viewModel.sendMessage(
            messageContent,
            configuration: configuration,
            attachments: attachments.isEmpty ? nil : attachments,
            mentionReferences: mentionReferences.isEmpty ? nil : mentionReferences
        )

        // Update message count
        conversationManager.incrementMessageCount(conversationId)

        // Generate title and summary after first exchange
        if isFirstMessage, let firstResponse = viewModel.messages.last?.content {
            Task {
                await conversationManager.generateTitleAndSummary(
                    for: conversationId,
                    firstMessage: originalUserText,
                    firstResponse: firstResponse,
                    provider: container.createLLMProvider()
                )
            }
        }

        // Re-focus input after sending
        DispatchQueue.main.async {
            isInputFocused = true
        }
    }

    private func missingAPIKeyError(for provider: LLMProvider) -> String? {
        switch provider {
        case .anthropic, .openai, .gemini, .custom:
            let key = (container.apiKeys[provider] ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return key.isEmpty ? "Missing API key for \(provider.displayName). Set it in Settings." : nil
        case .ollama:
            return nil
        }
    }
    
    @MainActor
    private func saveEditedMessage(messageId: UUID, newText: String) {
        guard let messageIndex = viewModel.messages.firstIndex(where: { $0.id == messageId }),
              messageIndex < viewModel.messages.count else {
            editingMessageId = nil
            editingMessageText = ""
            return
        }
        
        let message = viewModel.messages[messageIndex]
        guard message.role == .user else { return }
        
        // Update message content
        let updatedMessage = Message(
            id: message.id,
            conversationId: message.conversationId,
            role: message.role,
            content: newText.trimmingCharacters(in: .whitespacesAndNewlines),
            timestamp: message.timestamp,
            attachments: message.attachments,
            toolCallId: message.toolCallId,
            toolName: message.toolName
        )
        
        // Update in view model
        viewModel.messages[messageIndex] = updatedMessage
        
        // Save to repository
        Task {
            await conversationManager.conversationRepository.saveMessage(updatedMessage)
        }
        
        // Delete the following assistant response if it exists
        if messageIndex + 1 < viewModel.messages.count {
            let nextMessage = viewModel.messages[messageIndex + 1]
            if nextMessage.role == .assistant {
                Task {
                    await conversationManager.conversationRepository.deleteMessage(nextMessage.id)
                    _ = await MainActor.run {
                        viewModel.messages.remove(at: messageIndex + 1)
                    }
                }
            }
        }
        
        // Regenerate response with edited message
        editingMessageId = nil
        editingMessageText = ""
        
        let configuration = LLMConfiguration(
            provider: container.currentProvider,
            model: selectedModel,
            temperature: 0.7,
            maxTokens: 4096,
            systemPrompt: systemPromptPrefix.isEmpty ? nil : systemPromptPrefix,
            enableChainOfThought: viewModel.showChainOfThought,
            enablePromptEnhancement: enablePromptEnhancement
        )
        
        Task {
            await viewModel.sendMessage(newText, configuration: configuration, replaceAtIndex: messageIndex)
        }
    }
    
    @MainActor
    private func deleteMessageAndResponse(_ message: Message) {
        AppLogger.shared.log("Deleting message \(message.id)", level: .info)
        
        // Find the message index
        guard let messageIndex = viewModel.messages.firstIndex(where: { $0.id == message.id }) else { return }
        
        var messagesToDelete: [Message] = [message]
        
        // If it's a user message, also delete the following assistant response
        if message.role == .user, messageIndex + 1 < viewModel.messages.count {
            let nextMessage = viewModel.messages[messageIndex + 1]
            if nextMessage.role == .assistant {
                messagesToDelete.append(nextMessage)
            }
        }
        // If it's an assistant message, also delete the preceding user message
        else if message.role == .assistant, messageIndex > 0 {
            let prevMessage = viewModel.messages[messageIndex - 1]
            if prevMessage.role == .user {
                messagesToDelete.insert(prevMessage, at: 0)
            }
        }
        
        // Animate deletion with fade out
        withAnimation(.easeOut(duration: 0.3)) {
            for msg in messagesToDelete {
                // Remove from view with animation
                if let index = viewModel.messages.firstIndex(where: { $0.id == msg.id }) {
                    viewModel.messages.remove(at: index)
                }
                // Delete from repository
                Task {
                    await conversationManager.conversationRepository.deleteMessage(msg.id)
                }
            }
        }
        
        // Update conversation count
        conversationManager.incrementMessageCount(conversationId)
    }
    
    @MainActor
    private func regenerateResponse(for message: Message) {
        AppLogger.shared.log("Regenerating response for message \(message.id)", level: .info)
        
        // Find the user message that prompted this response
        guard let messageIndex = viewModel.messages.firstIndex(where: { $0.id == message.id }),
              messageIndex > 0 else { return }
        
        let userMessage = viewModel.messages[messageIndex - 1]
        guard userMessage.role == .user else { return }
        
        // Store the position to replace at
        let replaceIndex = messageIndex
        
        // Delete the current response from view (but keep position)
        withAnimation {
            viewModel.messages.removeAll { $0.id == message.id }
        }
        
        // Delete from repository
        Task {
            await conversationManager.conversationRepository.deleteMessage(message.id)
        }
        
        // Resend the user message - it will replace at the same position
        Task {
            let configuration = LLMConfiguration(
                provider: container.currentProvider,
                model: selectedModel,
                temperature: 0.7,
                maxTokens: 4096,
                systemPrompt: systemPromptPrefix.isEmpty ? nil : systemPromptPrefix,
                enableChainOfThought: viewModel.showChainOfThought,
                enablePromptEnhancement: enablePromptEnhancement
            )
            // Store the target index for replacement (assistant message will be inserted after user message)
            viewModel.targetReplaceIndex = replaceIndex
            await viewModel.sendMessage(userMessage.content, configuration: configuration, replaceAtIndex: replaceIndex)
        }
    }
    
    @MainActor
    private func regenerateWithDifferentModel(for message: Message) {
        AppLogger.shared.log("Regenerating with different model for message \(message.id)", level: .info)
        // Similar to regenerateResponse but allows model selection
        regenerateResponse(for: message)
    }
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .pdf, .text, .plainText, .json, .data]
        
        if panel.runModal() == .OK {
            droppedFiles.append(contentsOf: panel.urls)
        }
    }
    
    private func getMimeType(for url: URL) -> String? {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "md", "markdown":
            return "text/markdown"
        case "json":
            return "application/json"
        case "csv":
            return "text/csv"
        default:
            return "application/octet-stream"
        }
    }
}

struct ModelSelectorMenu: View {
    @Binding var selectedModel: String
    @EnvironmentObject var container: DependencyContainer
    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""

    var body: some View {
        Menu {
            ForEach(container.configuredProviders, id: \.self) { provider in
                Button {
                    container.currentProvider = provider
                    Task {
                        await container.loadModelsForCurrentProvider()

                        if provider == .ollama && !defaultOllamaModel.isEmpty {
                            selectedModel = defaultOllamaModel
                        } else if !container.availableModels.isEmpty {
                            selectedModel = container.availableModels[0]
                        }
                    }
                } label: {
                    HStack {
                        Text(provider.shortDisplayName)
                        if provider == container.currentProvider {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            if !container.availableModels.isEmpty {
                ForEach(container.availableModels, id: \.self) { model in
                    Button {
                        selectedModel = model
                    } label: {
                        HStack {
                            Text(model)
                            if model == selectedModel {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedModel.isEmpty ? container.currentProvider.shortDisplayName : selectedModel)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 150)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Select model")
        .frame(maxWidth: 170)
        .onAppear {
            if container.currentProvider == .ollama && !defaultOllamaModel.isEmpty {
                selectedModel = defaultOllamaModel
            }
        }
    }
}

// Editable message view for inline editing
struct EditableMessageView: View {
    let message: Message
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Spacer(minLength: 60)
            
            VStack(alignment: .trailing, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Edit message", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "00976d"))
                        .cornerRadius(20)
                        .foregroundStyle(Color(hex: "eeeeee"))
                        .focused($isFocused)
                        .onSubmit {
                            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSave()
                            }
                        }
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        Button("Cancel") {
                            onCancel()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        
                        Button("Save & Regenerate") {
                            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSave()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(hex: "00976d"))
                        .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: "00976d").opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "eeeeee"))
            }
            
            Spacer(minLength: 60)
        }
        .onAppear {
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
}

struct StreamingMessageView: View {
    let text: String

    // Break out the heavy MarkdownUI pipeline to help the type-checker
    private var configuredMarkdown: some View {
        MarkdownUI.Markdown(text)
            .markdownTextStyle(\.text) {
                ForegroundColor(Color(nsColor: .textColor))
                FontSize(14)
            }
            .markdownTextStyle(\.code) {
                FontFamilyVariant(.monospaced)
                FontSize(13)
                ForegroundColor(ThemeColors.codeAccent)
                BackgroundColor(ThemeColors.codeBackground)
            }
            .markdownBlockStyle(\.codeBlock) { configuration in
                configuration.label
                    .padding(12)
                    .background(ThemeColors.darkSurface)
                    .cornerRadius(8)
            }
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(ThemeColors.darkSurface)
            .cornerRadius(16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(ThemeColors.accent.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ThemeColors.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                configuredMarkdown

                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Streaming...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }

            Spacer(minLength: 60)
        }
    }
}

// MARK: - Error Card Component

/// Error type classification for appropriate icons and actions
enum ErrorType {
    case network
    case apiKey
    case rateLimit
    case serverError
    case timeout
    case unknown

    var icon: String {
        switch self {
        case .network:
            return "wifi.slash"
        case .apiKey:
            return "key.slash"
        case .rateLimit:
            return "gauge.with.needle.fill"
        case .serverError:
            return "exclamationmark.icloud.fill"
        case .timeout:
            return "clock.badge.exclamationmark.fill"
        case .unknown:
            return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .network:
            return ThemeColors.warning
        case .apiKey:
            return ThemeColors.error
        case .rateLimit:
            return ThemeColors.warning
        case .serverError:
            return ThemeColors.error
        case .timeout:
            return ThemeColors.warning
        case .unknown:
            return ThemeColors.warning
        }
    }

    var backgroundColor: Color {
        color.opacity(0.12)
    }

    var title: String {
        switch self {
        case .network:
            return "Connection Error"
        case .apiKey:
            return "API Key Error"
        case .rateLimit:
            return "Rate Limited"
        case .serverError:
            return "Server Error"
        case .timeout:
            return "Request Timeout"
        case .unknown:
            return "Error"
        }
    }

    var showRetry: Bool {
        switch self {
        case .network, .serverError, .timeout, .rateLimit:
            return true
        case .apiKey, .unknown:
            return false
        }
    }

    var showSettings: Bool {
        switch self {
        case .apiKey:
            return true
        default:
            return false
        }
    }

    static func classify(_ errorMessage: String) -> ErrorType {
        let lowercased = errorMessage.lowercased()

        if lowercased.contains("api key") || lowercased.contains("apikey") ||
           lowercased.contains("unauthorized") || lowercased.contains("authentication") ||
           lowercased.contains("missing") && lowercased.contains("key") {
            return .apiKey
        }

        if lowercased.contains("rate limit") || lowercased.contains("ratelimit") ||
           lowercased.contains("too many requests") || lowercased.contains("429") {
            return .rateLimit
        }

        if lowercased.contains("network") || lowercased.contains("connection") ||
           lowercased.contains("internet") || lowercased.contains("offline") ||
           lowercased.contains("unreachable") {
            return .network
        }

        if lowercased.contains("timeout") || lowercased.contains("timed out") {
            return .timeout
        }

        if lowercased.contains("server") || lowercased.contains("500") ||
           lowercased.contains("502") || lowercased.contains("503") {
            return .serverError
        }

        return .unknown
    }
}

/// Actionable error card with context-aware buttons
struct ErrorCard: View {
    let error: String
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    let onOpenSettings: (() -> Void)?

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var errorType: ErrorType {
        ErrorType.classify(error)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(errorType.backgroundColor)
                    .frame(width: 36, height: 36)

                Image(systemName: errorType.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(errorType.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(errorType.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                if errorType.showRetry, let onRetry = onRetry {
                    Button {
                        onRetry()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Retry")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ThemeColors.accent)
                        .foregroundStyle(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retry request")
                }

                if errorType.showSettings, let onOpenSettings = onOpenSettings {
                    Button {
                        onOpenSettings()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Settings")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ThemeColors.darkSurface)
                        .foregroundStyle(.primary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ThemeColors.darkBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open settings")
                }

                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(ThemeColors.darkSurface)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss error")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(errorType.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(errorType.color.opacity(isHovered ? 0.4 : 0.2), lineWidth: 1)
        )
        .onHover { hovering in
            if reduceMotion {
                isHovered = hovering
            } else {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(errorType.title): \(error)")
    }
}

// MARK: - Notification Extension for Settings

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
