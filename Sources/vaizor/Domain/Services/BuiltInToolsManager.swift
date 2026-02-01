import Foundation
import SwiftUI

/// Built-in tool definition with toggle capability
/// Inspired by Chorus's elegant toolset architecture
struct BuiltInTool: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let description: String
    let icon: String
    var isEnabled: Bool
    let category: ToolCategory

    enum ToolCategory: String, Codable, CaseIterable {
        case core = "Core"
        case web = "Web"
        case code = "Code"
        case artifacts = "Artifacts"

        var displayName: String { rawValue }
    }

    // Default built-in tools
    static let webSearch = BuiltInTool(
        id: "web_search",
        name: "web_search",
        displayName: "Web Search",
        description: "Search the web using DuckDuckGo for current information",
        icon: "globe",
        isEnabled: true,
        category: .web
    )

    static let codeExecution = BuiltInTool(
        id: "execute_code",
        name: "execute_code",
        displayName: "Code Execution",
        description: "Execute Python, JavaScript, Swift, and other code in a sandboxed environment",
        icon: "play.rectangle.fill",
        isEnabled: true,
        category: .code
    )

    static let shellExecution = BuiltInTool(
        id: "execute_shell",
        name: "execute_shell",
        displayName: "Shell Execution",
        description: "Execute Bash, Zsh, or PowerShell commands (requires explicit permission)",
        icon: "terminal.fill",
        isEnabled: false,  // Disabled by default for security
        category: .code
    )

    static let createArtifact = BuiltInTool(
        id: "create_artifact",
        name: "create_artifact",
        displayName: "Create Artifact",
        description: "Generate interactive React components, HTML, SVG, and Mermaid diagrams",
        icon: "wand.and.stars",
        isEnabled: true,
        category: .artifacts
    )

    static let browserAutomation = BuiltInTool(
        id: "browser_action",
        name: "browser_action",
        displayName: "Browser Control",
        description: "Control integrated browser - navigate, click, type, extract content, screenshot",
        icon: "globe",
        isEnabled: true,
        category: .web
    )

    static let allTools: [BuiltInTool] = [
        .webSearch,
        .browserAutomation,
        .codeExecution,
        .shellExecution,
        .createArtifact
    ]
}

/// Registration mode for tools (borrowed from Chorus)
enum ToolRegistrationMode {
    case all                           // Register all tools
    case none                          // Don't register any tools
    case filter((BuiltInTool) -> Bool) // Custom filter predicate
    case select([String])              // Explicit list of tool IDs to include
}

/// Tool status for UI display
enum ToolStatus: Equatable {
    case stopped
    case starting
    case running

    var color: Color {
        switch self {
        case .stopped: return .gray
        case .starting: return .yellow
        case .running: return .green
        }
    }

    var displayText: String {
        switch self {
        case .stopped: return "Disabled"
        case .starting: return "Starting..."
        case .running: return "Running"
        }
    }
}

/// Manager for built-in tools with toggle on/off support
@MainActor
class BuiltInToolsManager: ObservableObject {
    static let shared = BuiltInToolsManager()

    @Published var tools: [BuiltInTool] = []
    @Published var toolStatuses: [String: ToolStatus] = [:]

    private let userDefaultsKey = "builtInToolsEnabled"

    private init() {
        loadTools()
    }

    /// Load tools with saved enabled states
    private func loadTools() {
        let savedStates = loadSavedStates()

        tools = BuiltInTool.allTools.map { tool in
            var modifiedTool = tool
            if let savedEnabled = savedStates[tool.id] {
                modifiedTool.isEnabled = savedEnabled
            }
            return modifiedTool
        }

        // Initialize statuses
        for tool in tools {
            toolStatuses[tool.id] = tool.isEnabled ? .running : .stopped
        }
    }

    /// Save enabled states to UserDefaults
    private func saveStates() {
        var states: [String: Bool] = [:]
        for tool in tools {
            states[tool.id] = tool.isEnabled
        }

        if let data = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    /// Load saved states from UserDefaults
    private func loadSavedStates() -> [String: Bool] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let states = try? JSONDecoder().decode([String: Bool].self, from: data) else {
            return [:]
        }
        return states
    }

    /// Toggle a tool on/off
    func toggleTool(_ toolId: String) {
        guard let index = tools.firstIndex(where: { $0.id == toolId }) else { return }

        let wasEnabled = tools[index].isEnabled
        tools[index].isEnabled = !wasEnabled

        // Update status with animation-friendly timing
        if tools[index].isEnabled {
            toolStatuses[toolId] = .starting
            // Simulate brief startup delay for UX feedback
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                await MainActor.run {
                    if self.tools.first(where: { $0.id == toolId })?.isEnabled == true {
                        self.toolStatuses[toolId] = .running
                    }
                }
            }
        } else {
            toolStatuses[toolId] = .stopped
        }

        saveStates()

