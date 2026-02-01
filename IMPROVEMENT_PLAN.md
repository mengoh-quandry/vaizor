# Vaizor Improvement Plan
## Path to Feature Parity with Claude Desktop & ChatGPT

**Generated:** February 2026
**Current State:** Solid foundation, ~60% feature parity
**Target State:** Production-ready, frontier LLM client

---

## Executive Summary

**Strategic Goal:** Achieve full feature parity with Claude Desktop as the primary target, then differentiate.

Vaizor is a well-architected macOS AI chat client with strong fundamentals:
- Clean MVVM + Clean Architecture
- Multi-provider support (Claude, OpenAI, Gemini, Ollama)
- Basic MCP integration
- Code execution sandbox
- Artifact visualization (11 types)

However, significant gaps exist compared to Claude Desktop and ChatGPT:

| Area | Current Grade | Target | Effort |
|------|---------------|--------|--------|
| **Code Quality** | B- | A | 2-3 weeks |
| **MCP Compliance** | C+ | A- | 3-4 weeks |
| **UI/UX Polish** | C+ | A | 4-6 weeks |
| **Feature Parity** | D+ | B+ | 6-8 weeks |
| **Accessibility** | D | B | 2-3 weeks |

**Total Estimated Effort:** 16-24 weeks for full feature parity

---

## Part 1: Critical Bug Fixes (P0)

### 1.1 Race Condition in MCP Server Connection
**File:** `Sources/vaizor/Domain/Services/MCPServer.swift:1061-1062`

**Issue:** `pendingRequests` dictionary protected by `NSLock` has race condition - lock released between storing continuation and writing to stdin.

**Fix:**
```swift
// Replace NSLock + dictionary with an actor
actor RequestManager {
    private var pendingRequests: [Int: CheckedContinuation<[String: AnyCodable], Error>] = [:]
    private var messageId = 0

    func createRequest() -> (Int, CheckedContinuation<[String: AnyCodable], Error>) async {
        messageId += 1
        // continuation stored atomically with ID creation
    }
}
```

### 1.2 @unchecked Sendable Violations
**File:** `Sources/vaizor/Data/Database/DatabaseManager.swift:4`

**Issue:** `DatabaseManager` marked `@unchecked Sendable` without proper documentation or safety guarantees.

**Fix:** Either:
- Document why it's safe (Swift's lazy static initialization)
- Convert to actor pattern for clearer safety

### 1.3 Missing Transaction Safety
**File:** `Sources/vaizor/Data/Repositories/ConversationManager.swift:84-89`

**Issue:** In-memory state updated before database write succeeds.

**Fix:**
```swift
func createConversation(title: String) async throws -> Conversation {
    let newConversation = Conversation(title: title)
    try await dbQueue.write { db in
        try ConversationRecord(newConversation).insert(db)
    }
    // Only update in-memory AFTER successful write
    await MainActor.run {
        conversations.insert(newConversation, at: 0)
    }
    return newConversation
}
```

### 1.4 Silent Error Handling
**File:** `Sources/vaizor/Domain/Services/DependencyContainer.swift:116-120`

**Issue:** Ollama model loading errors swallowed silently.

**Fix:** Surface errors to UI via published error state or error banner.

### 1.5 Memory Leak in Parallel Execution
**File:** `Sources/vaizor/Domain/Services/ParallelModelExecutor.swift:186-191`

**Issue:** `cancel()` doesn't actually cancel running tasks.

**Fix:**
```swift
private var runningTasks: [Task<Void, Never>] = []

func cancel() {
    for task in runningTasks {
        task.cancel()
    }
    runningTasks.removeAll()
    isExecuting = false
}
```

### 1.6 Process Resource Leak
**File:** `Sources/vaizor/Domain/Services/MCPServer.swift:1123-1129`

**Issue:** `process.terminate()` called without waiting for cleanup.

**Fix:**
```swift
func stop() async {
    process.terminate()
    // Wait for graceful exit with timeout
    try? await withTimeout(seconds: 5) {
        process.waitUntilExit()
    }
    // Close pipes explicitly
    process.standardInput = nil
    process.standardOutput = nil
    process.standardError = nil
}
```

### 1.7 Hardcoded Ollama Path
**File:** `Sources/vaizor/Domain/Services/DependencyContainer.swift:93`

**Issue:** `/opt/homebrew/bin/ollama` won't work on Intel Macs.

