import SwiftUI
import MarkdownUI
import UniformTypeIdentifiers

struct ChatView: View {
    let conversationId: UUID
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var conversationManager: ConversationManager
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText: String = ""
    @State private var selectedModel: String = ""
    @State private var selectedProvider: LLMProvider? = nil
    @State private var showSlashCommands: Bool = false
    @State private var showWhiteboard: Bool = false
    @State private var pendingAttachments: [PendingAttachment] = []
    @State private var isDropTargeted: Bool = false
    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""
    @FocusState private var isInputFocused: Bool

    /// Returns the effective provider: conversation override or global
    private var effectiveProvider: LLMProvider {
        selectedProvider ?? container.currentProvider
    }

    init(conversationId: UUID) {
        self.conversationId = conversationId
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversationId: conversationId,
            conversationRepository: ConversationRepository()
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            errorBanner
            messagesScrollView
            inputBar
        }
        .navigationTitle("Chat")
        .onAppear { setupView() }
        .onChange(of: container.currentProvider) { _, newProvider in
            handleProviderChange(newProvider)
        }
        .onChange(of: container.apiKeys) { _, _ in
            // Re-create provider when API keys change (in case current provider's key was updated)
            updateProviderForCurrentSelection()
        }
        .sheet(isPresented: $showWhiteboard) {
            WhiteboardView(isPresented: $showWhiteboard)
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

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            onEdit: message.role == .user ? { newContent in
                                editMessage(message.id, newContent: newContent)
                            } : nil
                        )
                        .id(message.id)
                    }

                    if viewModel.isStreaming {
                        streamingContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToLastMessage(proxy: proxy)
            }
            .onChange(of: viewModel.currentStreamingText) { _, _ in
                withAnimation {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private var streamingContent: some View {
        if viewModel.currentStreamingText.isEmpty {
            ThinkingIndicator()
                .id("thinking")
        } else {
            StreamingMessageView(text: viewModel.currentStreamingText)
                .id("streaming")
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            slashCommandsOverlay
            Divider()
            inputBarContent
        }
    }

    @ViewBuilder
    private var slashCommandsOverlay: some View {
        if showSlashCommands {
            SlashCommandView(
                searchText: String(messageText.dropFirst()),
                onSelect: { command in
                    handleSlashCommand(command)
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var inputBarContent: some View {
        VStack(spacing: 8) {
            // Attachment preview strip
            if !pendingAttachments.isEmpty {
                AttachmentStripView(attachments: pendingAttachments) { attachment in
                    pendingAttachments.removeAll { $0.id == attachment.id }
                }
            }

            HStack(spacing: 12) {
                leftButtons
                modelSelector
                textInput
                rightButtons
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(dropHighlightOverlay)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onDrop(of: SupportedDropType.allTypes, isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    @ViewBuilder
    private var dropHighlightOverlay: some View {
        if isDropTargeted {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.1))
                )
        }
    }

    private var leftButtons: some View {
        HStack(spacing: 8) {
            Button {
                openFilePicker()
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(pendingAttachments.isEmpty ? .secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .help("Attach file (drag & drop or Cmd+V to paste images)")

            Button {
                openImagePicker()
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Add image")

            Button {
                showWhiteboard.toggle()
            } label: {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 20))
                    .foregroundStyle(showWhiteboard ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .help("Open whiteboard")
        }
    }

    private var modelSelector: some View {
        Menu {
            providerMenuContent
            Divider()
            modelMenuContent

            if selectedProvider != nil || !selectedModel.isEmpty {
                Divider()
                Button {
                    // Reset to global settings
                    selectedProvider = nil
                    selectedModel = ""
                    conversationManager.updateModelSettings(conversationId, provider: nil, model: nil)
                    Task {
                        await container.loadModelsForCurrentProvider()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Use Global Settings")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                // Show indicator if using conversation-specific settings
                if selectedProvider != nil {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                }
                Text(modelSelectorDisplayText)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(selectedProvider != nil ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .help(selectedProvider != nil ? "Model for this conversation (override)" : "Select model (using global settings)")
    }

    private var modelSelectorDisplayText: String {
        if !selectedModel.isEmpty {
            return selectedModel
        }
        return effectiveProvider.shortDisplayName
    }

    @ViewBuilder
    private var providerMenuContent: some View {
        ForEach(container.configuredProviders, id: \.self) { provider in
            Button {
                selectProvider(provider, forConversation: true)
            } label: {
                HStack {
                    Text(provider.shortDisplayName)
                    if provider == effectiveProvider {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var modelMenuContent: some View {
        // Use available models from container for Ollama, or provider defaults for API providers
        let models = effectiveModelsForProvider
        if !models.isEmpty {
            ForEach(models, id: \.self) { model in
                Button {
                    selectModel(model)
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
    }

    /// Returns the models available for the effective provider
    private var effectiveModelsForProvider: [String] {
        // For Ollama, use container's available models (dynamically loaded)
        // For API providers, use their default models
        if selectedProvider == nil {
            // Using global settings
            return container.availableModels.isEmpty ? effectiveProvider.defaultModels : container.availableModels
        } else {
            // Using conversation-specific provider
            switch effectiveProvider {
            case .ollama:
                return container.availableModels.isEmpty ? effectiveProvider.defaultModels : container.availableModels
            default:
                return effectiveProvider.defaultModels
            }
        }
    }

    private func selectModel(_ model: String) {
        selectedModel = model
        // If provider wasn't explicitly set for this conversation, set it now
        if selectedProvider == nil {
            selectedProvider = container.currentProvider
        }
        conversationManager.updateModelSettings(conversationId, provider: selectedProvider, model: model)
    }

    private var textInput: some View {
        PasteableTextField(
            text: $messageText,
            placeholder: "Ask anything or type / for commands",
            onPasteImage: { attachment in
                pendingAttachments.append(attachment)
            }
        )
        .font(.system(size: 14))
        .disabled(viewModel.isStreaming)
        .focused($isInputFocused)
        .onChange(of: messageText) { _, newValue in
            showSlashCommands = newValue.hasPrefix("/") && newValue.count > 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .submitChatInput)) { _ in
            Task { await sendMessage() }
        }
    }

    private var rightButtons: some View {
        HStack(spacing: 8) {
            Button {
                // Voice input
            } label: {
                Image(systemName: "mic")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Voice input")

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(viewModel.isStreaming ? .red : .accentColor)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isStreaming && messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingAttachments.isEmpty)
            .keyboardShortcut(.return, modifiers: [])
        }
    }

    // MARK: - Actions

    private func setupView() {
        // Load conversation-specific model settings
        loadConversationModelSettings()

        // Create provider based on conversation settings or fall back to global
        updateProviderForCurrentSelection()

        Task {
            await loadModelsForEffectiveProvider()
            // If no model selected yet, use first available or default
            if selectedModel.isEmpty {
                selectedModel = container.availableModels.first ?? effectiveProvider.defaultModels.first ?? ""
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInputFocused = true
        }
    }

    private func loadConversationModelSettings() {
        // Find the conversation and load its model settings
        if let conversation = conversationManager.conversations.first(where: { $0.id == conversationId }) {
            selectedProvider = conversation.selectedProvider
            selectedModel = conversation.selectedModel ?? ""
        }
    }

    private func updateProviderForCurrentSelection() {
        if let provider = selectedProvider,
           let llmProvider = container.createLLMProvider(for: provider) {
            viewModel.updateProvider(llmProvider)
        } else {
            viewModel.updateProvider(container.createLLMProvider())
        }
    }

    private func loadModelsForEffectiveProvider() async {
        if selectedProvider != nil {
            // Load models for the conversation's specific provider
            switch effectiveProvider {
            case .ollama:
                await container.loadModelsForCurrentProvider()
            default:
                // For API providers, use default models
                break
            }
        } else {
            await container.loadModelsForCurrentProvider()
        }
    }

    private func handleProviderChange(_ newProvider: LLMProvider) {
        // Only update if we're using global settings (no conversation-specific override)
        if selectedProvider == nil {
            viewModel.updateProvider(container.createLLMProvider())
            if !newProvider.defaultModels.contains(selectedModel) {
                selectedModel = newProvider.defaultModels.first ?? ""
            }
        }
    }

    private func selectProvider(_ provider: LLMProvider, forConversation: Bool = false) {
        if forConversation {
            // Set conversation-specific provider
            selectedProvider = provider
            conversationManager.updateModelSettings(conversationId, provider: provider, model: nil)

            // Update the LLM provider for this conversation
            if let llmProvider = container.createLLMProvider(for: provider) {
                viewModel.updateProvider(llmProvider)
            }

            Task {
                // Load models for the selected provider
                if provider == .ollama {
                    await container.loadModelsForCurrentProvider()
                }

                // Update selected model
                if provider == .ollama && !defaultOllamaModel.isEmpty {
                    selectedModel = defaultOllamaModel
                } else if !container.availableModels.isEmpty {
                    selectedModel = container.availableModels[0]
                } else {
                    selectedModel = provider.defaultModels.first ?? ""
                }

                // Persist the model selection too
                conversationManager.updateModelSettings(conversationId, provider: provider, model: selectedModel)
            }
        } else {
            // Legacy: update global provider
            container.currentProvider = provider
            Task {
                await container.loadModelsForCurrentProvider()
                if provider == .ollama && !defaultOllamaModel.isEmpty {
                    selectedModel = defaultOllamaModel
                } else if !container.availableModels.isEmpty {
                    selectedModel = container.availableModels[0]
                }
            }
        }
    }

    private func scrollToLastMessage(proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func handleSlashCommand(_ command: SlashCommand) {
        showSlashCommands = false

        switch command.name {
        case "whiteboard":
            showWhiteboard = true
            messageText = ""
        case "clear":
            messageText = ""
        default:
            messageText = "/\(command.name) "
        }
    }

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }
        if let apiKeyError = missingAPIKeyError(for: effectiveProvider) {
            viewModel.error = apiKeyError
            return
        }
        viewModel.error = nil

        // Capture and clear state
        let textToSend = text
        let attachmentsToSend = pendingAttachments.map { $0.toMessageAttachment() }
        messageText = ""
        pendingAttachments = []

        let configuration = LLMConfiguration(
            provider: effectiveProvider,
            model: selectedModel.isEmpty ? (effectiveProvider.defaultModels.first ?? "") : selectedModel,
            temperature: 0.7,
            maxTokens: 4096,
            systemPrompt: nil,
            enableChainOfThought: viewModel.showChainOfThought
        )

        await viewModel.sendMessage(
            textToSend.isEmpty ? "[Attached \(attachmentsToSend.count) file(s)]" : textToSend,
            configuration: configuration,
            attachments: attachmentsToSend.isEmpty ? nil : attachmentsToSend
        )

        DispatchQueue.main.async {
            isInputFocused = true
        }
    }

    private func missingAPIKeyError(for provider: LLMProvider) -> String? {
        switch provider {
        case .anthropic, .openai, .gemini, .custom:
            let key = (container.apiKeys[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return key.isEmpty ? "Missing API key for \(provider.displayName). Set it in Settings." : nil
        case .ollama:
            return nil
        }
    }

    private func editMessage(_ messageId: UUID, newContent: String) {
        // Check for API key before editing
        if let apiKeyError = missingAPIKeyError(for: effectiveProvider) {
            viewModel.error = apiKeyError
            return
        }

        let configuration = LLMConfiguration(
            provider: effectiveProvider,
            model: selectedModel.isEmpty ? (effectiveProvider.defaultModels.first ?? "") : selectedModel,
            temperature: 0.7,
            maxTokens: 4096,
            systemPrompt: nil,
            enableChainOfThought: viewModel.showChainOfThought
        )

        Task {
            await viewModel.editMessage(messageId, newContent: newContent, configuration: configuration)
        }
    }

    // MARK: - File Pickers

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .png, .jpeg, .gif, .webP, .heic, .tiff, .bmp,
            .pdf, .plainText, .json, .xml, .html, .sourceCode
        ]
        panel.message = "Select files to attach"
        panel.prompt = "Attach"

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let attachment = ClipboardHandler.loadFile(from: url) {
                    pendingAttachments.append(attachment)
                }
            }
        }
    }

    private func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP, .heic, .tiff, .bmp]
        panel.message = "Select images to attach"
        panel.prompt = "Add Images"

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let attachment = ClipboardHandler.loadFile(from: url) {
                    pendingAttachments.append(attachment)
                }
            }
        }
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // Try to load as file URL first
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            if let attachment = ClipboardHandler.loadFile(from: url) {
                                self.pendingAttachments.append(attachment)
                            }
                        }
                    }
                }
                continue
            }

            // Try to load as image data
            for imageType in SupportedDropType.imageTypes {
                if provider.hasItemConformingToTypeIdentifier(imageType.identifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: imageType.identifier) { data, error in
                        if let data = data {
                            let mimeType = SupportedDropType.mimeType(for: imageType)
                            let ext = imageType.preferredFilenameExtension ?? "png"
                            DispatchQueue.main.async {
                                let attachment = PendingAttachment(
                                    data: data,
                                    filename: "dropped-image.\(ext)",
                                    mimeType: mimeType
                                )
                                self.pendingAttachments.append(attachment)
                            }
                        }
                    }
                    break
                }
            }
        }
    }
}

struct StreamingMessageView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatarView
            contentView
            Spacer(minLength: 60)
        }
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 32, height: 32)

            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.purple)
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Markdown(text)
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

            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                Text("Streaming...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}
