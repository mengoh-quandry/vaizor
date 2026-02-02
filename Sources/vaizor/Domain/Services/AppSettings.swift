import Foundation
import SwiftUI

/// Comprehensive app settings manager with Chorus-level feature parity
@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Appearance Settings

    /// Font family for the app
    @AppStorage("font_family") var fontFamily: FontFamily = .system {
        didSet { objectWillChange.send() }
    }

    /// Font size scale (0.8 - 1.4)
    @AppStorage("font_size_scale") var fontSizeScale: Double = 1.0 {
        didSet { objectWillChange.send() }
    }

    /// Show message timestamps
    @AppStorage("show_timestamps") var showTimestamps: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Compact message mode
    @AppStorage("compact_messages") var compactMessages: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Show avatar icons in chat
    @AppStorage("show_avatars") var showAvatars: Bool = true {
        didSet { objectWillChange.send() }
    }

    // MARK: - Behavior Settings

    /// Auto-convert long text to file attachment
    @AppStorage("auto_convert_long_text") var autoConvertLongText: Bool = true {
        didSet { objectWillChange.send() }
    }

    /// Threshold for auto-converting text (characters)
    @AppStorage("long_text_threshold") var longTextThreshold: Int = 5000 {
        didSet { objectWillChange.send() }
    }

    /// Auto-scrape URLs pasted in chat
    @AppStorage("auto_scrape_urls") var autoScrapeUrls: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Cautious enter mode (require Shift+Enter to send)
    @AppStorage("cautious_enter") var cautiousEnter: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Auto-scroll to bottom on new messages
    @AppStorage("auto_scroll") var autoScroll: Bool = true {
        didSet { objectWillChange.send() }
    }

    /// Stream responses (show as they generate)
    @AppStorage("stream_responses") var streamResponses: Bool = true {
        didSet { objectWillChange.send() }
    }

    /// Show thinking/reasoning process
    @AppStorage("show_thinking") var showThinking: Bool = true {
        didSet { objectWillChange.send() }
    }

    // MARK: - Cost & Usage Settings

    /// Show token costs
    @AppStorage("show_cost") var showCost: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Show token count per message
    @AppStorage("show_token_count") var showTokenCount: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Monthly budget alert threshold (USD)
    @AppStorage("monthly_budget_alert") var monthlyBudgetAlert: Double = 50.0 {
        didSet { objectWillChange.send() }
    }

    /// Enable budget alerts
    @AppStorage("enable_budget_alerts") var enableBudgetAlerts: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Enable prompt caching for Anthropic Claude models
    /// Provides 90% discount on cached input tokens
    @AppStorage("enable_prompt_caching") var enablePromptCaching: Bool = true {
        didSet { objectWillChange.send() }
    }

    // MARK: - Context Enhancement Settings

    /// Enable automatic datetime injection for local models
    /// Always injects current date/time into system prompt
    @AppStorage("enable_datetime_injection") var enableDatetimeInjection: Bool = true {
        didSet { objectWillChange.send() }
    }

    /// Enable auto-refresh for stale queries
    /// Automatically searches web when detecting potentially outdated queries
    @AppStorage("enable_auto_refresh") var enableAutoRefresh: Bool = true {
        didSet { objectWillChange.send() }
    }

    /// Show context enhancement indicator
    /// Displays subtle indicator when context was enhanced
    @AppStorage("show_context_enhancement_indicator") var showContextEnhancementIndicator: Bool = true {
        didSet { objectWillChange.send() }
    }

    // MARK: - Privacy Settings

    /// Clear conversation on close
    @AppStorage("clear_on_close") var clearOnClose: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Disable conversation history
    @AppStorage("disable_history") var disableHistory: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Anonymize code snippets before sending
    @AppStorage("anonymize_code") var anonymizeCode: Bool = false {
        didSet { objectWillChange.send() }
    }

    // MARK: - Advanced Settings

    /// Default model for new chats
    @AppStorage("default_model") var defaultModel: String = "claude-3-5-sonnet-20241022" {
        didSet { objectWillChange.send() }
    }

    /// Default temperature (0.0 - 2.0)
    @AppStorage("default_temperature") var defaultTemperature: Double = 0.7 {
        didSet { objectWillChange.send() }
    }

    /// Max tokens for responses
    @AppStorage("max_tokens") var maxTokens: Int = 8192 {
        didSet { objectWillChange.send() }
    }

    /// Enable experimental features
    @AppStorage("experimental_features") var experimentalFeatures: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Custom system prompt prefix
    @AppStorage("system_prompt_prefix") var systemPromptPrefix: String = "" {
        didSet { objectWillChange.send() }
    }

    // MARK: - Keyboard Shortcuts

    /// Quick chat shortcut enabled
    @AppStorage("quick_chat_enabled") var quickChatEnabled: Bool = true {
        didSet { objectWillChange.send() }
    }

    /// Quick chat shortcut key combo
    @AppStorage("quick_chat_shortcut") var quickChatShortcut: String = "⌘⇧Space" {
        didSet { objectWillChange.send() }
    }

    // MARK: - Integration Settings

    /// Ollama server URL
    @AppStorage("ollama_url") var ollamaUrl: String = "http://localhost:11434" {
        didSet { objectWillChange.send() }
    }

    /// Ollama context window size (num_ctx) - how many tokens the model can see
    @AppStorage("ollama_context_window") var ollamaContextWindow: Int = 128000 {
        didSet { objectWillChange.send() }
    }

    /// MCP servers enabled
    @AppStorage("mcp_enabled") var mcpEnabled: Bool = true {
        didSet { objectWillChange.send() }
    }

    // MARK: - Onboarding

    /// Whether the user has completed the onboarding flow
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Reset onboarding to show it again
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Font Helpers

    enum FontFamily: String, CaseIterable, Identifiable {
        case system = "System"
        case inter = "Inter"
        case sourceCodePro = "Source Code Pro"
        case jetbrainsMono = "JetBrains Mono"
        case sfMono = "SF Mono"

        var id: String { rawValue }

        var fontName: String {
            switch self {
            case .system: return ".AppleSystemUIFont"
            case .inter: return "Inter"
            case .sourceCodePro: return "Source Code Pro"
            case .jetbrainsMono: return "JetBrains Mono"
            case .sfMono: return "SF Mono"
            }
        }
    }

    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let scaledSize = size * fontSizeScale
        if fontFamily == .system {
            return .system(size: scaledSize, weight: weight)
        } else {
            return .custom(fontFamily.fontName, size: scaledSize)
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        fontFamily = .system
        fontSizeScale = 1.0
        showTimestamps = false
        compactMessages = false
        showAvatars = true
        autoConvertLongText = true
        longTextThreshold = 5000
        autoScrapeUrls = false
        cautiousEnter = false
        autoScroll = true
        streamResponses = true
        showThinking = true
        showCost = false
        showTokenCount = false
        monthlyBudgetAlert = 50.0
        enableBudgetAlerts = false
        enablePromptCaching = true
        enableDatetimeInjection = true
        enableAutoRefresh = true
        showContextEnhancementIndicator = true
        clearOnClose = false
        disableHistory = false
        anonymizeCode = false
        defaultModel = "claude-3-5-sonnet-20241022"
        defaultTemperature = 0.7
        maxTokens = 8192
        experimentalFeatures = false
        systemPromptPrefix = ""
        quickChatEnabled = true
        quickChatShortcut = "⌘⇧Space"
        ollamaUrl = "http://localhost:11434"
        mcpEnabled = true
        // Note: hasCompletedOnboarding is intentionally NOT reset
    }
}