**Fix:**
```swift
func findOllamaPath() -> URL? {
    let paths = [
        "/opt/homebrew/bin/ollama",  // Apple Silicon Homebrew
        "/usr/local/bin/ollama",      // Intel Homebrew
        "/usr/bin/ollama"             // System install
    ]
    for path in paths {
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
    }
    // Fallback to which
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["ollama"]
    // ... execute and parse
}
```

---

## Part 2: MCP Protocol Compliance

### Current State
- **Tools:** ✅ Basic implementation works
- **Resources:** ⚠️ Read-only, no subscriptions
- **Prompts:** ⚠️ Basic, no dynamic updates
- **Sampling:** ❌ Not implemented (critical gap)
- **Roots:** ❌ Not implemented
- **Notifications:** ❌ All silently dropped

### 2.1 Notification Handler (Critical)
**Current:** Line 1576-1580 drops all notifications with a log message.

**Required Implementation:**
```swift
private func handleNotification(method: String, params: [String: Any]) {
    switch method {
    case "notifications/tools/listChanged":
        Task { await refreshToolsForServer(serverId) }
    case "notifications/resources/listChanged":
        Task { await refreshResourcesForServer(serverId) }
    case "notifications/resources/updated":
        let uri = params["uri"] as? String
        Task { await handleResourceUpdate(uri) }
    case "notifications/prompts/listChanged":
        Task { await refreshPromptsForServer(serverId) }
    case "notifications/progress":
        let token = params["progressToken"] as? String
        let progress = params["progress"] as? Double
        Task { await updateProgress(token, progress) }
    case "notifications/message":
        let level = params["level"] as? String
        let message = params["message"] as? String
        Task { await handleLogMessage(level, message) }
    default:
        AppLogger.shared.log("Unknown notification: \(method)", level: .debug)
    }
}
```

### 2.2 Sampling Support (Critical for Agentic Servers)
Servers need to be able to request LLM completions through the client.

**Required:**
1. Add `sampling` to client capabilities in initialize request
2. Handle `sampling/createMessage` requests
3. Route to active LLM provider
4. Return streamed responses

```swift
// Client capabilities update
"capabilities": [
    "sampling": [:],  // Add this
    "tools": [:],
    // ...
]

// Handler for sampling requests
func handleSamplingRequest(_ params: [String: Any]) async throws -> [String: Any] {
    let messages = params["messages"] as? [[String: Any]] ?? []
    let modelPrefs = params["modelPreferences"] as? [String: Any]

    // Convert to internal message format
    let convertedMessages = messages.map { /* ... */ }

    // Get response from active provider
    let response = try await activeProvider.complete(
        messages: convertedMessages,
        maxTokens: modelPrefs?["maxTokens"] as? Int ?? 1000
    )

    return [
        "role": "assistant",
        "content": ["type": "text", "text": response]
    ]
}
```

### 2.3 Roots Support
Add filesystem boundary negotiation for security.

```swift
// Add to capabilities
"roots": ["listChanged": true]

// Handler
func handleRootsListRequest() -> [[String: String]] {
    // Return workspace roots
    return [
        ["uri": "file://\(FileManager.default.homeDirectoryForCurrentUser.path)", "name": "Home"],
        ["uri": "file://\(currentProjectPath)", "name": "Project"]
    ]
}
```

### 2.4 Resource Subscriptions
Enable real-time resource updates.

```swift
// Update capabilities
"resources": ["subscribe": true, "listChanged": true]

// Track subscriptions
private var resourceSubscriptions: [String: Set<String>] = [:] // serverId -> uris

func subscribeToResource(uri: String, serverId: String) async throws {
    try await sendRequest(method: "resources/subscribe", params: ["uri": uri])
    resourceSubscriptions[serverId, default: []].insert(uri)
}
```

### 2.5 MCP Apps Protocol (Future)
For parity with Claude Desktop's new MCP Apps extension:
- Implement iframe sandboxing for UI rendering
- Handle bidirectional messaging
- Security sandbox for third-party UIs

**Effort:** Large (2-3 weeks)

---

## Part 3: UI/UX Improvements

### 3.1 Message Display (High Priority)

#### Visual Hierarchy Fix
**Current:** Hard green user messages, invisible assistant backgrounds.

