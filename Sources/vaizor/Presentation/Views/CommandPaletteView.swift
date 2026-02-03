import SwiftUI

struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var container: DependencyContainer
    @State private var searchText: String = ""
    @FocusState private var isFocused: Bool
    
    @State private var selectedIndex: Int = 0
    
    private var filteredCommands: [PaletteCommand] {
        // Access container properties on MainActor
        let configuredProviders = container.configuredProviders
        let availableServers = container.mcpManager.availableServers
        let enabledServers = container.mcpManager.enabledServers
        
        let allCommands = PaletteCommand.allCommands(
            configuredProviders: configuredProviders,
            availableServers: availableServers,
            enabledServers: enabledServers,
            container: container
        )
        
        if searchText.isEmpty {
            return allCommands
        }
        return allCommands.filter { command in
            command.title.localizedCaseInsensitiveContains(searchText) ||
            command.description.localizedCaseInsensitiveContains(searchText) ||
            command.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Type a command or search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isFocused)
                    .onSubmit {
                        if !filteredCommands.isEmpty {
                            executeCommand(filteredCommands[selectedIndex])
                        }
                    }
                    .onKeyPress { press in
                        return handleKeyPress(press)
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            Divider()
            
            // Command list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                        PaletteCommandRow(
                            command: command,
                            isSelected: index == selectedIndex,
                            onSelect: {
                                executeCommand(command)
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 600, height: 500)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .onAppear {
            isFocused = true
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
    }
    
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow:
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        case .downArrow:
            if selectedIndex < filteredCommands.count - 1 {
                selectedIndex += 1
            }
            return .handled
        case .escape:
            isPresented = false
            return .handled
        default:
            return .ignored
        }
    }
    
    private func executeCommand(_ command: PaletteCommand) {
        command.action()
        isPresented = false
    }
}

struct PaletteCommand: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let keywords: [String]
    let action: () -> Void
    
    static func allCommands(
        configuredProviders: [LLMProvider],
        availableServers: [MCPServer],
        enabledServers: Set<String>,
        container: DependencyContainer
    ) -> [PaletteCommand] {
        var commands: [PaletteCommand] = []
        
        // Navigation commands
        commands.append(PaletteCommand(
            title: "New Chat",
            description: "Create a new conversation",
            icon: "square.and.pencil",
            keywords: ["new", "chat", "conversation"],
            action: {
                NotificationCenter.default.post(name: .newChat, object: nil)
            }
        ))
        
        commands.append(PaletteCommand(
            title: "Open Settings",
            description: "Open application settings",
            icon: "gearshape",
            keywords: ["settings", "preferences", "config"],
            action: {
                NotificationCenter.default.post(name: .toggleSettings, object: nil)
            }
        ))

        commands.append(PaletteCommand(
            title: "Export Conversation",
            description: "Export the current conversation to a zip file",
            icon: "square.and.arrow.up",
            keywords: ["export", "backup", "conversation"],
            action: {
                NotificationCenter.default.post(name: .exportConversation, object: nil)
            }
        ))

        commands.append(PaletteCommand(
            title: "Import Conversation",
            description: "Import a conversation from a zip file",
            icon: "square.and.arrow.down",
            keywords: ["import", "restore", "conversation"],
            action: {
                NotificationCenter.default.post(name: .importConversation, object: nil)
            }
        ))
        
        // Model switching
        for provider in configuredProviders {
            let providerCopy = provider
            commands.append(PaletteCommand(
                title: "Switch to \(provider.shortDisplayName)",
                description: "Change default provider to \(provider.displayName)",
                icon: provider == .ollama ? "sparkles" : (provider == .anthropic ? "sparkles" : "brain"),
                keywords: [provider.rawValue, provider.shortDisplayName.lowercased(), "switch", "change"],
                action: {
                    Task { @MainActor in
                        container.currentProvider = providerCopy
                    }
                }
            ))
        }
        
        // MCP Server commands
        for server in availableServers {
            let isEnabled = enabledServers.contains(server.id)
            let serverCopy = server
            commands.append(PaletteCommand(
                title: "\(isEnabled ? "Disable" : "Enable") \(server.name)",
                description: "Toggle MCP server: \(server.description.isEmpty ? server.name : server.description)",
                icon: isEnabled ? "power" : "power.off",
                keywords: [server.name.lowercased(), "mcp", "server", isEnabled ? "disable" : "enable"],
                action: {
                    Task { @MainActor in
                        if isEnabled {
                            await container.mcpManager.stopServer(serverCopy)
                        } else {
                            try? await container.mcpManager.startServer(serverCopy)
                        }
                    }
                }
            ))
        }
        
        // View commands
        commands.append(PaletteCommand(
            title: "Toggle Sidebar",
            description: "Show or hide the sidebar",
            icon: "sidebar.left",
            keywords: ["sidebar", "toggle", "hide", "show"],
            action: {
                NotificationCenter.default.post(name: .toggleChatSidebar, object: nil)
            }
        ))
        
        commands.append(PaletteCommand(
            title: "Scroll to Top",
            description: "Jump to the beginning of the conversation",
            icon: "arrow.up",
            keywords: ["scroll", "top", "beginning"],
            action: {
                NotificationCenter.default.post(name: .scrollToTop, object: nil)
            }
        ))
        
        commands.append(PaletteCommand(
            title: "Scroll to Bottom",
            description: "Jump to the end of the conversation",
            icon: "arrow.down",
            keywords: ["scroll", "bottom", "end"],
            action: {
                NotificationCenter.default.post(name: .scrollToBottom, object: nil)
            }
        ))
        
        return commands
    }
}

struct PaletteCommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: command.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .white : ThemeColors.accent)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                    
                    Text(command.description)
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelected ? ThemeColors.accent : Color.clear
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