        AppLogger.shared.log(
            "Built-in tool '\(toolId)' \(tools[index].isEnabled ? "enabled" : "disabled")",
            level: .info
        )
    }

    /// Enable a tool by ID
    func enableTool(_ toolId: String) {
        guard let index = tools.firstIndex(where: { $0.id == toolId }),
              !tools[index].isEnabled else { return }
        toggleTool(toolId)
    }

    /// Disable a tool by ID
    func disableTool(_ toolId: String) {
        guard let index = tools.firstIndex(where: { $0.id == toolId }),
              tools[index].isEnabled else { return }
        toggleTool(toolId)
    }

    /// Check if a tool is enabled
    func isToolEnabled(_ toolId: String) -> Bool {
        tools.first(where: { $0.id == toolId })?.isEnabled ?? false
    }

    /// Get all enabled tools
    var enabledTools: [BuiltInTool] {
        tools.filter { $0.isEnabled }
    }

    /// Get tools by category
    func tools(in category: BuiltInTool.ToolCategory) -> [BuiltInTool] {
        tools.filter { $0.category == category }
    }

    /// Get running tool count for UI display
    var runningToolCount: Int {
        toolStatuses.values.filter { $0 == .running }.count
    }

    /// Get tool definitions for LLM system prompt
    func getToolDefinitionsForPrompt() -> String {
        var definitions: [String] = []

        for tool in enabledTools {
            definitions.append("""
            - **\(tool.name)**: \(tool.description)
            """)
        }

        return definitions.joined(separator: "\n")
    }

    /// Get tool schemas for API calls (OpenAI/Anthropic format)
    /// Uses centralized ToolSchemas as the single source of truth
    /// Includes internal helper tools that are always available
    func getToolSchemas() -> [[String: Any]] {
        let enabledSchemas = enabledTools.compactMap { tool in
            ToolSchemas.schema(for: tool.id)
        }
        // Add internal tools (always enabled, not shown to users)
        let allSchemas = enabledSchemas + ToolSchemas.allInternal
        return ToolSchemas.asAnthropicFormat(allSchemas)
    }

    /// Get tool schemas in OpenAI/Ollama format
    /// Includes internal helper tools that are always available
    func getToolSchemasOpenAI() -> [[String: Any]] {
        let enabledSchemas = enabledTools.compactMap { tool in
            ToolSchemas.schema(for: tool.id)
        }
        // Add internal tools (always enabled, not shown to users)
        let allSchemas = enabledSchemas + ToolSchemas.allInternal
        return ToolSchemas.asOpenAIFormat(allSchemas)
    }
}

// MARK: - SwiftUI View for Tools Toggle

struct BuiltInToolsToggleView: View {
    @ObservedObject var manager = BuiltInToolsManager.shared
    @State private var searchText = ""

    private var filteredTools: [BuiltInTool] {
        if searchText.isEmpty {
            return manager.tools
        }
        return manager.tools.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search tools...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Tools list grouped by category
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(BuiltInTool.ToolCategory.allCases, id: \.self) { category in
                        let categoryTools = filteredTools.filter { $0.category == category }
                        if !categoryTools.isEmpty {
                            toolCategorySection(category: category, tools: categoryTools)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func toolCategorySection(category: BuiltInTool.ToolCategory, tools: [BuiltInTool]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header
            Text(category.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor))

            // Tools in category
            ForEach(tools) { tool in
                ToolRowView(tool: tool, status: manager.toolStatuses[tool.id] ?? .stopped) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.toggleTool(tool.id)
                    }
                }

                if tool.id != tools.last?.id {
                    Divider()
                        .padding(.leading, 48)
                }
            }
        }
    }
}

struct ToolRowView: View {
    let tool: BuiltInTool
    let status: ToolStatus
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Tool icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(tool.isEnabled ? 0.15 : 0.08))
                    .frame(width: 32, height: 32)

                Image(systemName: tool.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tool.isEnabled ? Color.accentColor : .secondary)
            }

            // Tool info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tool.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    // Status indicator
                    statusIndicator
                }

                Text(tool.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Toggle switch
            Toggle("", isOn: Binding(
                get: { tool.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .scaleEffect(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)

            if status == .starting {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
        }
    }
}

// MARK: - Compact Tools Button for Input Bar

struct BuiltInToolsButton: View {
    @ObservedObject var manager = BuiltInToolsManager.shared
    @State private var showToolsPopover = false

    var body: some View {
        Button {
            showToolsPopover.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 14))
                    .foregroundStyle(manager.runningToolCount > 0 ? Color(hex: "00976d") : .secondary)

                // Running tools count badge
                if manager.runningToolCount > 0 {
                    Text("\(manager.runningToolCount)")
                        .font(.caption2)
                        .fontWeight(.medium)
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
        .help("Manage built-in tools")
        .popover(isPresented: $showToolsPopover) {
            BuiltInToolsToggleView()
                .frame(width: 320, height: 350)
        }
    }
}