**Fix in MessageBubbleView.swift:**
```swift
private var backgroundColor: some View {
    Group {
        switch message.role {
        case .user:
            ThemeColors.accent.opacity(0.15)  // Subtle tint, not solid
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ThemeColors.accent.opacity(0.3), lineWidth: 1)
                )
        case .assistant:
            ThemeColors.surface  // Subtle background
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ThemeColors.border, lineWidth: 0.5)
                )
        // ...
        }
    }
}
```

#### Syntax Highlighting for Code Blocks
**Current:** Plain monospaced text.

**Fix:** Integrate `Splash` or `Highlightr` for syntax highlighting:
```swift
import Highlightr

struct SyntaxHighlightedCode: View {
    let code: String
    let language: String

    var body: some View {
        if let highlightr = Highlightr(),
           let highlighted = highlightr.highlight(code, as: language) {
            Text(AttributedString(highlighted))
                .font(.system(.body, design: .monospaced))
        } else {
            Text(code)
                .font(.system(.body, design: .monospaced))
        }
    }
}
```

### 3.2 Input Experience

#### Rich File Preview
**Current:** Basic text list of dropped files.

**Fix:**
```swift
struct FilePreviewView: View {
    let file: DroppedFile

    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail for images
            if file.isImage, let thumbnail = file.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                // File type icon
                Image(systemName: file.systemIcon)
                    .font(.system(size: 24))
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.caption)
                    .lineLimit(1)
                Text(file.formattedSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { onRemove() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(ThemeColors.surface)
        .cornerRadius(8)
    }
}
```

### 3.3 Loading & Streaming States

#### Skeleton Loaders
Replace "Loading..." text with skeleton UI:
```swift
struct MessageSkeleton: View {
    @State private var shimmer = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(ThemeColors.surface)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ThemeColors.surface)
                    .frame(height: 12)
                    .frame(maxWidth: 200)

                RoundedRectangle(cornerRadius: 4)
                    .fill(ThemeColors.surface)
                    .frame(height: 12)
                    .frame(maxWidth: 300)
            }
        }
        .opacity(shimmer ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1).repeatForever(), value: shimmer)
        .onAppear { shimmer = true }
    }
}
```

#### Progress Indicator for Tools
```swift
struct ToolProgressView: View {
    let toolName: String
    let progress: Double? // nil = indeterminate
    let status: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.2")
                .symbolEffect(.rotate, isActive: progress == nil)

            VStack(alignment: .leading, spacing: 4) {
                Text("Running \(toolName)")
                    .font(.caption)
                    .fontWeight(.medium)

                if let progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                } else {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(ThemeColors.toolBackground)
        .cornerRadius(8)
    }
}
```

### 3.4 Settings Improvements

#### Search Functionality
```swift
struct SettingsSearchBar: View {
    @Binding var searchText: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search settings...", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(ThemeColors.surface)
        .cornerRadius(8)
    }
}

// Filter settings based on search
var filteredSettings: [SettingItem] {
    guard !searchText.isEmpty else { return allSettings }
    return allSettings.filter { setting in
        setting.title.localizedCaseInsensitiveContains(searchText) ||
        setting.description.localizedCaseInsensitiveContains(searchText) ||
        setting.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
    }
}
```

#### API Key Validation
```swift
struct APIKeyField: View {
    @Binding var key: String
    @State private var validationState: ValidationState = .idle
    let provider: LLMProvider

    enum ValidationState {
        case idle, validating, valid, invalid(String)
    }

    var body: some View {
        HStack {
            SecureField("Enter API key", text: $key)
                .textFieldStyle(.plain)

            switch validationState {
            case .idle:
                EmptyView()
            case .validating:
                ProgressView()
                    .scaleEffect(0.7)
            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .invalid(let error):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(error)
            }
        }
        .onChange(of: key) { _, newValue in
            validateAPIKey(newValue)
        }
    }

    func validateAPIKey(_ key: String) {
        guard !key.isEmpty else {
            validationState = .idle
            return
        }

        validationState = .validating

        Task {
            do {
                let isValid = try await provider.validateKey(key)
                await MainActor.run {
                    validationState = isValid ? .valid : .invalid("Invalid key")
                }
            } catch {
                await MainActor.run {
                    validationState = .invalid(error.localizedDescription)
                }
            }
        }
    }
}
```

### 3.5 Error Handling UI

