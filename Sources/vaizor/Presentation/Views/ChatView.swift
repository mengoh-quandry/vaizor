import SwiftUI
import MarkdownUI

struct ChatView: View {
    let conversationId: UUID
    @ObservedObject var conversationManager: ConversationManager
    @EnvironmentObject var container: DependencyContainer
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText: String = ""
    @State private var selectedModel: String = ""
    @State private var showSlashCommands: Bool = false
    @State private var slashCommandTimer: Task<Void, Never>?
    @State private var showWhiteboard: Bool = false
    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""
    @AppStorage("chatFontZoom") private var chatFontZoom: Double = 1.0
    @AppStorage("chatInputFontZoom") private var chatInputFontZoom: Double = 1.0
    @AppStorage("enablePromptEnhancement") private var enablePromptEnhancement: Bool = true
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    @State private var autoScrollEnabled: Bool = true
    @State private var showCommandPalette: Bool = false
    @State private var editingMessageId: UUID? = nil
    @State private var editingMessageText: String = ""
    @State private var droppedFiles: [URL] = []
    @State private var isDraggingOver: Bool = false
    
    // Virtualization state
    @State private var visibleMessageRange: Range<Int> = 0..<50
    @State private var messageBufferSize: Int = 10 // Messages above/below viewport

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

    private var animationTrigger: String {
        isInputActive ? "active" : "inactive"
    }

    private var inputBorderColors: [Color] {
        isInputActive ?
            [Color.blue.opacity(0.6), Color.purple.opacity(0.6), Color.pink.opacity(0.6)] :
            [Color.gray.opacity(0.2)]
    }

    private var inputBorderWidth: CGFloat {
        isInputActive ? 2 : 1
    }

    private var inputShadowColor: Color {
        isInputActive ? Color.blue.opacity(0.3) : Color.clear
    }

    struct InputBorderOverlayView: View {
        let colors: [Color]
        let lineWidth: CGFloat