// MARK: - Settings View

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    @State private var selectedSection: SettingsSection = .appearance

    enum SettingsSection: String, CaseIterable {
        case appearance = "Appearance"
        case behavior = "Behavior"
        case costUsage = "Cost & Usage"
        case privacy = "Privacy"
        case advanced = "Advanced"
        case shortcuts = "Shortcuts"
    }

    var body: some View {
        HSplitView {
            // Sidebar
            List(SettingsSection.allCases, id: \.self, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: iconFor(section))
            }
            .listStyle(.sidebar)
            .frame(width: 180)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedSection {
                    case .appearance:
                        appearanceSection
                    case .behavior:
                        behaviorSection
                    case .costUsage:
                        costUsageSection
                    case .privacy:
                        privacySection
                    case .advanced:
                        advancedSection
                    case .shortcuts:
                        shortcutsSection
                    }
                }
                .padding(24)
            }
            .frame(minWidth: 400)
        }
        .frame(width: 650, height: 500)
    }

    private func iconFor(_ section: SettingsSection) -> String {
        switch section {
        case .appearance: return "paintbrush"
        case .behavior: return "gearshape"
        case .costUsage: return "dollarsign.circle"
        case .privacy: return "lock.shield"
        case .advanced: return "wrench.and.screwdriver"
        case .shortcuts: return "keyboard"
        }
    }

    // MARK: - Appearance Section

    @ViewBuilder
    private var appearanceSection: some View {
        SettingsGroup(title: "Typography") {
            SettingRow(title: "Font Family", description: "Choose the font for the app") {
                Picker("", selection: $settings.fontFamily) {
                    ForEach(AppSettings.FontFamily.allCases) { font in
                        Text(font.rawValue).tag(font)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }

            SettingRow(title: "Font Size", description: "Scale: \(String(format: "%.0f%%", settings.fontSizeScale * 100))") {
                Slider(value: $settings.fontSizeScale, in: 0.8...1.4, step: 0.1)
                    .frame(width: 160)
            }
        }

        SettingsGroup(title: "Messages") {
            SettingToggle(
                title: "Show Timestamps",
                description: "Display time for each message",
                isOn: $settings.showTimestamps
            )

            SettingToggle(
                title: "Compact Mode",
                description: "Reduce spacing between messages",
                isOn: $settings.compactMessages
            )

            SettingToggle(
                title: "Show Avatars",
                description: "Display avatar icons in chat",
                isOn: $settings.showAvatars
            )
        }
    }

    // MARK: - Behavior Section

    @ViewBuilder
    private var behaviorSection: some View {
        SettingsGroup(title: "Input") {
            SettingToggle(
                title: "Cautious Enter",
                description: "Require Shift+Enter to send messages",
                isOn: $settings.cautiousEnter
            )

            SettingToggle(
                title: "Auto-convert Long Text",
                description: "Convert long pastes to file attachments",
                isOn: $settings.autoConvertLongText
            )

            if settings.autoConvertLongText {
                SettingRow(title: "Threshold", description: "\(settings.longTextThreshold) characters") {
                    Stepper("", value: $settings.longTextThreshold, in: 1000...20000, step: 1000)
                }
            }

            SettingToggle(
                title: "Auto-scrape URLs",
                description: "Fetch content from pasted URLs",
                isOn: $settings.autoScrapeUrls
            )
        }

        SettingsGroup(title: "Output") {
            SettingToggle(
                title: "Stream Responses",
                description: "Show responses as they generate",
                isOn: $settings.streamResponses
            )

            SettingToggle(
                title: "Auto-scroll",
                description: "Scroll to bottom on new messages",
                isOn: $settings.autoScroll
            )

            SettingToggle(
                title: "Show Thinking",
                description: "Display AI reasoning process",
                isOn: $settings.showThinking
            )
        }
    }

    // MARK: - Cost & Usage Section

    @ViewBuilder
    private var costUsageSection: some View {
        SettingsGroup(title: "Display") {
            SettingToggle(
                title: "Show Cost",
                description: "Display estimated cost per message",
                isOn: $settings.showCost
            )

            SettingToggle(
                title: "Show Token Count",
                description: "Display token usage per message",
                isOn: $settings.showTokenCount
            )
        }

        SettingsGroup(title: "Budget") {
            SettingToggle(
                title: "Enable Budget Alerts",
                description: "Get notified when approaching limit",
                isOn: $settings.enableBudgetAlerts
            )

            if settings.enableBudgetAlerts {
                SettingRow(title: "Monthly Limit", description: "$\(String(format: "%.0f", settings.monthlyBudgetAlert))") {
                    TextField("", value: $settings.monthlyBudgetAlert, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }
        }
    }

    // MARK: - Privacy Section

    @ViewBuilder
    private var privacySection: some View {
        SettingsGroup(title: "Conversation History") {
            SettingToggle(
                title: "Clear on Close",
                description: "Delete conversation when window closes",
                isOn: $settings.clearOnClose
            )

            SettingToggle(
                title: "Disable History",
                description: "Don't save conversation history",
                isOn: $settings.disableHistory
            )
        }

        SettingsGroup(title: "Code") {
            SettingToggle(
                title: "Anonymize Code",
                description: "Remove identifiers before sending",
                isOn: $settings.anonymizeCode
            )
        }
    }

    // MARK: - Advanced Section

    @ViewBuilder
    private var advancedSection: some View {
        SettingsGroup(title: "Model") {
            SettingRow(title: "Default Model", description: "Model for new conversations") {
                TextField("", text: $settings.defaultModel)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }

            SettingRow(title: "Temperature", description: String(format: "%.1f", settings.defaultTemperature)) {
                Slider(value: $settings.defaultTemperature, in: 0...2, step: 0.1)
                    .frame(width: 160)
            }

            SettingRow(title: "Max Tokens", description: "\(settings.maxTokens)") {
                Stepper("", value: $settings.maxTokens, in: 1024...32768, step: 1024)
            }
        }

        SettingsGroup(title: "System Prompt") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Prefix")
                    .font(.subheadline)
                TextEditor(text: $settings.systemPromptPrefix)
                    .frame(height: 80)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                Text("Added to the beginning of every conversation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        SettingsGroup(title: "Context Enhancement (Local Models)") {
            SettingToggle(
                title: "DateTime Injection",
                description: "Automatically inject current date/time into prompts",
                isOn: $settings.enableDatetimeInjection
            )

            SettingToggle(
                title: "Auto-Refresh Stale Queries",
                description: "Search web when detecting outdated information requests",
                isOn: $settings.enableAutoRefresh
            )

            SettingToggle(
                title: "Show Enhancement Indicator",
                description: "Display indicator when context was enhanced",
                isOn: $settings.showContextEnhancementIndicator
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("How it works")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Local models have knowledge cutoffs. When you ask about recent events, prices, or versions, Vaizor automatically searches for current info and injects it into the context.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }

        SettingsGroup(title: "Integrations") {
            SettingRow(title: "Ollama URL", description: "Local model server") {
                TextField("", text: $settings.ollamaUrl)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }

            SettingToggle(
                title: "Enable MCP",
                description: "Model Context Protocol servers",
                isOn: $settings.mcpEnabled
            )

            SettingToggle(
                title: "Experimental Features",
                description: "Enable beta functionality",
                isOn: $settings.experimentalFeatures
            )
        }

        HStack {
            Spacer()
            Button("Reset to Defaults") {
                settings.resetToDefaults()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Shortcuts Section

    @ViewBuilder
    private var shortcutsSection: some View {
        SettingsGroup(title: "Quick Chat") {
            SettingToggle(
                title: "Enable Quick Chat",
                description: "Open chat window with shortcut",
                isOn: $settings.quickChatEnabled
            )

            if settings.quickChatEnabled {
                SettingRow(title: "Shortcut", description: "Press keys to set") {
                    Text(settings.quickChatShortcut)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(4)
                }
            }
        }

        SettingsGroup(title: "Common Shortcuts") {
            KeyboardShortcutRow(action: "New Chat", shortcut: "⌘N")
            KeyboardShortcutRow(action: "Clear Chat", shortcut: "⌘K")
            KeyboardShortcutRow(action: "Focus Input", shortcut: "⌘L")
            KeyboardShortcutRow(action: "Toggle Sidebar", shortcut: "⌘\\")
            KeyboardShortcutRow(action: "Settings", shortcut: "⌘,")
            KeyboardShortcutRow(action: "Stop Generation", shortcut: "⎋")
        }
    }
}

// MARK: - Settings UI Components

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                content
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        }
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct SettingToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        SettingRow(title: title, description: description) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
        }
    }
}

struct KeyboardShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(action)
                .font(.system(size: 13))
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    AppSettingsView()
}