#### Actionable Error Cards
```swift
struct ErrorCard: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    let onSettings: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.icon)
                .font(.title2)
                .foregroundStyle(error.color)

            VStack(alignment: .leading, spacing: 4) {
                Text(error.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(error.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if let onRetry {
                    Button("Retry", action: onRetry)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }

                if let onSettings {
                    Button("Settings", action: onSettings)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(error.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(error.color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

enum AppError {
    case network(String)
    case apiKey(LLMProvider)
    case rateLimit(TimeInterval)
    case serverError(Int, String)

    var icon: String {
        switch self {
        case .network: return "wifi.slash"
        case .apiKey: return "key.fill"
        case .rateLimit: return "clock.badge.exclamationmark"
        case .serverError: return "exclamationmark.icloud"
        }
    }

    var color: Color {
        switch self {
        case .network: return .orange
        case .apiKey: return .red
        case .rateLimit: return .yellow
        case .serverError: return .red
        }
    }
}
```

---

## Part 4: Feature Parity Gaps

### 4.1 Claude Desktop Features Missing

| Feature | Priority | Effort | Description |
|---------|----------|--------|-------------|
| **MCP Apps** | High | 3 weeks | Interactive UI rendering from MCP servers |
| **Desktop Extensions** | High | 2 weeks | One-click MCP server installation |
| **Skills** | Medium | 1 week | Lightweight instruction sets |
| **Memory/Projects** | Medium | 2 weeks | Project-scoped context persistence |
| **@-mentions** | Medium | 1 week | Reference files in input |
| **Conversation Branching** | Low | 1 week | Fork from any message |
| **Inline Citations** | Low | 1 week | Hover previews for sources |

### 4.2 ChatGPT Features Missing

| Feature | Priority | Effort | Description |
|---------|----------|--------|-------------|
| **Canvas (full)** | High | 3 weeks | Side-by-side document editing |
| **Voice Input** | Medium | 1 week | Speech-to-text input |
| **Conversation Search** | Medium | 3 days | Global search across chats |
| **Shared Conversations** | Low | 1 week | Public/private sharing |
| **Usage Dashboard** | Low | 3 days | Cost and usage analytics |
| **Custom GPTs** | Low | 2 weeks | User-created specialized modes |

### 4.3 Implementation Details

#### Memory/Projects System
```swift
// Domain Model
struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    var conversations: [UUID]  // Linked conversation IDs
    var context: ProjectContext
    var createdAt: Date
}

struct ProjectContext: Codable {
    var systemPrompt: String?
    var files: [ProjectFile]
    var instructions: [String]
    var mcpServers: [UUID]  // Project-specific MCP servers
}

// Repository
class ProjectRepository {
    func createProject(name: String) async throws -> Project
    func addConversation(to project: UUID, conversation: UUID) async throws
    func getContext(for project: UUID) async throws -> ProjectContext
}

// View Integration
struct ProjectSidebar: View {
    @State private var projects: [Project] = []
    @State private var selectedProject: UUID?

    var body: some View {
        List(selection: $selectedProject) {
            Section("Projects") {
                ForEach(projects) { project in
                    ProjectRow(project: project)
                }
            }
        }
    }
}
```

#### @-Mentions for File Context
```swift
struct MentionableInput: View {
    @Binding var text: String
    @State private var showMentions = false
    @State private var mentionQuery = ""
    @State private var cursorPosition: Int = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .onChange(of: text) { _, newValue in
                    checkForMentionTrigger(newValue)
                }

            if showMentions {
                MentionSuggestions(
                    query: mentionQuery,
                    onSelect: { mention in
                        insertMention(mention)
                    }
                )
                .offset(y: calculatePopoverOffset())
            }
        }
    }

    func checkForMentionTrigger(_ text: String) {
        // Detect @ followed by characters
        let pattern = /@(\w*)$/
        if let match = text.range(of: pattern, options: .regularExpression) {
            mentionQuery = String(text[match]).dropFirst().description
            showMentions = true
        } else {
            showMentions = false
        }
    }
}

struct MentionSuggestions: View {
    let query: String
    let onSelect: (Mention) -> Void

    var filteredMentions: [Mention] {
        // Filter files, conversations, etc. by query
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(filteredMentions) { mention in
                MentionRow(mention: mention)
                    .onTapGesture { onSelect(mention) }
            }
        }
        .background(ThemeColors.surface)
        .cornerRadius(8)
        .shadow(radius: 8)
    }
}
```

---

## Part 5: Accessibility Fixes

