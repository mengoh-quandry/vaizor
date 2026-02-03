import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case intelligence = "Intelligence"
    case behavior = "Behavior"
    case mcpServers = "MCP Servers"
    case extensions = "Extensions"
    case appearance = "Appearance"
    case privacy = "Privacy"
    case security = "Security"
    case shortcuts = "Shortcuts"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .intelligence: return "sparkles"
        case .behavior: return "slider.horizontal.3"
        case .mcpServers: return "server.rack"
        case .extensions: return "puzzlepiece.extension"
        case .appearance: return "paintbrush"
        case .privacy: return "lock.shield"
        case .security: return "shield.checkered"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }
}

struct ComprehensiveSettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var conversationManager: ConversationManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategory: SettingsCategory = .general
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    // Adaptive colors for light/dark mode support
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    // Legacy color references (computed for adaptive theming)
    private var darkBase: Color { colors.background }
    private var darkSurface: Color { colors.surface }
    private var darkBorder: Color { colors.border }

    // Search-related computed properties
    private var filteredCategories: [SettingsCategory] {
        guard !searchText.isEmpty else {
            return SettingsCategory.allCases
        }
        let query = searchText.lowercased()
        return SettingsCategory.allCases.filter { category in
            // Match category name
            if category.rawValue.lowercased().contains(query) {
                return true
            }
            // Match category keywords
            return categorySearchKeywords(for: category).contains { $0.lowercased().contains(query) }
        }
    }

    private func categorySearchKeywords(for category: SettingsCategory) -> [String] {
        switch category {
        case .general:
            return ["sidebar", "interface", "folders", "templates", "export", "import", "data"]
        case .intelligence:
            return ["api", "key", "provider", "model", "anthropic", "openai", "gemini", "ollama", "temperature", "tokens", "system prompt"]
        case .behavior:
            return ["enter", "scroll", "stream", "thinking", "urls", "paste"]
        case .mcpServers:
            return ["mcp", "server", "tools", "protocol", "context"]
        case .extensions:
            return ["extension", "install", "marketplace", "plugin", "addon", "package", "registry", "update", "runtime", "node", "python"]
        case .appearance:
            return ["theme", "dark", "light", "mode", "color"]
        case .privacy:
            return ["redaction", "history", "clear", "cost", "tokens", "data", "cache"]
        case .security:
            return ["edr", "threat", "detection", "audit", "logging", "host", "firewall", "alert", "injection", "malware"]
        case .shortcuts:
            return ["keyboard", "shortcut", "hotkey", "key"]
        case .about:
            return ["version", "vaizor", "info"]
        }
    }

    private func highlightedText(_ text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard !query.isEmpty else { return attributed }

        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()

        var searchStartIndex = lowercasedText.startIndex
        while let range = lowercasedText.range(of: lowercasedQuery, range: searchStartIndex..<lowercasedText.endIndex) {
            // Convert String range to AttributedString range
            let startOffset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound)
            let endOffset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.upperBound)

            let attrStart = attributed.index(attributed.startIndex, offsetByCharacters: startOffset)
            let attrEnd = attributed.index(attributed.startIndex, offsetByCharacters: endOffset)
            attributed[attrStart..<attrEnd].backgroundColor = ThemeColors.accent.opacity(0.3)
            attributed[attrStart..<attrEnd].foregroundColor = .white

            searchStartIndex = range.upperBound
        }

        return attributed
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left sidebar
                sidebar
                    .frame(width: min(max(180, geometry.size.width * 0.28), geometry.size.width * 0.32))

                Rectangle()
                    .fill(ThemeColors.gradientDivider(horizontal: false))
                    .frame(width: 1)

                // Right content
                contentView
                    .frame(minWidth: 300, maxWidth: .infinity)
            }
        }
        .frame(minWidth: 500, minHeight: 450)
        .background(ThemeColors.surfaceGradient)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            HStack {
                Text("Settings")
                    .font(VaizorTypography.h3Rounded)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(VaizorTypography.label)
                        .foregroundStyle(.secondary)
                        .frame(width: VaizorSpacing.lg, height: VaizorSpacing.lg)
                        .background(darkSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Close Settings")
                .accessibilityLabel("Close settings")
            }
            .padding(.horizontal, VaizorSpacing.md)
            .padding(.vertical, VaizorSpacing.sm + 2)

            // Search bar
            HStack(spacing: VaizorSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(VaizorTypography.label)
                    .foregroundStyle(searchText.isEmpty ? ThemeColors.textSecondary : ThemeColors.accent)

                TextField("Search settings...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(VaizorTypography.label)
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(VaizorTypography.label)
                            .foregroundStyle(Color(hex: "606060"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, VaizorSpacing.xs + 2)
            .padding(.vertical, VaizorSpacing.xs)
            .background(darkSurface)
            .cornerRadius(VaizorSpacing.radiusMd)
            .overlay(
                RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd)
                    .stroke(isSearchFocused ? Color(hex: "00976d").opacity(0.5) : darkBorder, lineWidth: 1)
            )
            .padding(.horizontal, VaizorSpacing.xs + 2)
            .padding(.bottom, VaizorSpacing.xs)

            Rectangle()
                .fill(darkBorder)
                .frame(height: 1)

            ScrollView {
                VStack(spacing: VaizorSpacing.xxxs) {
                    if filteredCategories.isEmpty {
                        VStack(spacing: VaizorSpacing.xs) {
                            Image(systemName: "magnifyingglass")
                                .font(VaizorTypography.h1)
                                .foregroundStyle(Color(hex: "606060"))
                            Text("No results found")
                                .font(VaizorTypography.label)
                                .foregroundStyle(Color(hex: "808080"))
                            Text("Try a different search term")
                                .font(VaizorTypography.caption)
                                .foregroundStyle(Color(hex: "606060"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VaizorSpacing.lg + 6)
                    } else {
                        ForEach(filteredCategories) { category in
                            SettingsCategoryButton(
                                category: category,
                                isSelected: selectedCategory == category,
                                searchText: searchText,
                                highlightedText: highlightedText
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, VaizorSpacing.xs + 2)
                .padding(.vertical, VaizorSpacing.xs + 2)
            }
        }
        .background(darkBase)
        .onChange(of: filteredCategories) { _, newCategories in
            // Auto-select first result if current selection is filtered out
            if !newCategories.contains(selectedCategory), let first = newCategories.first {
                selectedCategory = first
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VaizorSpacing.md) {
                // Header with title
                HStack(spacing: VaizorSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd)
                            .fill(Color(hex: "00976d"))
                            .frame(width: 36, height: 36)

                        Image(systemName: selectedCategory.icon)
                            .font(VaizorTypography.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: VaizorSpacing.xxxs) {
                        Text(selectedCategory.rawValue)
                            .font(VaizorTypography.h2Rounded)
                            .foregroundStyle(.white)

                        Text(categoryDescription)
                            .font(VaizorTypography.label)
                            .foregroundStyle(Color(hex: "808080"))
                    }

                    Spacer()
                }
                .padding(.horizontal, VaizorSpacing.lg - 4)
                .padding(.top, VaizorSpacing.lg - 4)

                Rectangle()
                    .fill(darkBorder)
                    .frame(height: 1)
                    .padding(.horizontal, VaizorSpacing.lg - 4)

                // Category-specific content
                Group {
                    switch selectedCategory {
                    case .general:
                        GeneralSettingsView()
                            .environmentObject(conversationManager)
                    case .intelligence:
                        IntelligenceSettingsView()
                            .environmentObject(container)
                    case .behavior:
                        BehaviorSettingsView()
                    case .mcpServers:
                        MCPServersSettingsView()
                            .environmentObject(container)
                    case .extensions:
                        ExtensionsSettingsView()
                            .environmentObject(container)
                    case .appearance:
                        AppearanceSettingsView()
                    case .privacy:
                        PrivacySettingsView()
                    case .security:
                        SecuritySettingsView()
                    case .shortcuts:
                        ShortcutsSettingsView()
                    case .about:
                        AboutSettingsView()
                    }
                }
                .padding(.horizontal, VaizorSpacing.lg - 4)
                .padding(.bottom, VaizorSpacing.lg - 4)
            }
        }
        .background(darkBase)
    }

    private var categoryDescription: String {
        switch selectedCategory {
        case .general:
            return "Configure general app settings"
        case .intelligence:
            return "Manage AI providers and models"
        case .behavior:
            return "Customize input and output behavior"
        case .mcpServers:
            return "Configure MCP server connections"
        case .extensions:
            return "Browse and install MCP extensions"
        case .appearance:
            return "Customize the app's look and feel"
        case .privacy:
            return "Manage your data and privacy"
        case .security:
            return "AI Endpoint Detection & Response"
        case .shortcuts:
            return "View and customize keyboard shortcuts"
        case .about:
            return "About Vaizor"
        }
    }
}

// MARK: - Settings Category Button with Polish

struct SettingsCategoryButton: View {
    let category: SettingsCategory
    let isSelected: Bool
    let searchText: String
    let highlightedText: (String, String) -> AttributedString
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: VaizorSpacing.xs + 2) {
                // Icon with glow when selected
                Image(systemName: category.icon)
                    .font(VaizorTypography.bodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? ThemeColors.accent : ThemeColors.textSecondary)
                    .frame(width: 18)
                    .shadow(color: isSelected ? ThemeColors.accentGlow : .clear, radius: 4, y: 0)

                if searchText.isEmpty {
                    Text(category.rawValue)
                        .font(VaizorTypography.bodySmall)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .white : Color(hex: "a0a0a0"))
                } else {
                    Text(highlightedText(category.rawValue, searchText))
                        .font(VaizorTypography.bodySmall)
                        .fontWeight(isSelected ? .semibold : .regular)
                }

                Spacer(minLength: 0)

                // Selection indicator
                if isSelected {
                    Circle()
                        .fill(ThemeColors.accent)
                        .frame(width: 5, height: 5)
                        .shadow(color: ThemeColors.accentGlow, radius: 3, y: 0)
                }
            }
            .padding(.horizontal, VaizorSpacing.sm)
            .padding(.vertical, VaizorSpacing.xs + 1)
            .background(
                RoundedRectangle(cornerRadius: VaizorSpacing.radiusSm)
                    .fill(backgroundColor)
            )
            // Top highlight for selected state
            .overlay(
                isSelected ?
                RoundedRectangle(cornerRadius: VaizorSpacing.radiusSm)
                    .stroke(ThemeColors.borderHighlight, lineWidth: 0.5)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                : nil
            )
            // Selection border glow
            .overlay(
                RoundedRectangle(cornerRadius: VaizorSpacing.radiusSm)
                    .stroke(isSelected ? ThemeColors.accent.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .shadow(color: isSelected ? ThemeColors.selectedGlow : (isHovered ? ThemeColors.shadowLight : .clear), radius: isHovered ? 3 : 0, y: isHovered ? 1 : 0)
        }
        .buttonStyle(.plain)
        .offset(y: isHovered && !isSelected ? -1 : 0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("\(category.rawValue) settings")
    }

    private var backgroundColor: Color {
        if isSelected {
            return ThemeColors.accent.opacity(0.15)
        } else if isHovered {
            return ThemeColors.hoverBackground.opacity(0.5)
        }
        return .clear
    }
}

// MARK: - Dark Theme Colors (shared) - Using ThemeColors
private let settingsDarkBase = ThemeColors.darkBase
private let settingsDarkSurface = ThemeColors.darkSurface
private let settingsDarkBorder = ThemeColors.darkBorder
private let settingsTextPrimary = ThemeColors.textPrimary
private let settingsTextSecondary = ThemeColors.textSecondary
private let settingsAccent = ThemeColors.accent

// MARK: - General Settings
struct GeneralSettingsView: View {
    @EnvironmentObject var conversationManager: ConversationManager
    @AppStorage("sidebarPosition") private var sidebarPosition: SidebarPosition = .left

    private func getConversationManager() -> ConversationManager {
        return conversationManager
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VaizorSpacing.md) {
            // Sidebar Position
            SettingsSection(title: "Interface") {
                SettingsRow(title: "Sidebar Position", subtitle: "Choose which side of the window") {
                    Picker("", selection: $sidebarPosition) {
                        Text("Left").tag(SidebarPosition.left)
                        Text("Right").tag(SidebarPosition.right)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
            }

            // Organization
            SettingsSection(title: "Organization") {
                HStack(spacing: VaizorSpacing.xs + 2) {
                    NavigationLink {
                        FolderManagementView(conversationManager: getConversationManager())
                    } label: {
                        Label("Folders", systemImage: "folder")
                            .font(VaizorTypography.label)
                    }
                    .buttonStyle(DarkButtonStyle())

                    NavigationLink {
                        TemplateManagementView(conversationManager: getConversationManager())
                    } label: {
                        Label("Templates", systemImage: "doc.text")
                            .font(VaizorTypography.label)
                    }
                    .buttonStyle(DarkButtonStyle())
                }
            }

            // Data
            SettingsSection(title: "Data") {
                VStack(alignment: .leading, spacing: VaizorSpacing.xs + 2) {
                    Text("Export or import conversations as zip archives.")
                        .font(VaizorTypography.label)
                        .foregroundStyle(settingsTextSecondary)
                        .lineSpacing(VaizorLineHeight.normal)

                    HStack(spacing: VaizorSpacing.xs + 2) {
                        Button {
                            NotificationCenter.default.post(name: .exportConversation, object: nil)
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .font(VaizorTypography.label)
                        }
                        .buttonStyle(DarkButtonStyle())

                        Button {
                            NotificationCenter.default.post(name: .importConversation, object: nil)
                        } label: {
                            Label("Import", systemImage: "square.and.arrow.down")
                                .font(VaizorTypography.label)
                        }
                        .buttonStyle(DarkButtonStyle())
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
    @AppStorage("system_prompt_prefix") private var systemPromptPrefix: String = ""
    @State private var showSystemPromptEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Provider Selection
            SettingsSection(title: "Provider") {
                SettingsRow(title: "Default Provider", subtitle: "Select your AI provider") {
                    Picker("", selection: $container.currentProvider) {
                        ForEach(LLMProvider.allCases, id: \.self) { provider in
                            Text(provider.shortDisplayName).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    .onChange(of: container.currentProvider) { _, _ in
                        Task {
                            await container.loadModelsForCurrentProvider()
                        }
                    }
                }
            }

            // API Keys
            SettingsSection(title: "API Keys") {
                VStack(spacing: 12) {
                    APIKeyField(label: "Anthropic Claude", icon: "sparkles", provider: .anthropic, key: $anthropicKey) { newValue in
                        container.apiKeys[.anthropic] = newValue
                    }
                    APIKeyField(label: "OpenAI", icon: "brain", provider: .openai, key: $openaiKey) { newValue in
                        container.apiKeys[.openai] = newValue
                    }
                    APIKeyField(label: "Google Gemini", icon: "globe", provider: .gemini, key: $geminiKey) { newValue in
                        container.apiKeys[.gemini] = newValue
                    }
                    APIKeyField(label: "Custom Provider", icon: "server.rack", provider: .custom, key: $customKey) { newValue in
                        container.apiKeys[.custom] = newValue
                    }
                }
            }

            // Ollama Settings
            if container.currentProvider == .ollama {
                SettingsSection(title: "Ollama") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Model selector
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(settingsTextSecondary)

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
                                        .font(.system(size: 12))
                                        .foregroundStyle(defaultOllamaModel.isEmpty ? settingsTextSecondary : settingsTextPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundStyle(settingsTextSecondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(settingsDarkSurface)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }

                        // Context window size
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Context Window")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(settingsTextSecondary)
                                Spacer()
                                Text("\(AppSettings.shared.ollamaContextWindow / 1000)K tokens")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(settingsAccent)
                            }

                            Picker("", selection: Binding(
                                get: { AppSettings.shared.ollamaContextWindow },
                                set: { AppSettings.shared.ollamaContextWindow = $0 }
                            )) {
                                Text("8K").tag(8192)
                                Text("16K").tag(16384)
                                Text("32K").tag(32768)
                                Text("64K").tag(65536)
                                Text("128K").tag(131072)
                            }
                            .pickerStyle(.segmented)

                            Text("Higher values use more VRAM. Ensure your model supports the selected size.")
                                .font(.system(size: 10))
                                .foregroundStyle(settingsTextSecondary)
                        }

                        Text("Ollama runs locally and doesn't require an API key")
                            .font(.system(size: 11))
                            .foregroundStyle(settingsTextSecondary)
                    }
                }
            }

            // Model Parameters
            SettingsSection(title: "Parameters") {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Temperature")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(settingsTextPrimary)
                            Spacer()
                            Text(String(format: "%.1f", defaultTemperature))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(settingsAccent)
                        }
                        Slider(value: $defaultTemperature, in: 0...2, step: 0.1)
                            .tint(settingsAccent)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Max Tokens")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(settingsTextPrimary)
                            Spacer()
                            Text("\(defaultMaxTokens)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(settingsAccent)
                        }
                        Slider(value: Binding(
                            get: { Double(defaultMaxTokens) },
                            set: { defaultMaxTokens = Int($0) }
                        ), in: 256...8192, step: 256)
                            .tint(settingsAccent)
                    }
                }
            }

            // System Prompt
            SettingsSection(title: "System Prompt") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Customize how the AI assistant behaves. This prompt is prepended to every conversation.")
                        .font(.system(size: 11))
                        .foregroundStyle(settingsTextSecondary)

                    // Preview of current prompt
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Custom Instructions")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(settingsTextPrimary)
                            Spacer()
                            if !systemPromptPrefix.isEmpty {
                                Text("\(systemPromptPrefix.count) chars")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(settingsTextSecondary)
                            }
                        }

                        Button {
                            showSystemPromptEditor = true
                        } label: {
                            HStack {
                                if systemPromptPrefix.isEmpty {
                                    Text("No custom instructions set")
                                        .font(.system(size: 12))
                                        .foregroundStyle(settingsTextSecondary)
                                } else {
                                    Text(systemPromptPrefix.prefix(100) + (systemPromptPrefix.count > 100 ? "..." : ""))
                                        .font(.system(size: 12))
                                        .foregroundStyle(settingsTextPrimary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundStyle(settingsAccent)
                            }
                            .padding(12)
                            .background(settingsDarkSurface)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }

                    // Quick templates
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Templates")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(settingsTextSecondary)

                        HStack(spacing: 8) {
                            SystemPromptTemplateButton(title: "Concise", icon: "text.alignleft") {
                                systemPromptPrefix = "Be concise and direct in your responses. Avoid unnecessary explanations unless asked."
                            }
                            SystemPromptTemplateButton(title: "Technical", icon: "wrench.and.screwdriver") {
                                systemPromptPrefix = "You are a senior software engineer. Focus on technical accuracy, best practices, and production-ready code. Explain trade-offs when relevant."
                            }
                            SystemPromptTemplateButton(title: "Creative", icon: "paintbrush") {
                                systemPromptPrefix = "Be creative and think outside the box. Offer unique perspectives and innovative solutions."
                            }
                        }

                        if !systemPromptPrefix.isEmpty {
                            Button {
                                systemPromptPrefix = ""
                            } label: {
                                Label("Clear Instructions", systemImage: "xmark.circle")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(settingsTextSecondary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSystemPromptEditor) {
            SystemPromptEditorSheet(
                systemPrompt: $systemPromptPrefix,
                onDismiss: { showSystemPromptEditor = false }
            )
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
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "MCP Servers") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(container.mcpManager.availableServers.count) server(s) configured")
                            .font(.system(size: 12))
                            .foregroundStyle(settingsTextSecondary)
                        Spacer()
                        Button {
                            showMCPSettings = true
                        } label: {
                            Label("Manage", systemImage: "gearshape")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(DarkAccentButtonStyle())
                    }

                    if container.mcpManager.availableServers.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 28))
                                .foregroundStyle(settingsTextSecondary)

                            Text("No MCP servers configured")
                                .font(.system(size: 12))
                                .foregroundStyle(settingsTextSecondary)

                            Button {
                                showMCPSettings = true
                            } label: {
                                Label("Add Server", systemImage: "plus")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(DarkButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(container.mcpManager.availableServers) { server in
                                MCPServerToggleRow(
                                    server: server,
                                    isEnabled: container.mcpManager.enabledServers.contains(server.id),
                                    onToggle: { enabled in
                                        Task {
                                            if enabled {
                                                do {
                                                    try await container.mcpManager.startServer(server)
                                                } catch {
                                                    AppLogger.shared.logError(error, context: "Failed to start MCP server")
                                                }
                                            } else {
                                                await container.mcpManager.stopServer(server)
                                            }
                                        }
                                    }
                                )
                            }
                        }
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

// MARK: - Extensions Settings
struct ExtensionsSettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @ObservedObject private var registry = ExtensionRegistry.shared
    @ObservedObject private var installer = ExtensionInstaller.shared
    @State private var showExtensionManager = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Installed Extensions
            SettingsSection(title: "Installed Extensions") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(registry.installedExtensions.count) extension(s) installed")
                            .font(.system(size: 12))
                            .foregroundStyle(settingsTextSecondary)

                        Spacer()

                        Button {
                            showExtensionManager = true
                        } label: {
                            Label("Browse", systemImage: "square.grid.2x2")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(DarkAccentButtonStyle())
                    }

                    if registry.installedExtensions.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "puzzlepiece.extension")
                                .font(.system(size: 28))
                                .foregroundStyle(settingsTextSecondary)

                            Text("No extensions installed")
                                .font(.system(size: 12))
                                .foregroundStyle(settingsTextSecondary)

                            Text("Browse the extension gallery to add new capabilities")
                                .font(.system(size: 11))
                                .foregroundStyle(settingsTextSecondary.opacity(0.7))
                                .multilineTextAlignment(.center)

                            Button {
                                showExtensionManager = true
                            } label: {
                                Label("Browse Extensions", systemImage: "plus")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(DarkButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(registry.installedExtensions.prefix(5), id: \.id) { installed in
                                ExtensionQuickRow(installed: installed)
                            }

                            if registry.installedExtensions.count > 5 {
                                Button {
                                    showExtensionManager = true
                                } label: {
                                    Text("View all \(registry.installedExtensions.count) extensions...")
                                        .font(.system(size: 11))
                                        .foregroundStyle(settingsAccent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Available Runtimes
            SettingsSection(title: "Available Runtimes") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Extensions may require these runtimes to be installed on your system.")
                        .font(.system(size: 11))
                        .foregroundStyle(settingsTextSecondary)

                    HStack(spacing: 12) {
                        RuntimeStatusBadge(runtime: .node, isAvailable: installer.isRuntimeAvailable(.node))
                        RuntimeStatusBadge(runtime: .python, isAvailable: installer.isRuntimeAvailable(.python))
                        RuntimeStatusBadge(runtime: .deno, isAvailable: installer.isRuntimeAvailable(.deno))
                        RuntimeStatusBadge(runtime: .bun, isAvailable: installer.isRuntimeAvailable(.bun))
                    }
                }
            }

            // Updates
            let updatesCount = registry.installedExtensions.filter { registry.hasUpdate($0.id) }.count
            if updatesCount > 0 {
                SettingsSection(title: "Updates Available") {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(settingsAccent)
                        Text("\(updatesCount) extension update(s) available")
                            .font(.system(size: 12))
                            .foregroundStyle(settingsTextPrimary)

                        Spacer()

                        Button {
                            showExtensionManager = true
                        } label: {
                            Text("View Updates")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(DarkAccentButtonStyle())
                    }
                    .padding(12)
                    .background(settingsAccent.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .sheet(isPresented: $showExtensionManager) {
            ExtensionManagerView()
        }
        .onAppear {
            Task {
                await installer.detectRuntimes()
            }
        }
    }
}

// Extension Quick Row for Settings
struct ExtensionQuickRow: View {
    let installed: InstalledExtension

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(installed.extension_.category.color.opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: installed.extension_.icon ?? installed.extension_.category.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(installed.extension_.category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(installed.extension_.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(installed.isEnabled ? settingsTextPrimary : settingsTextSecondary)

                Text("v\(installed.installedVersion)")
                    .font(.system(size: 10))
                    .foregroundStyle(settingsTextSecondary)
            }

            Spacer()

            Circle()
                .fill(installed.isEnabled ? settingsAccent : settingsTextSecondary.opacity(0.5))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

// Runtime Status Badge
struct RuntimeStatusBadge: View {
    let runtime: ExtensionRuntime
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isAvailable ? ThemeColors.accent : ThemeColors.textSecondary.opacity(0.5))
                .frame(width: 6, height: 6)

            Text(runtime.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isAvailable ? settingsTextPrimary : settingsTextSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: "232426"))
        .cornerRadius(4)
    }
}

// MARK: - Appearance Settings
struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance = "Dark"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Theme") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $appearance) {
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                        Text("System").tag("System")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appearance) { _, newValue in
                        applyTheme(newValue)
                    }

                    Text("Choose your preferred color scheme")
                        .font(.system(size: 11))
                        .foregroundStyle(settingsTextSecondary)
                }
            }
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
        default:
            NSApp.appearance = nil
        }
    }
}

// MARK: - Behavior Settings
struct BehaviorSettingsView: View {
    @AppStorage("cautious_enter") private var cautiousEnter: Bool = false
    @AppStorage("auto_scroll") private var autoScroll: Bool = true
    @AppStorage("stream_responses") private var streamResponses: Bool = true
    @AppStorage("show_thinking") private var showThinking: Bool = true
    @AppStorage("auto_convert_long_text") private var autoConvertLongText: Bool = true
    @AppStorage("long_text_threshold") private var longTextThreshold: Int = 5000
    @AppStorage("auto_scrape_urls") private var autoScrapeUrls: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Input") {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Cautious Enter",
                        subtitle: "Require Shift+Enter to send messages",
                        isOn: $cautiousEnter
                    )
                    SettingsToggleRow(
                        title: "Auto-convert Long Text",
                        subtitle: "Convert long pastes to file attachments",
                        isOn: $autoConvertLongText
                    )
                    if autoConvertLongText {
                        HStack {
                            Text("Threshold")
                                .font(.system(size: 12))
                                .foregroundStyle(settingsTextPrimary)
                            Spacer()
                            Text("\(longTextThreshold) chars")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(settingsAccent)
                            Stepper("", value: $longTextThreshold, in: 1000...20000, step: 1000)
                                .labelsHidden()
                        }
                        .padding(.vertical, 8)
                    }
                    SettingsToggleRow(
                        title: "Auto-scrape URLs",
                        subtitle: "Fetch content from pasted URLs",
                        isOn: $autoScrapeUrls
                    )
                }
            }

            SettingsSection(title: "Output") {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Stream Responses",
                        subtitle: "Show responses as they generate",
                        isOn: $streamResponses
                    )
                    SettingsToggleRow(
                        title: "Auto-scroll",
                        subtitle: "Scroll to bottom on new messages",
                        isOn: $autoScroll
                    )
                    SettingsToggleRow(
                        title: "Show Thinking",
                        subtitle: "Display AI reasoning process",
                        isOn: $showThinking
                    )
                }
            }
        }
    }
}

