import SwiftUI

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case intelligence = "Intelligence"
    case mcpServers = "MCP Servers"
    case appearance = "Appearance"
    case shortcuts = "Shortcuts"
    case about = "About"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .intelligence: return "sparkles"
        case .mcpServers: return "server.rack"
        case .appearance: return "paintbrush"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }
}

struct ComprehensiveSettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var conversationManager: ConversationManager
    @State private var selectedCategory: SettingsCategory = .general

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left sidebar (wider for better category names display)
                sidebar
                    .frame(width: min(max(180, geometry.size.width * 0.28), geometry.size.width * 0.32))

                Divider()

                // Right content (flexible, takes remaining space with word wrapping)
                contentView
                    .frame(minWidth: 300, maxWidth: .infinity)
            }
        }
        .frame(minWidth: 460, minHeight: 400)
        .background(.thinMaterial)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Settings title
            HStack {
                Text("Settings")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(SettingsCategory.allCases) { category in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = category
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(selectedCategory == category ? Color(hex: "00976d") : .secondary)
                                    .symbolRenderingMode(.hierarchical)
                                    .frame(width: 20)

                                Text(category.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(selectedCategory == category ? .primary : .secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                Group {
                                    if selectedCategory == category {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hex: "00976d").opacity(0.12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color(hex: "00976d").opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with title
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "00976d"), Color(hex: "00976d").opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(hex: "00976d").opacity(0.3), radius: 4, y: 2)

                        Image(systemName: selectedCategory.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(hex: "eeeeee"))
                            .symbolRenderingMode(.hierarchical)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedCategory.rawValue)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(categoryDescription)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal, 20)

                // Category-specific content
                Group {
                    switch selectedCategory {
                    case .general:
                        GeneralSettingsView()
                            .environmentObject(conversationManager)
                    case .intelligence:
                        IntelligenceSettingsView()
                            .environmentObject(container)
                    case .mcpServers:
                        MCPServersSettingsView()
                            .environmentObject(container)
                    case .appearance:
                        AppearanceSettingsView()
                    case .shortcuts:
                        ShortcutsSettingsView()
                    case .about:
                        AboutSettingsView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private var categoryDescription: String {
        switch selectedCategory {
        case .general:
            return "Configure general app settings"
        case .intelligence:
            return "Manage AI providers and models"
        case .mcpServers:
            return "Configure MCP server connections"
        case .appearance:
            return "Customize the app's look and feel"
        case .shortcuts:
            return "View and customize keyboard shortcuts"
        case .about:
            return "About Vaizor"
        }
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @EnvironmentObject var conversationManager: ConversationManager
    @AppStorage("windowTabsIndependentSidebar") private var windowTabsIndependentSidebar = false
    @AppStorage("automaticallyUnlockFiles") private var automaticallyUnlockFiles = false
    @AppStorage("fileExtensions") private var fileExtensions = "Show All"
    @AppStorage("sidebarPosition") private var sidebarPosition: SidebarPosition = .left
    
    private func getConversationManager() -> ConversationManager {
        return conversationManager
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sidebar Position Setting
            VStack(alignment: .leading, spacing: 8) {
                Label("Sidebar Position", systemImage: "sidebar.left")
                    .font(.subheadline)
                
                Picker("", selection: $sidebarPosition) {
                    Text("Left").tag(SidebarPosition.left)
                    Text("Right").tag(SidebarPosition.right)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
            
            Divider()
            
            // Organization
            VStack(alignment: .leading, spacing: 12) {
                Text("Organization")
                    .font(.headline)
                
                NavigationLink {
                    FolderManagementView(conversationManager: getConversationManager())
                } label: {
                    Label("Folders", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                
                NavigationLink {
                    TemplateManagementView(conversationManager: getConversationManager())
                } label: {
                    Label("Templates", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // Data tools
            VStack(alignment: .leading, spacing: 12) {
                Text("Data")
                    .font(.headline)

                Text("Export or import conversations as zip archives.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        NotificationCenter.default.post(name: .exportConversation, object: nil)
                    } label: {
                        Label("Export Conversation", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        NotificationCenter.default.post(name: .importConversation, object: nil)
                    } label: {
                        Label("Import Conversation", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Divider()
            
            // General Settings
            VStack(alignment: .leading, spacing: 8) {
                Label("Find navigator detail", systemImage: "magnifyingglass")
                    .font(.subheadline)
                
                Picker("", selection: $fileExtensions) {
                    Text("Up to 3 Lines").tag("Up to 3 Lines")
                    Text("Up to 5 Lines").tag("Up to 5 Lines")
                    Text("Unlimited").tag("Unlimited")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Issue navigator detail", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                
                Picker("", selection: $fileExtensions) {
                    Text("Up to 3 Lines").tag("Up to 3 Lines")
                    Text("Up to 5 Lines").tag("Up to 5 Lines")
                    Text("Unlimited").tag("Unlimited")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
            
            Toggle(isOn: $windowTabsIndependentSidebar) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Window tabs have independent sidebar widths")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Each window tab can use a different width for its navigator and inspector. The tab bar will move when changing tabs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(1.5)
                }
            }

            Toggle(isOn: $automaticallyUnlockFiles) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatically unlock files")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Unlock locked files without prompting when editing. This is useful in projects using Perforce.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(1.5)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Label("File extensions", systemImage: "doc.text")
                    .font(.subheadline)
                
                Picker("", selection: $fileExtensions) {
                    Text("Show All").tag("Show All")
                    Text("Hide All").tag("Hide All")
                    Text("Show Only Unknown").tag("Show Only Unknown")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
            
            Divider()
            
            // Issues Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Issues")
                    .font(.headline)
                
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Issue presentation", systemImage: "list.bullet")
                                .font(.subheadline)
                            
                            Picker("", selection: Binding(
                                get: { "Show Inline" },
                                set: { _ in
                                    NotificationCenter.default.post(
                                        name: .showUnderConstructionToast,
                                        object: "Issue Presentation Setting"
                                    )
                                }
                            )) {
                                Text("Show Inline").tag("Show Inline")
                                Text("Show in Navigator").tag("Show in Navigator")
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 200)
                        }
                        
                        Toggle(isOn: Binding(
                            get: { true },
                            set: { _ in
                                NotificationCenter.default.post(
                                    name: .showUnderConstructionToast,
                                    object: "Show Live Issues Setting"
                                )
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show live issues")
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Updates warnings and errors displayed in files as they are edited, before the scheme is built.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(1.5)
                            }
                        }
                        
                        Toggle(isOn: Binding(
                            get: { true },
                            set: { _ in
                                NotificationCenter.default.post(
                                    name: .showUnderConstructionToast,
                                    object: "Stop Build on First Error Setting"
                                )
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Stop build on first error")
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Cancels all active and scheduled build tasks when any tasks reports an error.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(1.5)
                            }
                        }
                        
                        HStack {
                            Text("\"Don't ask me\" warnings")
                            Spacer()
                            Button("Reset All") {
                                NotificationCenter.default.post(
                                    name: .showUnderConstructionToast,
                                    object: "Reset Warnings"
                                )
                            }
                            .buttonStyle(.bordered)
                        }
                }
            }
        }
    }
}

// MARK: - Intelligence Settings (LLM Configuration)
struct IntelligenceSettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @State private var anthropicKey: String = ""
    @State private var openaiKey: String = ""
    @State private var geminiKey: String = ""
    @State private var customKey: String = ""
    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""
    @AppStorage("defaultTemperature") private var defaultTemperature: Double = 0.7
    @AppStorage("defaultMaxTokens") private var defaultMaxTokens: Int = 4096
    @AppStorage("enableChainOfThought") private var enableChainOfThought = false
    @AppStorage("enablePromptEnhancement") private var enablePromptEnhancement = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Provider Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Provider")
                    .font(.headline)

                Picker("Provider", selection: $container.currentProvider) {
                    ForEach(LLMProvider.allCases, id: \.self) { provider in
                        Text(provider.shortDisplayName).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: container.currentProvider) { _, _ in
                    Task {
                        await container.loadModelsForCurrentProvider()
                    }
                }
            }
            
            Divider()
            
            // API Keys Section
            VStack(alignment: .leading, spacing: 12) {
                Text("API Keys")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Anthropic Claude", systemImage: "sparkles")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        SecureField("Enter API key", text: $anthropicKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                            .onChange(of: anthropicKey) { _, newValue in
                                container.apiKeys[.anthropic] = newValue
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("OpenAI", systemImage: "brain")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        SecureField("Enter API key", text: $openaiKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                            .onChange(of: openaiKey) { _, newValue in
                                container.apiKeys[.openai] = newValue
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Google Gemini", systemImage: "globe")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        SecureField("Enter API key", text: $geminiKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                            .onChange(of: geminiKey) { _, newValue in
                                container.apiKeys[.gemini] = newValue
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Custom Provider", systemImage: "server.rack")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        SecureField("Enter API key", text: $customKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                            .onChange(of: customKey) { _, newValue in
                                container.apiKeys[.custom] = newValue
                            }
                    }
                }
            }
            
            Divider()
            
            // Ollama Settings
            if container.currentProvider == .ollama {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ollama Configuration")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Default Model", systemImage: "circle.grid.3x3.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
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
                                        .foregroundStyle(defaultOllamaModel.isEmpty ? .secondary : .primary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            
                            Text("Ollama runs locally and doesn't require an API key")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Divider()
            
            // Model Parameters
            VStack(alignment: .leading, spacing: 12) {
                Text("Model Parameters")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Temperature: \(defaultTemperature, specifier: "%.1f")", systemImage: "thermometer")
                            .font(.subheadline)
                        
                        Slider(value: $defaultTemperature, in: 0...2, step: 0.1)
                            .frame(maxWidth: .infinity)

                        Text("Controls randomness. Lower values make responses more focused and deterministic.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Max Tokens: \(defaultMaxTokens)", systemImage: "number")
                            .font(.subheadline)
                        
                        Slider(value: Binding(
                            get: { Double(defaultMaxTokens) },
                            set: { defaultMaxTokens = Int($0) }
                        ), in: 256...8192, step: 256)
                            .frame(maxWidth: .infinity)

                        Text("Maximum number of tokens to generate in the response.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Toggle(isOn: $enableChainOfThought) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Chain of Thought")
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Show intermediate reasoning steps in responses.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(1.5)
                        }
                    }

                    Toggle(isOn: $enablePromptEnhancement) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-Enhance Prompts")
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Automatically optimize your prompts for maximum clarity and effectiveness before sending to the model.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(1.5)
                        }
                    }
                }
            }
        }
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

// MARK: - MCP Servers Settings
struct MCPServersSettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @State private var showMCPSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MCP Servers")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showMCPSettings = true
                } label: {
                    Label("Manage Servers", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
            }
            
            if container.mcpManager.availableServers.isEmpty {
                VStack(spacing: 8) {
                    MCPIconManager.icon()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Text("No MCP servers configured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("Add MCP servers to extend Ollama's capabilities")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        showMCPSettings = true
                    } label: {
                        Label("Add MCP Server", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(container.mcpManager.availableServers) { server in
                        MCPServerToggleRow(
                            server: server,
                            isEnabled: container.mcpManager.enabledServers.contains(server.id),
                            onToggle: { enabled in
                                if enabled {
                                    Task {
                                        do {
                                            AppLogger.shared.log("User toggled MCP server \(server.name) ON from settings", level: .info)
                                            try await container.mcpManager.startServer(server)
                                            // State updates automatically via @Published (errors cleared on success)
                                        } catch {
                                            AppLogger.shared.logError(error, context: "User failed to start MCP server \(server.name) from settings")
                                            // Error is stored in serverErrors and state is cleaned up automatically
                                        }
                                    }
                                } else {
                                    AppLogger.shared.log("User toggled MCP server \(server.name) OFF from settings", level: .info)
                                    container.mcpManager.stopServer(server)
                                    // State updates automatically via @Published
                                }
                            }
                        )
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .sheet(isPresented: $showMCPSettings) {
            MCPSettingsView()
                .environmentObject(container)
        }
    }
}

// MARK: - Appearance Settings
struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance = "System"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Theme", systemImage: "paintbrush")
                    .font(.headline)
                
                Picker("", selection: $appearance) {
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                    Text("System").tag("System")
                }
                .pickerStyle(.segmented)
                .onChange(of: appearance) { _, newValue in
                    applyTheme(newValue)
                }
            }
            
            Text("Choose your preferred color scheme. System will follow your macOS appearance settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            applyTheme(appearance)
        }
    }
    
    private func applyTheme(_ theme: String) {
        switch theme {
        case "Light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "Dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case "System":
            NSApp.appearance = nil // Use system default
        default:
            NSApp.appearance = nil
        }
    }
}

// MARK: - Shortcuts Settings
struct ShortcutsSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ShortcutRow(action: "New Chat", shortcut: "⌘N")
                ShortcutRow(action: "Open Settings", shortcut: "⌘,")
                ShortcutRow(action: "Send Message", shortcut: "⏎")
                ShortcutRow(action: "Stop Streaming", shortcut: "⌘.")
            }
        }
    }
}

struct ShortcutRow: View {
    let action: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - About Settings
struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "00976d"))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(hex: "eeeeee"))
                        .font(.system(size: 32, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vaizor")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("A multi-modal LLM client with MCP support")
                    .font(.subheadline)
                
                Text("Vaizor enables seamless interaction with various LLM providers and extends capabilities through MCP (Model Context Protocol) servers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