### 5.1 Keyboard Navigation
```swift
// Add to MessageBubbleView
.focusable()
.onKeyPress(.upArrow) { focusPreviousMessage() }
.onKeyPress(.downArrow) { focusNextMessage() }
.onKeyPress(.return) { showActions() }
.onKeyPress(.escape) { dismissActions() }

// Add to ChatView
.focusScope(chatFocusNamespace)
.defaultFocus($focusedMessage, messages.last?.id)
```

### 5.2 Screen Reader Support
```swift
// Add to all icon buttons
Button(action: copyMessage) {
    Image(systemName: "doc.on.doc")
}
.accessibilityLabel("Copy message")
.accessibilityHint("Copies the message content to clipboard")

// Add to message bubbles
MessageBubbleView(message: message)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(message.role.rawValue) message: \(message.content)")
    .accessibilityAddTraits(message.role == .user ? .isButton : [])
```

### 5.3 Reduced Motion
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// In ThinkingIndicator
.onAppear {
    guard !reduceMotion else { return }
    withAnimation(.easeInOut(duration: 1.5).repeatForever()) {
        glowPhase = 1.0
    }
}

// Alternative for reduced motion
var body: some View {
    if reduceMotion {
        // Static indicator
        HStack(spacing: 8) {
            ProgressView()
            Text(status)
        }
    } else {
        // Animated indicator
        AnimatedThinkingIndicator(status: status)
    }
}
```

### 5.4 Color Contrast
```swift
// Update ThemeColors for WCAG AA compliance
struct ThemeColors {
    // Ensure 4.5:1 contrast ratio for normal text
    static let primaryText = Color(hex: "FFFFFF")      // White on dark
    static let secondaryText = Color(hex: "A0A0A0")    // 4.5:1 on #1c1d1f
    static let tertiaryText = Color(hex: "808080")     // Use sparingly

    // Links need 3:1 against surrounding text
    static let link = Color(hex: "66D9A5")             // Lighter green
}
```

---

## Part 6: Prompt Caching (Cost Optimization)

### Why Prompt Caching Matters
Claude's prompt caching provides a **90% discount** on cached input tokens. For an app with:
- Long system prompts (1000+ tokens)
- Multi-turn conversations (accumulating context)
- Repeated tool schemas

This can reduce API costs by 50-70% for typical usage patterns.

### Implementation Requirements

#### 6.1 Claude API Caching Structure
```swift
// Message structure with cache control
struct CachedMessage: Codable {
    let role: String
    let content: [ContentBlock]
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
    let cacheControl: CacheControl?

    enum CodingKeys: String, CodingKey {
        case type, text
        case cacheControl = "cache_control"
    }
}

struct CacheControl: Codable {
    let type: String  // "ephemeral"
}
```

#### 6.2 Request Structure for Maximum Cache Hits
```swift
// Structure requests for caching:
// 1. System prompt (cacheable - stable across requests)
// 2. Tool definitions (cacheable - stable across requests)
// 3. Conversation history prefix (cacheable - grows but stable)
// 4. Recent messages (not cached - changes each request)

func buildCachedRequest(conversation: Conversation) -> [String: Any] {
    var messages: [[String: Any]] = []

    // System prompt with cache control
    messages.append([
        "role": "system",
        "content": [
            [
                "type": "text",
                "text": conversation.systemPrompt,
                "cache_control": ["type": "ephemeral"]
            ]
        ]
    ])

    // Split conversation: cache older messages, don't cache recent
    let cacheBreakpoint = max(0, conversation.messages.count - 4)
    let cachedMessages = Array(conversation.messages.prefix(cacheBreakpoint))
    let recentMessages = Array(conversation.messages.suffix(4))

    // Add cached prefix with cache control on last cached message
    for (index, msg) in cachedMessages.enumerated() {
        var content: [[String: Any]] = [["type": "text", "text": msg.content]]
        if index == cachedMessages.count - 1 {
            content[0]["cache_control"] = ["type": "ephemeral"]
        }
        messages.append(["role": msg.role, "content": content])
    }

    // Add recent messages without caching
    for msg in recentMessages {
        messages.append(["role": msg.role, "content": msg.content])
    }

    return ["messages": messages]
}
```

#### 6.3 Cache Metrics Tracking
```swift
// Extend CostTracker to handle cache metrics
struct CacheMetrics {
    var cacheCreationInputTokens: Int = 0
    var cacheReadInputTokens: Int = 0
    var regularInputTokens: Int = 0
    var outputTokens: Int = 0