// MARK: - Privacy Settings
struct PrivacySettingsView: View {
    @AppStorage("clear_on_close") private var clearOnClose: Bool = false
    @AppStorage("disable_history") private var disableHistory: Bool = false
    @AppStorage("show_cost") private var showCost: Bool = false
    @AppStorage("show_token_count") private var showTokenCount: Bool = false
    @AppStorage("enable_prompt_caching") private var enablePromptCaching: Bool = true
    @ObservedObject private var redactor = DataRedactor.shared
    @ObservedObject private var costTracker = CostTracker.shared
    @State private var showAddPatternSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Data Redaction Section
            SettingsSection(title: "Data Redaction") {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsToggleRow(
                        title: "Enable Redaction",
                        subtitle: "Automatically redact sensitive data before sending to AI",
                        isOn: $redactor.isRedactionEnabled
                    )

                    if redactor.isRedactionEnabled {
                        Rectangle()
                            .fill(settingsDarkBorder)
                            .frame(height: 1)
                            .padding(.vertical, 4)

                        // Pattern categories
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Redaction Patterns")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(settingsTextPrimary)

                            Text("Sensitive data matching these patterns will be replaced with placeholders before being sent to the AI, then restored in the response.")
                                .font(.system(size: 11))
                                .foregroundStyle(settingsTextSecondary)
                                .lineSpacing(2)
                        }

                        // Built-in patterns
                        RedactionPatternList(
                            title: "Built-in Patterns",
                            patterns: redactor.patterns.filter { $0.isBuiltIn },
                            onToggle: { pattern in
                                redactor.togglePattern(pattern)
                            },
                            canDelete: false
                        )

                        // User patterns
                        if !redactor.patterns.filter({ !$0.isBuiltIn }).isEmpty {
                            RedactionPatternList(
                                title: "Custom Patterns",
                                patterns: redactor.patterns.filter { !$0.isBuiltIn },
                                onToggle: { pattern in
                                    redactor.togglePattern(pattern)
                                },
                                onDelete: { pattern in
                                    redactor.removePattern(pattern)
                                },
                                canDelete: true
                            )
                        }

                        // Add custom pattern button
                        Button {
                            showAddPatternSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12))
                                Text("Add Custom Pattern")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(settingsAccent)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
            }

            SettingsSection(title: "Conversation History") {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Clear on Close",
                        subtitle: "Delete conversation when window closes",
                        isOn: $clearOnClose
                    )
                    SettingsToggleRow(
                        title: "Disable History",
                        subtitle: "Don't save conversation history",
                        isOn: $disableHistory
                    )
                }
            }

            SettingsSection(title: "Usage Tracking") {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Show Cost",
                        subtitle: "Display estimated cost per message",
                        isOn: $showCost
                    )
                    SettingsToggleRow(
                        title: "Show Token Count",
                        subtitle: "Display token usage per message",
                        isOn: $showTokenCount
                    )
                }
            }

            // Prompt Caching Section
            SettingsSection(title: "Prompt Caching") {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsToggleRow(
                        title: "Enable Prompt Caching",
                        subtitle: "Cache system prompts and conversation history (Claude only)",
                        isOn: $enablePromptCaching
                    )

                    if enablePromptCaching {
                        Rectangle()
                            .fill(settingsDarkBorder)
                            .frame(height: 1)
                            .padding(.vertical, 4)

                        // Cache Statistics
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cache Statistics")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(settingsTextPrimary)

                            // Session stats
                            HStack(spacing: 16) {
                                CacheStatCard(
                                    title: "Session Hit Rate",
                                    value: String(format: "%.1f%%", costTracker.cacheHitRate),
                                    subtitle: "\(costTracker.sessionCacheHits) hits / \(costTracker.sessionCacheMisses) misses"
                                )
                                CacheStatCard(
                                    title: "All-Time Hit Rate",
                                    value: String(format: "%.1f%%", costTracker.totalCacheHitRate),
                                    subtitle: "\(costTracker.totalCacheHits) hits / \(costTracker.totalCacheMisses) misses"
                                )
                            }

                            // Token stats
                            HStack(spacing: 16) {
                                CacheStatCard(
                                    title: "Tokens Read from Cache",
                                    value: formatTokenCount(costTracker.totalCacheReadTokens),
                                    subtitle: "90% discount applied"
                                )
                                CacheStatCard(
                                    title: "Estimated Savings",
                                    value: String(format: "$%.2f", costTracker.estimatedCacheSavings),
                                    subtitle: "From cached tokens"
                                )
                            }

                            // Info text
                            Text("Prompt caching reduces costs by reusing processed system prompts and conversation history. Cached tokens cost 90% less than regular input tokens.")
                                .font(.system(size: 11))
                                .foregroundStyle(settingsTextSecondary)
                                .lineSpacing(2)
                                .padding(.top, 4)

                            // Reset button
                            HStack {
                                Spacer()
                                Button("Reset Statistics") {
                                    costTracker.resetAllCacheStats()
                                }
                                .buttonStyle(.bordered)
                                .font(.system(size: 11))
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddPatternSheet) {
            AddRedactionPatternView(
                onAdd: { name, pattern in
                    redactor.addPattern(name: name, pattern: pattern)
                }
            )
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Cache Stat Card
struct CacheStatCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(settingsTextSecondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(settingsAccent)
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(settingsTextSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(settingsDarkBase)
        .cornerRadius(6)
    }
}

// MARK: - Redaction Pattern List
struct RedactionPatternList: View {
    let title: String
    let patterns: [RedactionPattern]
    let onToggle: (RedactionPattern) -> Void
    var onDelete: ((RedactionPattern) -> Void)? = nil
    let canDelete: Bool

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(settingsTextSecondary)
                        .frame(width: 12)

                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(settingsTextSecondary)

                    Text("(\(patterns.filter(\.isEnabled).count)/\(patterns.count))")
                        .font(.system(size: 10))
                        .foregroundStyle(settingsTextSecondary.opacity(0.7))

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(patterns) { pattern in
                        HStack(spacing: 8) {
                            Toggle("", isOn: Binding(
                                get: { pattern.isEnabled },
                                set: { _ in onToggle(pattern) }
                            ))
                            .toggleStyle(.checkbox)
                            .tint(settingsAccent)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(pattern.name)
                                    .font(.system(size: 12))
                                    .foregroundStyle(pattern.isEnabled ? settingsTextPrimary : settingsTextSecondary)

                                Text(pattern.pattern.prefix(40) + (pattern.pattern.count > 40 ? "..." : ""))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(settingsTextSecondary.opacity(0.7))
                            }

                            Spacer()

                            if canDelete, let onDelete = onDelete {
                                Button {
                                    onDelete(pattern)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundStyle(settingsTextSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.leading, 18)
            }
        }
    }
}

// MARK: - Add Redaction Pattern View
struct AddRedactionPatternView: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (String, String) -> Void

    @State private var name = ""
    @State private var pattern = ""
    @State private var testText = ""
    @State private var testResult = ""

    private let darkBase = ThemeColors.darkBase
    private let darkSurface = ThemeColors.darkSurface
    private let darkBorder = ThemeColors.darkBorder
    private let textPrimary = ThemeColors.textPrimary
    private let textSecondary = ThemeColors.textSecondary
    private let accent = ThemeColors.accent

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Custom Pattern")
                    .font(VaizorTypography.h3)
                    .foregroundStyle(textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(textSecondary)
                        .frame(width: 24, height: 24)
                        .background(darkSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Rectangle().fill(darkBorder).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pattern Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(textPrimary)
                        TextField("e.g., Company API Key", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .padding(10)
                            .background(darkSurface)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(darkBorder, lineWidth: 1))
                    }

                    // Pattern field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Regex Pattern")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(textPrimary)
                        TextField("e.g., MYAPI_[a-zA-Z0-9]{32}", text: $pattern)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(10)
                            .background(darkSurface)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(darkBorder, lineWidth: 1))

                        Text("Use regular expression syntax to match sensitive data")
                            .font(.system(size: 11))
                            .foregroundStyle(textSecondary)
                    }

                    // Test area
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Test Pattern")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(textPrimary)

                        TextEditor(text: $testText)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 60)
                            .padding(8)
                            .background(darkSurface)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(darkBorder, lineWidth: 1))

                        Button("Test") {
                            testPattern()
                        }
                        .buttonStyle(.bordered)

                        if !testResult.isEmpty {
                            Text(testResult)
                                .font(.system(size: 11))
                                .foregroundStyle(testResult.contains("Found") ? accent : textSecondary)
                        }
                    }
                }
                .padding(16)
            }

            Rectangle().fill(darkBorder).frame(height: 1)

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add Pattern") {
                    onAdd(name, pattern)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(name.isEmpty || pattern.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 450, height: 450)
        .background(darkBase)
    }

    private func testPattern() {
        guard !pattern.isEmpty, !testText.isEmpty else {
            testResult = "Enter both pattern and test text"
            return
        }

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(testText.startIndex..., in: testText)
            let matches = regex.matches(in: testText, options: [], range: range)

            if matches.isEmpty {
                testResult = "No matches found"
            } else {
                let matchStrings = matches.compactMap { match -> String? in
                    guard let range = Range(match.range, in: testText) else { return nil }
                    return String(testText[range])
                }
                testResult = "Found \(matches.count) match(es): \(matchStrings.joined(separator: ", "))"
            }
        } catch {
            testResult = "Invalid regex: \(error.localizedDescription)"
        }
    }
}