        var body: some View {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )
        }
    }

    private func inputBorderOverlay() -> some View {
        InputBorderOverlayView(colors: inputBorderColors, lineWidth: inputBorderWidth)
    }

    @ViewBuilder
    private func messagesList(proxy: ScrollViewProxy) -> some View {
        GeometryReader { geometry in
            let dynamicMaxWidth = min(geometry.size.width - 40, max(350, geometry.size.width * 0.85))
            ScrollViewReader { scrollReader in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Loading indicator for older messages
                        if viewModel.isLoadingMore {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading older messages...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .id("loading-more")
                        }
                        
                        // Load more trigger (invisible at top)
                        Color.clear
                            .frame(height: 1)
                            .id("load-more-trigger")
                            .onAppear {
                                // Load more messages when scrolling near top
                                if viewModel.hasMoreMessages && !viewModel.isLoadingMore {
                                    Task {
                                        await viewModel.loadMoreMessages()
                                    }
                                }
                            }
                        
                        // Virtualized message rendering - only render visible + buffer
                        let totalMessages = viewModel.messages.count
                        let startIndex = max(0, visibleMessageRange.lowerBound - messageBufferSize)
                        let endIndex = min(totalMessages, visibleMessageRange.upperBound + messageBufferSize)
                        
                        // Placeholder for messages above viewport
                        if startIndex > 0 {
                            Color.clear
                                .frame(height: CGFloat(startIndex) * 100) // Estimated height
                                .id("spacer-top")
                        }
                        
                        // Render visible messages
                        ForEach(Array(viewModel.messages[startIndex..<endIndex].enumerated()), id: \.element.id) { enumeratedItem in
                            let index = enumeratedItem.offset
                            let message = enumeratedItem.element
                            let actualIndex = startIndex + index
                            Group {
                                if editingMessageId == message.id && message.role == .user {
                                    // Show editable message view
                                    EditableMessageView(
                                        message: message,
                                        text: $editingMessageText,
                                        onSave: {
                                            saveEditedMessage(messageId: message.id, newText: editingMessageText)
                                        },
                                        onCancel: {
                                            editingMessageId = nil
                                            editingMessageText = ""
                                        }
                                    )
                                } else {
                                    MessageBubbleView(
                                        message: message,
                                        provider: container.currentProvider,
                                        isPromptEnhanced: enablePromptEnhancement && message.role == .user,
                                        onCopy: {
                                            let pasteboard = NSPasteboard.general
                                            pasteboard.clearContents()
                                            pasteboard.setString(message.content, forType: .string)
                                        },
                                        onEdit: message.role == .user ? {
                                            // Start editing message
                                            editingMessageId = message.id
                                            editingMessageText = message.content
                                        } : nil,
                                        onDelete: {
                                            deleteMessageAndResponse(message)
                                        },
                                        onRegenerate: message.role == .assistant ? {
                                            regenerateResponse(for: message)
                                        } : nil,
                                        onRegenerateDifferent: message.role == .assistant ? {
                                            regenerateWithDifferentModel(for: message)
                                        } : nil,
                                        onScrollToTop: message.role == .assistant ? {
                                            if let proxy = scrollProxy {
                                                withAnimation {
                                                    proxy.scrollTo(message.id, anchor: .top)
                                                }
                                                autoScrollEnabled = false
                                            }
                                        } : nil
                                    )
                                }
                            }
                            .id(message.id)
                            .frame(maxWidth: dynamicMaxWidth, alignment: message.role == .user ? .trailing : .leading)
                            .onAppear {
                                // Update visible range as messages appear
                                updateVisibleRange(actualIndex)
                            }
                        }

                        // Placeholder for messages below viewport
                        if endIndex < totalMessages {
                            Color.clear
                                .frame(height: CGFloat(totalMessages - endIndex) * 100) // Estimated height
                                .id("spacer-bottom")
                        }

                        if viewModel.isStreaming {
                            if viewModel.currentStreamingText.isEmpty {
                                ThinkingIndicator(status: viewModel.thinkingStatus)
                                    .id("thinking")
                            } else {
                                StreamingMessageView(text: viewModel.currentStreamingText)
                                    .id("streaming")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, max(10, min(20, geometry.size.width * 0.02)))
                    .padding(.vertical, 16)
                }
                .onAppear {
                    scrollProxy = scrollReader
                }
            }
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

    @ViewBuilder
    private func inputRow() -> some View {
        HStack(spacing: 12) {
            TextField(
                viewModel.isParallelMode ? "Ask multiple models..." : "Ask anything or type / for commands",
                text: $messageText,
                axis: .vertical
            )
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...6)
                .disabled(viewModel.isStreaming)
                .focused($isInputFocused)
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
                    
                    if newValue.hasPrefix("/") {
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
                    }
                }
                .onKeyPress(phases: .down) { press in
                    if press.key == .return {
                        // Shift+Enter: insert newline (let default behavior happen)
                        if press.modifiers.contains(.shift) {
                            return .ignored
                        }
                        // Plain Enter: send message
                        Task { await sendMessage() }
                        return .handled
                    }
                    return .ignored
                }

            Button {
                if viewModel.isStreaming {
                    viewModel.stopStreaming()
                } else {
                    Task { await sendMessage() }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.isStreaming ? Color.red : Color(hex: "00976d"))
                        .frame(width: 32, height: 32)
                        .shadow(color: (viewModel.isStreaming ? Color.red : Color(hex: "00976d")).opacity(0.3), radius: 4, y: 2)

                    Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "eeeeee"))
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isStreaming && messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(!viewModel.isStreaming && messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.error {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(error)
                    .font(.caption)
                Spacer()
                Button("Dismiss") {
                    viewModel.error = nil
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            .padding(8)
            .background(Color.orange.opacity(0.1))
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
                    if autoScrollEnabled, let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.currentStreamingText) { _, _ in
                    if autoScrollEnabled {
                        withAnimation {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { _ in
                    if let firstMessage = viewModel.messages.first {
                        withAnimation {
                            proxy.scrollTo(firstMessage.id, anchor: .top)
                        }
                        autoScrollEnabled = false
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .scrollToBottom)) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                        autoScrollEnabled = true
                    }
                }
        }
    }

    @ViewBuilder
    private var inputBar: some View {
        VStack(spacing: 0) {
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
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Divider()

            VStack(spacing: 12) {
                // Dropped files preview
                if !droppedFiles.isEmpty {
                    DroppedFilesView(files: droppedFiles) {
                        droppedFiles.removeAll()
                    }
                }
                
                // Top row: Icons and model selector
                topInputRow

                // Bottom row: Text input and send button
                inputRow()
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(inputBorderOverlay())
            .overlay(
                Group {
                    if isDraggingOver {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "00976d"), lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: "00976d").opacity(0.1))
                            )
                    }
                }
            )
            .shadow(color: inputShadowColor, radius: 12, x: 0, y: 4)
            .animation(.easeInOut(duration: 0.3), value: animationTrigger)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
                handleDroppedFiles(providers: providers)
            }
        }
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
                .help("Attach Files")
                .buttonStyle(.plain)
                .help("Attach file")

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

                Button {
                    showWhiteboard.toggle()
                } label: {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 18))
                        .foregroundStyle(showWhiteboard ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .help("Open whiteboard")

                // MCP Servers indicator
                mcpServersMenu
            }

            Spacer()

            // Right icons
            HStack(spacing: 6) {
                // Prompt enhancement indicator
                if enablePromptEnhancement {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "00976d"))
                        .help("Prompt enhancement enabled")
                }
                
                // Parallel mode toggle
                parallelModeButton
                
                // Model selector - moved to right side
                ModelSelectorMenu(selectedModel: $selectedModel)
                    .layoutPriority(1)
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
                                .fill(isEnabled ? Color.green : Color.gray)
                                .frame(width: 6, height: 6)

                            Text(server.name)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "power")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isEnabled ? Color(hex: "00976d") : Color.secondary)
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
                    .foregroundStyle(container.mcpManager.enabledServers.isEmpty ? Color.secondary : Color.green)

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
        .onKeyPress { press in
            // Command+K to open palette
            if press.modifiers.contains(.command) && press.key.character == "k" {
                showCommandPalette = true
                return .handled
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
    }
    
    @ViewBuilder
    private var mainContentView: some View {
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
    private var scrollToBottomButton: some View {
        if !viewModel.messages.isEmpty {
            VStack(spacing: 0) {
                Button {
                    if let lastMessage = viewModel.messages.last, let proxy = scrollProxy {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                        autoScrollEnabled = true
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "00976d"))
                            .frame(width: 32, height: 32)
                            .shadow(color: Color(hex: "00976d").opacity(0.3), radius: 4, y: 2)

                        Image(systemName: "arrow.down")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "eeeeee"))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .buttonStyle(.plain)
                .help("Scroll to Bottom")
                
                Spacer()
                    .frame(height: 40)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 0)
        }
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
                    // TODO: Apply system prompt to conversation
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
        guard !text.isEmpty || !droppedFiles.isEmpty else { return }
        
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
        let messageContent = text.isEmpty && !attachments.isEmpty ? "Attached \(attachments.count) file\(attachments.count == 1 ? "" : "s")" : text
        
        messageText = ""
        droppedFiles = []

        // Use conversation-specific model if set, otherwise use global
        let conversation = conversationManager.conversations.first(where: { $0.id == conversationId })
        let effectiveProvider = conversation?.selectedProvider ?? container.currentProvider
        let effectiveModel = conversation?.selectedModel ?? selectedModel

        let configuration = LLMConfiguration(
            provider: effectiveProvider,
            model: effectiveModel,
            temperature: 0.7,
            maxTokens: 4096,
            systemPrompt: nil,
            enableChainOfThought: viewModel.showChainOfThought,
            enablePromptEnhancement: enablePromptEnhancement
        )

        let userMessage = messageContent
        await viewModel.sendMessage(messageContent, configuration: configuration, attachments: attachments.isEmpty ? nil : attachments)

        // Update message count
        conversationManager.incrementMessageCount(conversationId)

        // Generate title and summary after first exchange
        if isFirstMessage, let firstResponse = viewModel.messages.last?.content {
            Task {
                await conversationManager.generateTitleAndSummary(
                    for: conversationId,
                    firstMessage: userMessage,
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
            systemPrompt: nil,
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
                systemPrompt: nil,
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
                ForegroundColor(.purple)
                BackgroundColor(Color.purple.opacity(0.1))
            }
            .markdownBlockStyle(\.codeBlock) { configuration in
                configuration.label
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
            }
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.purple)
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