    var cacheHitRate: Double {
        let total = cacheCreationInputTokens + cacheReadInputTokens + regularInputTokens
        guard total > 0 else { return 0 }
        return Double(cacheReadInputTokens) / Double(total)
    }

    var estimatedSavings: Double {
        // Cache reads are 90% cheaper
        let fullPriceTokens = cacheReadInputTokens
        let discountedCost = Double(fullPriceTokens) * 0.1
        let savings = Double(fullPriceTokens) - discountedCost
        return savings
    }
}

// Parse from API response
extension CostTracker {
    func updateFromResponse(_ response: [String: Any]) {
        if let usage = response["usage"] as? [String: Any] {
            metrics.cacheCreationInputTokens += usage["cache_creation_input_tokens"] as? Int ?? 0
            metrics.cacheReadInputTokens += usage["cache_read_input_tokens"] as? Int ?? 0
            metrics.regularInputTokens += usage["input_tokens"] as? Int ?? 0
            metrics.outputTokens += usage["output_tokens"] as? Int ?? 0
        }
    }
}
```

#### 6.4 Caching Requirements & Constraints
- **Minimum cacheable size:** 1024 tokens (shorter prompts won't be cached)
- **Cache TTL:** 5 minutes (must send requests within window to get cache hits)
- **Max cache breakpoints:** 4 per request
- **Beta header required:** `anthropic-beta: prompt-caching-2024-07-31`

#### 6.5 Settings Integration
```swift
// Add to AppSettings
@AppStorage("enablePromptCaching") var enablePromptCaching: Bool = true
@AppStorage("showCacheMetrics") var showCacheMetrics: Bool = false

// UI in ComprehensiveSettingsView
Toggle("Enable prompt caching (reduces API costs)", isOn: $settings.enablePromptCaching)
Toggle("Show cache metrics in conversation", isOn: $settings.showCacheMetrics)

