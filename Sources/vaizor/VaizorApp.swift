import SwiftUI
import AppKit

extension Notification.Name {
    static let importMCPRequested = Notification.Name("ImportMCPRequested")
}

@main
struct VaizorApp: App {
    @StateObject private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(Color.clear)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Extensions") {
                Button("Import MCP Servers from Folder…") {
                    NotificationCenter.default.post(name: .importMCPRequested, object: nil)
                }
                .keyboardShortcut("I", modifiers: [.command, .shift])
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var container: DependencyContainer
    @StateObject private var conversationManager = ConversationManager()
    @State private var selectedConversation: Conversation?
    @State private var showSettings = false
    @State private var showChatSidebar = true
    @State private var showSettingsSidebar = false
    @State private var showBrowserPanel = false

    @State private var isImportingMCP = false
    @State private var showImportResult = false
    @State private var importResultMessage: String? = nil
    
    @State private var showImportPreview = false
    @State private var parsedServers: [MCPServer] = []
    
    // Settings sidebar state
    @State private var anthropicKey: String = ""
    @State private var openaiKey: String = ""
    @State private var geminiKey: String = ""
    @State private var customKey: String = ""
    @State private var showMCPSettings = false
    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""

    var body: some View {
        ZStack {
            // Background underlays adopt system window backdrop
            Color.clear
                .ignoresSafeArea()
            
            // Main layout
            HStack(spacing: 0) {
                // Left sidebar - Chats
                if showChatSidebar {
                    chatSidebar
                        .frame(width: 280)
                        .padding(.vertical, 8)
                        .background(Material.thin)
                    Divider()
                }

                // Main content
                mainContent

                // Right sidebar - Settings
                if showSettingsSidebar {
                    Divider()
                    settingsSidebar
                        .frame(width: 320)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            if selectedConversation == nil, let first = conversationManager.conversations.first {
                selectedConversation = first
            }
        }
        .sheet(isPresented: $showBrowserPanel) {
            BrowserPanelView(automation: container.browserAutomation)
                .frame(minWidth: 900, minHeight: 700)
        }
        .onReceive(NotificationCenter.default.publisher(for: .importMCPRequested)) { _ in
            Task { await importMCPServers() }
        }
        .alert("Import MCP Servers", isPresented: $showImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResultMessage ?? "")
        }
        .sheet(isPresented: $showImportPreview) {
            ImportPreviewView(
                servers: parsedServers,
                errors: importResultMessage,
                onCommit: { committed in
                    container.mcpManager.commitImported(committed)
                    showImportPreview = false
                    importResultMessage = "Imported: \(committed.count)"
                    showImportResult = true
                },
                onCancel: {
                    showImportPreview = false
                }
            )
            .environmentObject(container)
            .frame(minWidth: 700, minHeight: 500)
        }
    }

    private var chatSidebar: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with logo
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "00976d"))
                            .frame(width: 32, height: 32)

                        Image(systemName: "sparkles")
                            .foregroundColor(Color(hex: "1c1d1f"))
                            .font(.system(size: 14, weight: .bold))
                    }

                    Text("Vaizor")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button {
                        createNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("New Chat")
                }
                .padding()
                .background(Material.ultraThin)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Divider()

                // Sidebar background with subtle glass
                .background(
                    Color.clear
                )

                // Conversations list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(conversationManager.conversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: selectedConversation?.id == conversation.id,
                                onSelect: {
                                    selectedConversation = conversation
                                    conversationManager.updateLastUsed(conversation.id)
                                },
                                onDelete: {
                                    conversationManager.deleteConversation(conversation.id)
                                    if selectedConversation?.id == conversation.id {
                                        selectedConversation = nil
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
            .background(Material.thin)
        }
        .background(
            Material.thin
        )
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            Divider()

            // Content background
            ZStack {
                Color.clear
                    .background(Material.ultraThin)
                    .ignoresSafeArea()
                
                if let conversation = selectedConversation {
                    ChatView(
                        conversationId: conversation.id
                    )
                    .id(conversation.id)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "message")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("No Chat Selected")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Create a new chat to get started")
                            .foregroundStyle(.secondary)

                        Button {
                            createNewChat()
                        } label: {
                            Label("New Chat", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                    .background(Material.ultraThin)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .toolbar {
            // Left side - Sidebar toggle
            ToolbarItem(placement: .navigation) {
                Button {
                    showChatSidebar.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(showChatSidebar ? "Hide Sidebar" : "Show Sidebar")
            }

            // Principal title
            ToolbarItem(placement: .principal) {
                if let conversation = selectedConversation {
                    Text(conversation.title).font(.headline)
                } else {
                    Text("Vaizor").font(.headline)
                }
            }

            // Right side controls
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        showBrowserPanel.toggle()
                    } label: {
                        Image(systemName: "globe")
                    }
                    .help("Open Browser Panel")
                    
                    Button {
                        NotificationCenter.default.post(name: .importMCPRequested, object: nil)
                    } label: {
                        Image(systemName: "tray.and.arrow.down")
                    }
                    .help("Import MCP Servers from Folder…")

                    Button {
                        showSettingsSidebar.toggle()
                    } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .help(showSettingsSidebar ? "Hide Settings" : "Show Settings")
                }
            }
        }
        .background(
            Material.ultraThin
        )
    }

    private var settingsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)

                // API Keys Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("API Keys")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Anthropic")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            SecureField("API key", text: $anthropicKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: anthropicKey) { _, newValue in
                                    container.apiKeys[.anthropic] = newValue
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("OpenAI")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            SecureField("API key", text: $openaiKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: openaiKey) { _, newValue in
                                    container.apiKeys[.openai] = newValue
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Google Gemini")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            SecureField("API key", text: $geminiKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: geminiKey) { _, newValue in
                                    container.apiKeys[.gemini] = newValue
                                }
                        }
                    }
                }

                Divider()

                // Ollama Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ollama")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default Model")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Menu {
                            ForEach(container.availableModels, id: \.self) { model in
                                Button {
                                    defaultOllamaModel = model
                                } label: {
                                    HStack {
                                        Text(model)
                                        if model == defaultOllamaModel {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(defaultOllamaModel.isEmpty ? "Select a model" : defaultOllamaModel)
                                    .font(.caption)
                                    .foregroundStyle(defaultOllamaModel.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Material.ultraThin)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                // MCP Servers
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("MCP Servers")
                            .font(.headline)

                        Spacer()

                        Button {
                            showMCPSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    if container.mcpManager.availableServers.isEmpty {
                        Text("No servers configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            showMCPSettings = true
                        } label: {
                            Label("Add Server", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(container.mcpManager.availableServers) { server in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(container.mcpManager.enabledServers.contains(server.id) ? Color.green : Color.gray)
                                        .frame(width: 6, height: 6)

                                    Text(server.name)
                                        .font(.caption)

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { container.mcpManager.enabledServers.contains(server.id) },
                                        set: { enabled in
                                            if enabled {
                                                Task {
                                                    try? await container.mcpManager.startServer(server)
                                                }
                                            } else {
                                                container.mcpManager.stopServer(server)
                                            }
                                        }
                                    ))
                                    .scaleEffect(0.7)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Material.thin)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(8)
        }
        .background(Material.ultraThin)
        .sheet(isPresented: $showMCPSettings) {
            MCPSettingsView()
                .environmentObject(container)
                .background(Material.thin)
        }
        .background(
            Material.thin
        )
        .onAppear {
            anthropicKey = container.apiKeys[.anthropic] ?? ""
            openaiKey = container.apiKeys[.openai] ?? ""
            geminiKey = container.apiKeys[.gemini] ?? ""
            customKey = container.apiKeys[.custom] ?? ""

            if container.currentProvider == .ollama {
                Task {
                    await container.loadModelsForCurrentProvider()
                }
            }
        }
    }

    private func createNewChat() {
        let newConversation = conversationManager.createConversation()
        selectedConversation = newConversation
    }
    
    @MainActor
    private func importMCPServers() async {
        guard !isImportingMCP else { return }
        isImportingMCP = true
        defer { isImportingMCP = false }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        if panel.runModal() != .OK { return }
        guard let folder = panel.url else { return }

        // Build LLM config and provider
        let provider = container.createLLMProvider()
        let model = container.availableModels.first ?? container.currentProvider.defaultModels.first ?? ""
        let config = LLMConfiguration(provider: container.currentProvider, model: model, temperature: 0.3, maxTokens: 2048)

        let parsed = await container.mcpManager.parseUnstructured(from: folder, config: config, provider: provider)
        self.parsedServers = parsed.servers
        self.importResultMessage = parsed.errors.isEmpty ? nil : parsed.errors.prefix(3).joined(separator: "\n")
        self.showImportPreview = true
    }
}

// Compact settings view for sidebar
struct SettingsSidebarView: View {
    @EnvironmentObject var container: DependencyContainer
    @State private var anthropicKey: String = ""
    @State private var openaiKey: String = ""
    @State private var geminiKey: String = ""
    @State private var customKey: String = ""
    @State private var showMCPSettings = false
    @State private var ollamaModelRefreshTrigger = false
    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)

                // API Keys Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("API Keys")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Anthropic")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            SecureField("API key", text: $anthropicKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: anthropicKey) { _, newValue in
                                    container.apiKeys[.anthropic] = newValue
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("OpenAI")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            SecureField("API key", text: $openaiKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: openaiKey) { _, newValue in
                                    container.apiKeys[.openai] = newValue
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Google Gemini")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            SecureField("API key", text: $geminiKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: geminiKey) { _, newValue in
                                    container.apiKeys[.gemini] = newValue
                                }
                        }
                    }
                }

                Divider()

                // Ollama Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ollama")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default Model")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Menu {
                            ForEach(container.availableModels, id: \.self) { model in
                                Button {
                                    defaultOllamaModel = model
                                } label: {
                                    HStack {
                                        Text(model)
                                        if model == defaultOllamaModel {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(defaultOllamaModel.isEmpty ? "Select a model" : defaultOllamaModel)
                                    .font(.caption)
                                    .foregroundStyle(defaultOllamaModel.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Material.ultraThin)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                // MCP Servers
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("MCP Servers")
                            .font(.headline)

                        Spacer()

                        Button {
                            showMCPSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    if container.mcpManager.availableServers.isEmpty {
                        Text("No servers configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            showMCPSettings = true
                        } label: {
                            Label("Add Server", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(container.mcpManager.availableServers) { server in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(container.mcpManager.enabledServers.contains(server.id) ? Color.green : Color.gray)
                                        .frame(width: 6, height: 6)

                                    Text(server.name)
                                        .font(.caption)

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { container.mcpManager.enabledServers.contains(server.id) },
                                        set: { enabled in
                                            if enabled {
                                                Task {
                                                    try? await container.mcpManager.startServer(server)
                                                }
                                            } else {
                                                container.mcpManager.stopServer(server)
                                            }
                                        }
                                    ))
                                    .scaleEffect(0.7)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Material.thin)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(8)
        }
        .background(Material.ultraThin)
        .sheet(isPresented: $showMCPSettings) {
            MCPSettingsView()
                .environmentObject(container)
                .background(Material.thin)
        }
        .background(
            Material.thin
        )
        .onAppear {
            anthropicKey = container.apiKeys[.anthropic] ?? ""
            openaiKey = container.apiKeys[.openai] ?? ""
            geminiKey = container.apiKeys[.gemini] ?? ""
            customKey = container.apiKeys[.custom] ?? ""

            if container.currentProvider == .ollama {
                Task {
                    await container.loadModelsForCurrentProvider()
                }
            }
        }
    }
}

struct ImportPreviewView: View {
    @EnvironmentObject var container: DependencyContainer

    // Initial parsed servers (value)
    let servers: [MCPServer]
    let errors: String?
    let onCommit: ([MCPServer]) -> Void
    let onCancel: () -> Void

    @State private var drafts: [DraftServer] = []

    struct DraftServer: Identifiable {
        var id: String
        var name: String
        var description: String
        var command: String
        var argsText: String
        var path: String
        var isTesting: Bool = false
        var testSuccess: Bool? = nil
        var testMessage: String? = nil

        init(_ s: MCPServer) {
            self.id = s.id
            self.name = s.name
            self.description = s.description
            self.command = s.command
            self.argsText = s.args.joined(separator: " ")
            self.path = s.path.path
        }

        func toServer() -> MCPServer {
            let args = argsText.split(separator: " ").map(String.init)
            return MCPServer(id: id, name: name, description: description, command: command, args: args, path: URL(fileURLWithPath: path))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Import MCP Servers")
                    .font(.title2).bold()
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Import") { onCommit(drafts.map { $0.toServer() }) }
                    .keyboardShortcut(.return)
                    .disabled(drafts.isEmpty)
            }
            .padding()
            .background(Material.thin)

            Divider()

            HStack(alignment: .top, spacing: 12) {
                List {
                    ForEach(drafts.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("Name", text: $drafts[i].name)
                                    .font(.headline)
                                Spacer()
                                Button {
                                    testConnection(index: i)
                                } label: {
                                    if drafts[i].isTesting {
                                        ProgressView().scaleEffect(0.7)
                                    } else if let ok = drafts[i].testSuccess {
                                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(ok ? .green : .red)
                                    } else {
                                        Text("Test")
                                    }
                                }
                                .buttonStyle(.bordered)
                            }

                            TextField("Description", text: $drafts[i].description)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                Text("Command:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("Command", text: $drafts[i].command)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Args", text: $drafts[i].argsText)
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack(spacing: 8) {
                                Text("Path:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("/absolute/path", text: $drafts[i].path)
                                    .textFieldStyle(.roundedBorder)
                                Button("Choose…") { choosePath(index: i) }
                            }

                            if let msg = drafts[i].testMessage, !msg.isEmpty {
                                Text(msg)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                if let errors, !errors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Parser Notes").font(.headline)
                        ScrollView { Text(errors).font(.caption) }
                    }
                    .frame(width: 260)
                }
            }
            .padding(12)
        }
        .onAppear {
            drafts = servers.map(DraftServer.init)
        }
    }

    private func testConnection(index: Int) {
        drafts[index].isTesting = true
        drafts[index].testMessage = nil
        drafts[index].testSuccess = nil
        let server = drafts[index].toServer()
        Task {
            let (success, message) = await container.mcpManager.testConnection(server)
            await MainActor.run {
                drafts[index].isTesting = false
                drafts[index].testSuccess = success
                drafts[index].testMessage = message
            }
        }
    }

    private func choosePath(index: Int) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            drafts[index].path = url.path
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "00976d"))
                    .frame(width: 36, height: 36)

                Image(systemName: "message.fill")
                    .foregroundColor(Color(hex: "1c1d1f"))
                    .font(.system(size: 14))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if !conversation.summary.isEmpty {
                    Text(conversation.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(conversation.lastUsedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text("\(conversation.messageCount) messages")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(Material.ultraThin))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

