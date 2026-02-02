import SwiftUI
import MarkdownUI

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
            viewModel.updateProvider(container.createLLMProvider())
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
                        MessageBubbleView(message: message)
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
        HStack(spacing: 12) {
            leftButtons
            modelSelector
            textInput
            rightButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var leftButtons: some View {
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
    }

    private var modelSelector: some View {
        Menu {
            providerMenuContent
            Divider()
            modelMenuContent
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
            if container.currentProvider == .ollama && !defaultOllamaModel.isEmpty {
                selectedModel = defaultOllamaModel
            }
        }
    }

    @ViewBuilder
    private var providerMenuContent: some View {
        ForEach(container.configuredProviders, id: \.self) { provider in
            Button {
                selectProvider(provider)
            } label: {
                HStack {
                    Text(provider.shortDisplayName)
                    if provider == container.currentProvider {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var modelMenuContent: some View {
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
    }

    private var textInput: some View {
        TextField("Ask anything or type / for commands", text: $messageText, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .lineLimit(1...6)
            .disabled(viewModel.isStreaming)
            .focused($isInputFocused)
            .onChange(of: messageText) { _, newValue in
                showSlashCommands = newValue.hasPrefix("/") && newValue.count > 1
            }
            .onSubmit {
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
            .disabled(!viewModel.isStreaming && messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: [])
        }
    }

    // MARK: - Actions

    private func setupView() {
        viewModel.updateProvider(container.createLLMProvider())
        Task {
            await container.loadModelsForCurrentProvider()
            if selectedModel.isEmpty {
                selectedModel = container.availableModels.first ?? container.currentProvider.defaultModels.first ?? ""
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInputFocused = true
        }
    }

    private func handleProviderChange(_ newProvider: LLMProvider) {
        viewModel.updateProvider(container.createLLMProvider())
        if !newProvider.defaultModels.contains(selectedModel) {
            selectedModel = newProvider.defaultModels.first ?? ""
        }
    }

    private func selectProvider(_ provider: LLMProvider) {
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