// Cache stats display (when enabled)
if settings.showCacheMetrics {
    HStack {
        Text("Cache hit rate: \(costTracker.cacheHitRate, specifier: "%.1f")%")
        Text("Saved: $\(costTracker.estimatedSavings, specifier: "%.4f")")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
}
```

#### 6.6 Multi-Provider Caching Support

| Provider | Caching Support | Implementation |
|----------|-----------------|----------------|
| **Claude** | ✅ Full support | cache_control blocks |
| **OpenAI** | ⚠️ Automatic | No explicit control needed |
| **Gemini** | ⚠️ Context caching | Different API |
| **Ollama** | ❌ Local | N/A |

---

## Part 7: Testing Infrastructure

### Current State
No test files exist in the codebase.

### Required Test Coverage

#### Unit Tests
```swift
// MCPServerConnectionTests.swift
class MCPServerConnectionTests: XCTestCase {
    func testJSONRPCEncoding() async throws {
        let connection = MockMCPServerConnection()
        let request = try connection.encodeRequest(
            method: "tools/list",
            params: [:]
        )
        XCTAssertEqual(request["jsonrpc"] as? String, "2.0")
    }

    func testNotificationRouting() async {
        let manager = MCPServerManager()
        let notification = [
            "method": "notifications/tools/listChanged",
            "params": [:]
        ]

        await manager.handleNotification(notification)

        // Assert tools were refreshed
    }
}

// MessageViewModelTests.swift
class ChatViewModelTests: XCTestCase {
    func testStreamingBufferFlush() async {
        let viewModel = ChatViewModel()
        viewModel.appendToStreamingBuffer("Hello")
        viewModel.appendToStreamingBuffer(" World")

        try? await Task.sleep(nanoseconds: 60_000_000) // 60ms

        XCTAssertEqual(viewModel.currentStreamingText, "Hello World")
    }
}
```

#### Integration Tests
```swift
// MCPIntegrationTests.swift
class MCPIntegrationTests: XCTestCase {
    func testServerLifecycle() async throws {
        let manager = MCPServerManager()
        let server = MCPServer(
            name: "test",
            command: "echo",
            args: ["test"]
        )

        try await manager.startServer(server)
        XCTAssertTrue(manager.enabledServers.contains(server.id))

        await manager.stopServer(server)
        XCTAssertFalse(manager.enabledServers.contains(server.id))
    }
}
```

#### UI Tests
```swift
// ChatViewUITests.swift
class ChatViewUITests: XCTestCase {
    func testMessageSending() throws {
        let app = XCUIApplication()
        app.launch()

        let input = app.textFields["Message input"]
        input.tap()
        input.typeText("Hello, world!")

        app.buttons["Send"].tap()

        XCTAssertTrue(app.staticTexts["Hello, world!"].exists)
    }
}
```

---

## Part 7: Prioritized Roadmap

### Phase 1: Stability (Weeks 1-3) ⚡ IN PROGRESS
**Goal:** Fix critical bugs, establish testing

- [x] Fix race condition in MCP connection (actor pattern)
- [x] Fix transaction safety in repositories
- [x] Fix memory leak in parallel executor
- [x] Fix process resource leak
- [x] Fix hardcoded Ollama path
- [x] Surface silent errors to UI
- [ ] Add unit tests for core services
- [ ] Add integration tests for MCP

### Phase 2: MCP Compliance (Weeks 4-6) ⚡ IN PROGRESS
**Goal:** Full MCP spec implementation - CRITICAL for Claude Desktop parity

- [x] Implement notification handler
- [x] Add sampling support
- [x] Add roots support
- [x] Add resource subscriptions
- [x] Add progress notifications
- [ ] Add cancellation support
- [ ] Test with 10+ popular MCP servers

### Phase 3: UI/UX Polish (Weeks 7-10) ⚡ IN PROGRESS
**Goal:** Match Claude Desktop quality

- [x] Visual hierarchy fixes (message backgrounds)
- [x] Syntax highlighting for code blocks
- [x] Rich file preview in input
- [x] Skeleton loaders
- [x] Settings search
- [x] Actionable error cards
- [x] Accessibility fixes
- [ ] Tool progress indicators
- [ ] API key validation UI

### Phase 3.5: Prompt Caching (Week 10) ⚡ IN PROGRESS
**Goal:** 50-70% API cost reduction

- [x] Claude API cache_control implementation
- [x] Cache metrics tracking
- [ ] Settings integration
- [ ] Cache hit rate display
- [ ] Multi-provider support

### Phase 4: Feature Parity (Weeks 11-16)
**Goal:** Match Claude Desktop features - PRIMARY TARGET

| Feature | Claude Desktop | Priority | Status |
|---------|----------------|----------|--------|
| Memory/Projects | ✅ | P0 | Pending |
| @-mentions | ✅ | P0 | Pending |
| Desktop Extensions | ✅ | P1 | Pending |
| MCP Apps | ✅ | P1 | Pending |
| Skills System | ✅ | P2 | Pending |
| Conversation Branching | ✅ | P2 | Pending |

- [ ] Memory/Projects system (project-scoped context)
- [ ] @-mentions for file context
- [ ] Desktop extensions (one-click MCP install)
- [ ] MCP Apps support (iframe UI rendering)
- [ ] Skills system (lightweight instruction sets)
- [ ] Global conversation search
- [ ] Conversation branching
- [ ] Voice input

### Phase 5: Differentiation (Weeks 17-24) ⚡ IN PROGRESS
**Goal:** Unique features that exceed Claude Desktop

#### 5.1 Invisible Context Enhancement (Local Model Intelligence)
Non-user-visible tools that enhance local model capabilities:

| Tool | Purpose | Visibility |
|------|---------|------------|
| **DateTime Injection** | Inject current time/date on every request | Hidden |
| **Knowledge Staleness Detection** | Detect outdated info, auto-fetch current data | Chain-of-thought |
| **Context Delta Display** | Show model training date vs. current world state | Subtle UI |

#### 5.2 Extended Code Execution
Expand beyond Python/JS to full shell support:

| Shell | Platform | Use Cases |
|-------|----------|-----------|
| **Bash** | macOS/Linux | System automation, file ops |
| **Zsh** | macOS | Advanced scripting |
| **PowerShell** | Cross-platform | Windows compat, Azure/O365 |

#### 5.3 AiEDR (AI Endpoint Detection & Response)
Security-first AI client with built-in threat detection:

| Component | Function |
|-----------|----------|
| **Prompt Injection Defense** | Already implemented, enhance |
| **Output Sanitization** | Detect malicious code in responses |
| **Host Security Checks** | System vulnerability scanning |
| **AI Threat Detection** | Jailbreak attempts, data exfil patterns |
| **Audit Logging** | Full conversation forensics |
| **Compliance Mode** | Enterprise security policies |

#### 5.4 Native Browser Integration
Embedded browser for AI-assisted web interaction:

| Feature | Description |
|---------|-------------|
| **Embedded WebView** | Browser within Vaizor |
| **AI Page Analysis** | Extract/summarize page content |
| **Browser Automation** | Playwright/Puppeteer-style control |
| **Form Filling** | AI-assisted form completion |
| **Screenshot Analysis** | Visual understanding of pages |
| **Session Persistence** | Maintain auth across tasks |

#### 5.5 Existing Advantages (Already Built)
- Multi-model orchestration (parallel execution)
- Advanced artifact system (11 types)
- Local-first with Ollama (privacy)
- Prompt caching (cost efficiency)

### Phase 6: Launch
**Goal:** Production readiness

- [ ] Performance optimization
- [ ] Memory profiling
- [ ] Crash reporting integration
- [ ] Analytics (opt-in)
- [ ] Documentation
- [ ] App Store preparation
- [ ] Beta testing program

---

## Appendix A: File Reference

### Critical Files to Modify

| File | Changes | Priority |
|------|---------|----------|
| `MCPServer.swift` | Notification handler, sampling, roots | P0 |
| `ChatViewModel.swift` | Cancellation, progress, error handling | P0 |
| `DatabaseManager.swift` | Transaction safety, actor pattern | P0 |
| `ConversationManager.swift` | Transaction safety | P0 |
| `DependencyContainer.swift` | Error surfacing, dynamic paths | P1 |
| `ParallelModelExecutor.swift` | Task cancellation | P1 |
| `MessageBubbleView.swift` | Visual hierarchy, syntax highlighting | P1 |
| `ChatView.swift` | Skeleton loaders, file preview | P1 |
| `ComprehensiveSettingsView.swift` | Search, validation | P2 |

### New Files Required

| File | Purpose |
|------|---------|
| `Tests/MCPTests/` | MCP unit and integration tests |
| `Tests/ViewModelTests/` | ViewModel unit tests |
| `Tests/UITests/` | UI automation tests |
| `Project.swift` | Project/memory model |
| `ProjectRepository.swift` | Project persistence |
| `MentionableInput.swift` | @-mention input component |
| `SkeletonView.swift` | Loading skeleton component |
| `ErrorCard.swift` | Actionable error component |

---

## Appendix B: Dependency Recommendations

### Add These Dependencies

```swift
// Package.swift additions
.package(url: "https://github.com/JohnSundell/Splash", from: "0.16.0"),  // Syntax highlighting
.package(url: "https://github.com/scinfu/SwiftSoup", from: "2.6.0"),     // HTML parsing
.package(url: "https://github.com/apple/swift-testing", from: "0.1.0"),   // Modern testing
```

### Consider These Dependencies

```swift
// For advanced features
.package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI"),  // Image caching
.package(url: "https://github.com/nalexn/ViewInspector"),          // SwiftUI testing
```

---

## Appendix C: Metrics & Success Criteria

### Quality Gates

| Metric | Current | Target |
|--------|---------|--------|
| Test Coverage | 0% | 70% |
| Crash-free Sessions | Unknown | 99.5% |
| MCP Spec Compliance | ~50% | 95% |
| Accessibility Score | D | B+ |
| Lighthouse Performance | N/A | 85+ |

### Feature Parity Score

| vs. Claude Desktop | Current | Target |
|-------------------|---------|--------|
| Core Chat | 80% | 95% |
| MCP | 50% | 90% |
| UI/UX | 60% | 85% |
| Features | 40% | 75% |
| **Overall** | **57%** | **86%** |

---

## Sources

- [MCP Specification 2024-11-05](https://spec.modelcontextprotocol.io/specification/2024-11-05/)
- [Claude Desktop Ultimate Guide](https://skywork.ai/blog/ai-agent/claude-desktop-2025-ultimate-guide/)
- [Claude MCP Apps Extension](https://www.theregister.com/2026/01/26/claude_mcp_apps_arrives/)
- [ChatGPT Canvas Features](https://skywork.ai/blog/chatgpt-canvas-review-2025-features-coding-pros-cons/)
- [MCP Features Guide](https://workos.com/blog/mcp-features-guide)
- [Claude Desktop MCP Setup](https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop)