// MARK: - Security Settings (AiEDR)
struct SecuritySettingsView: View {
    @ObservedObject private var edrService = AiEDRService.shared
    @State private var showSecurityDashboard = false
    @State private var isPerformingHostCheck = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quick Status
            SettingsSection(title: "Status") {
                HStack(spacing: 16) {
                    // Threat level indicator
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(edrService.threatLevel.color.opacity(0.2))
                                .frame(width: 36, height: 36)

                            Image(systemName: edrService.threatLevel.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(edrService.threatLevel.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Threat Level")
                                .font(.system(size: 11))
                                .foregroundStyle(settingsTextSecondary)

                            Text(edrService.threatLevel.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(edrService.threatLevel.color)
                        }
                    }

                    Spacer()

                    // Quick stats
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(edrService.totalDetectedThreats) detected")
                            .font(.system(size: 11))
                            .foregroundStyle(settingsTextSecondary)

                        Text("\(edrService.activeAlerts.count) active alerts")
                            .font(.system(size: 11))
                            .foregroundStyle(edrService.activeAlerts.isEmpty ? settingsAccent : .orange)
                    }

                    Button {
                        showSecurityDashboard = true
                    } label: {
                        Label("Dashboard", systemImage: "shield.checkered")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(DarkAccentButtonStyle())
                }
            }

            // Detection Settings
            SettingsSection(title: "Detection") {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Enable AiEDR",
                        subtitle: "AI Endpoint Detection & Response system",
                        isOn: $edrService.isEnabled
                    )

                    SettingsToggleRow(
                        title: "Auto-block Critical Threats",
                        subtitle: "Automatically block messages with critical threat level",
                        isOn: $edrService.autoBlockCritical
                    )

                    SettingsToggleRow(
                        title: "Prompt on High Threats",
                        subtitle: "Ask for confirmation before sending suspicious messages",
                        isOn: $edrService.promptOnHigh
                    )
                }
            }

            // Audit Logging
            SettingsSection(title: "Audit Logging") {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Log Threats Only",
                        subtitle: "Only log when security threats are detected (privacy-focused)",
                        isOn: $edrService.logThreatsOnly
                    )

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Audit Log Entries")
                                .font(.system(size: 12))
                                .foregroundStyle(settingsTextPrimary)

                            Text("\(edrService.auditLog.count) entries stored")
                                .font(.system(size: 11))
                                .foregroundStyle(settingsTextSecondary)
                        }

                        Spacer()

                        Button("Export") {
                            if let data = edrService.exportAuditLog() {
                                let panel = NSSavePanel()
                                panel.allowedContentTypes = [.json]
                                panel.nameFieldStringValue = "vaizor_audit_log.json"
                                if panel.runModal() == .OK, let url = panel.url {
                                    try? data.write(to: url)
                                }
                            }
                        }
                        .buttonStyle(DarkButtonStyle())

                        Button("Clear") {
                            edrService.clearAuditLog()
                        }
                        .buttonStyle(DarkButtonStyle())
                    }
                    .padding(.vertical, 8)
                }
            }

            // Host Monitoring
            SettingsSection(title: "Host Security") {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsToggleRow(
                        title: "Background Monitoring",
                        subtitle: "Periodically check system security status",
                        isOn: $edrService.backgroundMonitoring
                    )
                    .onChange(of: edrService.backgroundMonitoring) { _, newValue in
                        if newValue {
                            edrService.startBackgroundMonitoring()
                        } else {
                            edrService.stopBackgroundMonitoring()
                        }
                    }

                    HStack {
                        if let report = edrService.lastHostSecurityReport {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Last scan: \(report.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(settingsTextSecondary)

                                HStack(spacing: 12) {
                                    Label("Firewall", systemImage: report.firewallEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(report.firewallEnabled ? settingsAccent : .red)

                                    Label("FileVault", systemImage: report.diskEncrypted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(report.diskEncrypted ? settingsAccent : .red)

                                    Label("SIP", systemImage: report.systemIntegrityProtection ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(report.systemIntegrityProtection ? settingsAccent : .red)
                                }
                            }
                        } else {
                            Text("No security scan performed yet")
                                .font(.system(size: 11))
                                .foregroundStyle(settingsTextSecondary)
                        }

                        Spacer()

                        Button {
                            Task {
                                isPerformingHostCheck = true
                                _ = await edrService.performHostSecurityCheck()
                                isPerformingHostCheck = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if isPerformingHostCheck {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text("Scan Now")
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(DarkButtonStyle())
                        .disabled(isPerformingHostCheck)
                    }
                }
            }
        }
        .sheet(isPresented: $showSecurityDashboard) {
            SecurityDashboardView()
                .frame(minWidth: 700, minHeight: 500)
        }
    }
}

// MARK: - Shortcuts Settings
struct ShortcutsSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Keyboard Shortcuts") {
                VStack(spacing: 0) {
                    ShortcutRow(action: "New Chat", shortcut: "⌘N")
                    ShortcutRow(action: "Open Settings", shortcut: "⌘,")
                    ShortcutRow(action: "Send Message", shortcut: "⏎")
                    ShortcutRow(action: "Stop Streaming", shortcut: "⌘.")
                    ShortcutRow(action: "Toggle Sidebar", shortcut: "⌘\\")
                }
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
                .font(.system(size: 12))
                .foregroundStyle(settingsTextPrimary)
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(settingsTextSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(settingsDarkSurface)
                .cornerRadius(4)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - About Settings
struct AboutSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // App Info with actual icon
            HStack(spacing: 14) {
                // App Icon
                if let iconImage = loadAppIcon() {
                    Image(nsImage: iconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                } else {
                    // Fallback icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "1a3a32"), Color(hex: "0d1f1a")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)

                        // Stylized V logo
                        Image(systemName: "v.circle.fill")
                            .foregroundStyle(settingsAccent)
                            .font(.system(size: 32, weight: .bold))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Vaizor")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(settingsTextPrimary)

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.system(size: 12))
                        .foregroundStyle(settingsTextSecondary)

                    Text("Premium AI Assistant")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(settingsAccent)
                }

                Spacer()
            }

            Rectangle()
                .fill(settingsDarkBorder)
                .frame(height: 1)

            // Description
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Intelligent AI Companion")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(settingsTextPrimary)

                Text("Vaizor is a premium AI client that seamlessly connects you with leading language models from Anthropic, OpenAI, Google, and local providers like Ollama. Extended capabilities through MCP (Model Context Protocol) servers enable powerful integrations with your tools and data.")
                    .font(.system(size: 12))
                    .foregroundStyle(settingsTextSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(settingsDarkBorder)
                .frame(height: 1)

            // Features highlight
            VStack(alignment: .leading, spacing: 8) {
                Text("Key Features")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(settingsTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                VStack(alignment: .leading, spacing: 6) {
                    featureRow(icon: "cpu", text: "Multi-provider support (Claude, GPT, Gemini, Ollama)")
                    featureRow(icon: "puzzlepiece.extension", text: "MCP server integration for extended capabilities")
                    featureRow(icon: "shield.checkered", text: "Privacy-focused with local data storage")
                    featureRow(icon: "sparkles", text: "Interactive artifacts and code execution")
                    featureRow(icon: "paintbrush", text: "Beautiful native macOS experience")
                }
            }

            Rectangle()
                .fill(settingsDarkBorder)
                .frame(height: 1)

            // Show Onboarding button
            VStack(alignment: .leading, spacing: 8) {
                Text("Getting Started")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(settingsTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .showOnboarding, object: nil)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))

                        Text("Show Onboarding")
                            .font(.system(size: 13, weight: .medium))

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundStyle(settingsTextSecondary)
                    }
                    .foregroundStyle(settingsTextPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(settingsDarkSurface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(settingsDarkBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Copyright and legal
            VStack(alignment: .leading, spacing: 4) {
                Rectangle()
                    .fill(settingsDarkBorder)
                    .frame(height: 1)
                    .padding(.bottom, 8)

                Text("Developed by Quandry")
                    .font(.system(size: 10))
                    .foregroundStyle(settingsTextSecondary.opacity(0.7))

                Text("© 2024-2025 Quandry Labs. All rights reserved.")
                    .font(.system(size: 10))
                    .foregroundStyle(settingsTextSecondary.opacity(0.5))
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(settingsAccent)
                .frame(width: 16)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(settingsTextSecondary)
        }
    }

    private func loadAppIcon() -> NSImage? {
        // Try to load from bundle resources
        if let iconPath = Bundle.main.path(forResource: "Vaizor", ofType: "png"),
           let image = NSImage(contentsOfFile: iconPath) {
            return image
        }

        // Try the icns file
        if let icnsPath = Bundle.main.path(forResource: "Vaizor", ofType: "icns"),
           let image = NSImage(contentsOfFile: icnsPath) {
            return image
        }

        // Try app icon from bundle
        if let appIconName = Bundle.main.infoDictionary?["CFBundleIconFile"] as? String {
            let iconName = appIconName.hasSuffix(".icns") ? String(appIconName.dropLast(5)) : appIconName
            if let iconPath = Bundle.main.path(forResource: iconName, ofType: "icns"),
               let image = NSImage(contentsOfFile: iconPath) {
                return image
            }
        }

        return NSApp.applicationIconImage
    }
}

// MARK: - Settings UI Components

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(settingsTextSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(12)
            .background(settingsDarkSurface)
            .cornerRadius(8)
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(settingsTextPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(settingsTextSecondary)
            }
            Spacer()
            content
        }
    }
}

struct APIKeyField: View {
    let label: String
    let icon: String
    let provider: LLMProvider
    @Binding var key: String
    let onChange: (String) -> Void

    @State private var isKeyVisible: Bool = false
    @State private var validationState: APIKeyValidationState = .empty
    @State private var testErrorMessage: String?
    @State private var isTesting: Bool = false
    @FocusState private var isFocused: Bool

    enum APIKeyValidationState {
        case empty
        case formatValid      // Format looks correct
        case formatInvalid    // Format is wrong
        case verified         // API test passed
        case testFailed       // API test failed

        var color: Color {
            switch self {
            case .empty: return settingsDarkBorder
            case .formatValid: return .orange.opacity(0.8)
            case .formatInvalid: return .red
            case .verified: return settingsAccent
            case .testFailed: return .red
            }
        }

        var icon: String? {
            switch self {
            case .empty: return nil
            case .formatValid: return "questionmark.circle.fill"
            case .formatInvalid: return "exclamationmark.circle.fill"
            case .verified: return "checkmark.seal.fill"
            case .testFailed: return "xmark.circle.fill"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(settingsAccent)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(settingsTextPrimary)

                Spacer()

                // Test button
                if !key.isEmpty && provider != .ollama && provider != .custom {
                    Button {
                        Task {
                            await testAPIKey()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 10, height: 10)
                            } else {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                            }
                            Text(isTesting ? "Testing..." : "Test")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(isTesting ? settingsTextSecondary : settingsAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(settingsDarkSurface)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting)
                    .help("Test API key by making a request")
                }

                // Validation indicator
                if let validationIcon = validationState.icon {
                    Image(systemName: validationIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(validationState.color)
                }
            }

            HStack(spacing: 0) {
                // Key input field with show/hide toggle
                Group {
                    if isKeyVisible {
                        TextField("Enter API key", text: $key)
                            .textFieldStyle(.plain)
                    } else {
                        SecureField("Enter API key", text: $key)
                            .textFieldStyle(.plain)
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .focused($isFocused)

                // Show/Hide toggle button
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isKeyVisible.toggle()
                    }
                } label: {
                    Image(systemName: isKeyVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(settingsTextSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isKeyVisible ? "Hide API key" : "Show API key")
                .accessibilityLabel(isKeyVisible ? "Hide API key" : "Show API key")
            }
            .background(settingsDarkBase)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isFocused ? settingsAccent : validationState.color, lineWidth: 1)
            )
            .onChange(of: key) { _, newValue in
                onChange(newValue)
                validateKeyFormat(newValue)
            }

            // Validation feedback text
            validationFeedback
        }
    }

    @ViewBuilder
    private var validationFeedback: some View {
        switch validationState {
        case .empty:
            EmptyView()
        case .formatInvalid:
            if !key.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("API key format appears invalid")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.orange)
            }
        case .formatValid:
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 10))
                Text("Format looks valid - click Test to verify")
                    .font(.system(size: 10))
            }
            .foregroundStyle(settingsTextSecondary)
        case .verified:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                Text("API key verified")
                    .font(.system(size: 10))
            }
            .foregroundStyle(settingsAccent)
        case .testFailed:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                Text(testErrorMessage ?? "API key test failed")
                    .font(.system(size: 10))
                    .lineLimit(2)
            }
            .foregroundStyle(.red)
        }
    }

    private func validateKeyFormat(_ key: String) {
        testErrorMessage = nil
        guard !key.isEmpty else {
            validationState = .empty
            return
        }

        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        let isValidFormat: Bool
        switch provider {
        case .anthropic:
            isValidFormat = trimmedKey.hasPrefix("sk-ant-") && trimmedKey.count > 20
        case .openai:
            isValidFormat = trimmedKey.hasPrefix("sk-") && trimmedKey.count > 20
        case .gemini:
            isValidFormat = trimmedKey.count >= 30
        case .ollama, .custom:
            isValidFormat = trimmedKey.count >= 10
        }

        validationState = isValidFormat ? .formatValid : .formatInvalid
    }

    @MainActor
    private func testAPIKey() async {
        isTesting = true
        testErrorMessage = nil

        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            switch provider {
            case .anthropic:
                try await testAnthropicKey(trimmedKey)
            case .openai:
                try await testOpenAIKey(trimmedKey)
            case .gemini:
                try await testGeminiKey(trimmedKey)
            case .ollama, .custom:
                // These don't have standard validation endpoints
                validationState = .verified
                isTesting = false
                return
            }
            validationState = .verified
        } catch {
            validationState = .testFailed
            testErrorMessage = error.localizedDescription
        }
        isTesting = false
    }

    private func testAnthropicKey(_ apiKey: String) async throws {
        // Use count_tokens endpoint - it's free and validates auth without making a paid API call
        let url = URL(string: "https://api.anthropic.com/v1/messages/count_tokens")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Minimal request to test authentication - count_tokens is free
        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "messages": [["role": "user", "content": "test"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIKeyValidationError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIKeyValidationError.invalidKey
        } else if httpResponse.statusCode == 403 {
            throw APIKeyValidationError.insufficientPermissions
        } else if httpResponse.statusCode >= 400 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIKeyValidationError.apiError(message)
            }
            throw APIKeyValidationError.apiError("HTTP \(httpResponse.statusCode)")
        }
        // Success - key is valid
    }

    private func testOpenAIKey(_ apiKey: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIKeyValidationError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIKeyValidationError.invalidKey
        } else if httpResponse.statusCode == 403 {
            throw APIKeyValidationError.insufficientPermissions
        } else if httpResponse.statusCode >= 400 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIKeyValidationError.apiError(message)
            }
            throw APIKeyValidationError.apiError("HTTP \(httpResponse.statusCode)")
        }
        // Success - key is valid
    }

    private func testGeminiKey(_ apiKey: String) async throws {
        // Use header-based auth to avoid API key in URL (more secure - won't appear in logs)
        let url = URL(string: "https://generativelanguage.googleapis.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIKeyValidationError.invalidResponse
        }

        if httpResponse.statusCode == 400 || httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
            throw APIKeyValidationError.invalidKey
        } else if httpResponse.statusCode >= 400 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIKeyValidationError.apiError(message)
            }
            throw APIKeyValidationError.apiError("HTTP \(httpResponse.statusCode)")
        }
        // Success - key is valid
    }
}

