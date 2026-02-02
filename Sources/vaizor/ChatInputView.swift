import SwiftUI

struct ChatInputView: View {
    @Binding var messageText: String
    @Binding var showSlashCommands: Bool
    @Binding var showWhiteboard: Bool
    @Binding var selectedModel: String
    
    let isStreaming: Bool
    let container: DependencyContainer
    let onSend: () -> Void
    let onStop: () -> Void
    
    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
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

            VStack(spacing: 12) {
                // Top row: Icons and model selector
                HStack(spacing: 12) {
                    // Left icons
                    leftIcons
                    
                    Spacer()

                    // Model selector
                    modelSelector

                    // Right icons
                    rightIcons
                }

                // Bottom row: Text input and send button
                inputRow
            }
            .padding(16)
            .background(Material.thin)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(inputBorder)
            .shadow(color: inputShadowColor, radius: 8, x: 0, y: 3)
            .animation(.easeInOut(duration: 0.3), value: messageText.isEmpty)
            .animation(.easeInOut(duration: 0.3), value: isStreaming)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Material.ultraThin)
    }
    
    private var leftIcons: some View {
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

            mcpServersIndicator
        }
    }
    
    private var mcpServersIndicator: some View {
        Menu {
            if container.mcpManager.availableServers.isEmpty {
                Text("No MCP servers configured")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(container.mcpManager.availableServers) { server in
                    HStack {
                        Circle()
                            .fill(container.mcpManager.enabledServers.contains(server.id) ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)

                        Text(server.name)

                        Spacer()

                        if container.mcpManager.enabledServers.contains(server.id) {
                            Text("Running")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "server.rack")
                    .font(.system(size: 16))
                    .foregroundStyle(container.mcpManager.enabledServers.isEmpty ? Color.secondary : Color.green)

                if !container.mcpManager.enabledServers.isEmpty {
                    Text("\(container.mcpManager.enabledServers.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .help("MCP Servers: \(container.mcpManager.enabledServers.count) active")
    }
    
    private var modelSelector: some View {
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
    
    private var rightIcons: some View {
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
        }
    }
    
    private var inputRow: some View {
        HStack(spacing: 12) {
            TextField("Ask anything or type / for commands", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...6)
                .focused($isInputFocused)
                .onChange(of: messageText) { _, newValue in
                    showSlashCommands = newValue.hasPrefix("/") && newValue.count > 1
                }
                .onSubmit {
                    onSend()
                }

            Button {
                if isStreaming {
                    onStop()
                } else {
                    onSend()
                }
            } label: {
                Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(isStreaming ? .red : .accentColor)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming)
            .keyboardShortcut(.return, modifiers: [])
        }
    }
    
    private var inputBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(
                LinearGradient(
                    colors: (!messageText.isEmpty || isStreaming) ?
                        [Color.blue.opacity(0.5), Color.purple.opacity(0.5)] :
                        [Color.gray.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: (!messageText.isEmpty || isStreaming) ? 1.5 : 0.75
            )
    }
    
    private var inputShadowColor: Color {
        (!messageText.isEmpty || isStreaming) ? Color.blue.opacity(0.15) : Color.clear
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
}
