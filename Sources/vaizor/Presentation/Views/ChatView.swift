import SwiftUI

struct ChatView: View {
    let conversationId: UUID
    @EnvironmentObject var container: DependencyContainer
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText: String = ""
    @State private var selectedModel: String = ""
    @State private var showSlashCommands: Bool = false
    @State private var showWhiteboard: Bool = false
    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""
    @FocusState private var isInputFocused: Bool

    init(conversationId: UUID) {
        self.conversationId = conversationId
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversationId: conversationId,
            conversationRepository: ConversationRepository()
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
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

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }

                        if viewModel.isStreaming {
                            if viewModel.currentStreamingText.isEmpty {
                                ThinkingIndicator()
                                    .id("thinking")
                            } else {
                                StreamingMessageView(text: viewModel.currentStreamingText)
                                    .id("streaming")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.currentStreamingText) { _, _ in
                    withAnimation {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }

            // Modern chat input bar
            VStack(spacing: 0) {
                // Slash command suggestions
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

                Divider()

                HStack(spacing: 12) {
                    // Left icons
                    HStack(spacing: 8) {
                        Button {
                            // Attach file
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Attach file")

                        Button {
                            // Open image
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

                    // Model selector (inline)
                    Menu {
                        ForEach(container.configuredProviders, id: \.self) { provider in
                            Button {
                                container.currentProvider = provider
                                Task {
                                    await container.loadModelsForCurrentProvider()

                                    // Auto-select default Ollama model if switching to Ollama
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
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Select model")
                    .onAppear {
                        // Initialize with default Ollama model if on Ollama
                        if container.currentProvider == .ollama && !defaultOllamaModel.isEmpty {
                            selectedModel = defaultOllamaModel
                        }
                    }

                    // Text input
                    TextField("Ask anything or type / for commands", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .lineLimit(1...6)
                        .disabled(viewModel.isStreaming)
                        .focused($isInputFocused)
                        .onChange(of: messageText) { _, newValue in
                            // Show slash commands if text starts with /
                            showSlashCommands = newValue.hasPrefix("/") && newValue.count > 1
                        }
                        .onSubmit {
                            Task {
                                await sendMessage()
                            }
                        }

                    // Right icons
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
                            Task {
                                await sendMessage()
                            }
                        } label: {
                            Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(viewModel.isStreaming ? .red : .accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.isStreaming && messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.return, modifiers: [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                .appleIntelligenceGlow(isActive: !messageText.isEmpty || viewModel.isStreaming)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Chat")
        .onAppear {
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

    private func handleSlashCommand(_ command: SlashCommand) {
        showSlashCommands = false

        switch command.name {
        case "whiteboard":
            showWhiteboard = true
            messageText = ""
        case "clear":
            // Clear conversation
            messageText = ""
        default:
            messageText = "/\(command.name) "
        }
    }

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let apiKeyError = missingAPIKeyError(for: container.currentProvider) {
            viewModel.error = apiKeyError
            return
        }
        viewModel.error = nil

        messageText = ""

        let configuration = LLMConfiguration(
            provider: container.currentProvider,
            model: selectedModel,
            temperature: 0.7,
            maxTokens: 4096,
            systemPrompt: nil,
            enableChainOfThought: viewModel.showChainOfThought
        )

        await viewModel.sendMessage(text, configuration: configuration)

        // Re-focus input after sending
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
}

struct StreamingMessageView: View {
    let text: String

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