enum APIKeyValidationError: LocalizedError {
    case invalidKey
    case insufficientPermissions
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid API key"
        case .insufficientPermissions:
            return "Insufficient permissions"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return message
        }
    }
}

struct DarkButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VaizorTypography.label)
            .foregroundStyle(ThemeColors.textPrimary)
            .padding(.horizontal, VaizorSpacing.sm)
            .padding(.vertical, VaizorSpacing.xs)
            .background(configuration.isPressed ? ThemeColors.darkBorder : ThemeColors.darkSurface)
            .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusSm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VaizorSpacing.radiusSm, style: .continuous)
                    .stroke(ThemeColors.darkBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct DarkAccentButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VaizorTypography.label)
            .foregroundStyle(.white)
            .padding(.horizontal, VaizorSpacing.sm)
            .padding(.vertical, VaizorSpacing.xs)
            .background(configuration.isPressed ? ThemeColors.accent.opacity(0.8) : ThemeColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusSm, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VaizorTypography.label)
                    .foregroundStyle(ThemeColors.textPrimary)
                Text(subtitle)
                    .font(VaizorTypography.caption)
                    .foregroundStyle(ThemeColors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(ThemeColors.accent)
        }
        .padding(.vertical, VaizorSpacing.xs)
    }
}

// MARK: - System Prompt Components

struct SystemPromptTemplateButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaizorSpacing.xxs + 2) {
                Image(systemName: icon)
                    .font(VaizorTypography.body)
                    .foregroundStyle(ThemeColors.accent)
                Text(title)
                    .font(VaizorTypography.caption.weight(.medium))
                    .foregroundStyle(ThemeColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, VaizorSpacing.xs + 2)
            .background(ThemeColors.darkSurface)
            .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous)
                    .stroke(ThemeColors.darkBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SystemPromptEditorSheet: View {
    @Binding var systemPrompt: String
    let onDismiss: () -> Void
    @State private var editingPrompt: String = ""
    @FocusState private var isEditorFocused: Bool

    private let darkBase = ThemeColors.darkBase
    private let darkSurface = ThemeColors.darkSurface
    private let darkBorder = ThemeColors.darkBorder
    private let textPrimary = ThemeColors.textPrimary
    private let textSecondary = ThemeColors.textSecondary
    private let accent = ThemeColors.accent

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom Instructions")
                        .font(VaizorTypography.h3)
                        .foregroundStyle(textPrimary)
                    Text("Define how the AI should behave in conversations")
                        .font(.system(size: 12))
                        .foregroundStyle(textSecondary)
                }
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Rectangle().fill(darkBorder).frame(height: 1)

            // Editor
            VStack(alignment: .leading, spacing: 12) {
                Text("System Prompt")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textPrimary)

                TextEditor(text: $editingPrompt)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(darkSurface)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isEditorFocused ? accent : darkBorder, lineWidth: 1)
                    )
                    .frame(minHeight: 200)
                    .focused($isEditorFocused)

                HStack {
                    Text("\(editingPrompt.count) characters")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(textSecondary)
                    Spacer()
                    if editingPrompt.count > 2000 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("Long prompts may increase costs")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.orange)
                    }
                }

                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips for effective prompts:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(textSecondary)

                    VStack(alignment: .leading, spacing: 4) {
                        tipRow("Be specific about the role or persona you want")
                        tipRow("Include constraints (e.g., word limits, formatting)")
                        tipRow("Mention any domains of expertise needed")
                        tipRow("Specify tone: formal, casual, technical, etc.")
                    }
                }
                .padding(12)
                .background(darkSurface.opacity(0.5))
                .cornerRadius(8)
            }
            .padding(20)

            Rectangle().fill(darkBorder).frame(height: 1)

            // Footer
            HStack {
                Button("Reset to Default") {
                    editingPrompt = ""
                }
                .buttonStyle(.bordered)
                .foregroundStyle(textSecondary)

                Spacer()

                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(textPrimary)

                Button("Save") {
                    systemPrompt = editingPrompt
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }
            .padding(20)
        }
        .frame(width: 550, height: 580)
        .background(darkBase)
        .onAppear {
            editingPrompt = systemPrompt
        }
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(accent)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(textSecondary)
        }
    }
}
