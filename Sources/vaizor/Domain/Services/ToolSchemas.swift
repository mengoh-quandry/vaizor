import Foundation

/// Centralized tool schema definitions - Single Source of Truth
/// All tool schemas should be defined here and referenced elsewhere
enum ToolSchemas {

    // MARK: - Internal Helper Tools (Not shown to users)

    /// Get current date and time in user's timezone
    static let getCurrentTime = ToolSchema(
        name: "get_current_time",
        displayName: "Get Current Time",
        description: "Get the current date, time, and timezone. Use this to provide time-aware responses, schedule-related help, or when the user asks about the current time/date.",
        icon: "clock",
        category: .core,
        inputSchema: [
            "type": "object",
            "properties": [
                "format": [
                    "type": "string",
                    "enum": ["full", "date_only", "time_only", "iso8601", "unix"],
                    "description": "Output format. 'full' includes date, time, timezone. 'iso8601' for standard format. 'unix' for timestamp."
                ]
            ],
            "required": []
        ],
        isInternal: true
    )

    /// Get user's approximate location
    static let getLocation = ToolSchema(
        name: "get_location",
        displayName: "Get Location",
        description: "Get the user's approximate location (city, region, country, timezone) based on system settings. Use for location-aware responses, weather queries, or local recommendations. Does NOT use GPS - only system locale/timezone.",
        icon: "location",
        category: .core,
        inputSchema: [
            "type": "object",
            "properties": [:],
            "required": []
        ],
        isInternal: true
    )

    /// Get system information
    static let getSystemInfo = ToolSchema(
        name: "get_system_info",
        displayName: "Get System Info",
        description: "Get basic system information: OS version, device type, language, available disk space, memory. Use to provide platform-specific advice or troubleshoot issues.",
        icon: "desktopcomputer",
        category: .core,
        inputSchema: [
            "type": "object",
            "properties": [:],
            "required": []
        ],
        isInternal: true
    )

    /// Read clipboard contents
    static let getClipboard = ToolSchema(
        name: "get_clipboard",
        displayName: "Get Clipboard",
        description: "Read the current clipboard contents (text only). Use when the user says 'from my clipboard', 'what I copied', or asks to work with clipboard content.",
        icon: "doc.on.clipboard",
        category: .core,
        inputSchema: [
            "type": "object",
            "properties": [:],
            "required": []
        ],
        isInternal: true
    )

    /// Set clipboard contents
    static let setClipboard = ToolSchema(
        name: "set_clipboard",
        displayName: "Set Clipboard",
        description: "Copy text to the clipboard. Use when the user asks to 'copy this', 'put in clipboard', or after generating content they might want to paste elsewhere.",
        icon: "doc.on.clipboard.fill",
        category: .core,
        inputSchema: [
            "type": "object",
            "properties": [
                "text": [
                    "type": "string",
                    "description": "Text to copy to clipboard"
                ]
            ],
            "required": ["text"]
        ],
        isInternal: true
    )

    /// Get current weather
    static let getWeather = ToolSchema(
        name: "get_weather",
        displayName: "Get Weather",
        description: "Get current weather conditions for a location. If no location specified, uses user's approximate location. Returns temperature, conditions, humidity, wind.",
        icon: "cloud.sun",
        category: .core,
        inputSchema: [
            "type": "object",
            "properties": [
                "location": [
                    "type": "string",
                    "description": "City name or 'auto' to use user's location. Examples: 'San Francisco', 'London, UK', 'auto'"
                ]
            ],
            "required": []
        ],
        isInternal: true
    )

    /// All internal helper tools
    static let allInternal: [ToolSchema] = [
        getCurrentTime,
        getLocation,
        getSystemInfo,
        getClipboard,
        setClipboard,
        getWeather
    ]

    // MARK: - Web Search Tool

    static let webSearch = ToolSchema(
        name: "web_search",
        displayName: "Web Search",
        description: "Search the web for real-time information. USE PROACTIVELY for: current events, factual data, statistics, company info, technical docs, image URLs, or to verify claims. Returns snippets and URLs from top results.",
        icon: "globe",
        category: .web,
        inputSchema: [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Specific search query with relevant keywords, dates, or context. Good: 'Swift 5.10 new features 2024'. Bad: 'Swift features'"
                ],
                "max_results": [
                    "type": "integer",
                    "description": "Number of results to return (1-10). Default: 5. Use more for research, fewer for quick facts.",
                    "default": 5,
                    "minimum": 1,
                    "maximum": 10
                ]
            ],
            "required": ["query"]
        ]
    )

    // MARK: - Code Execution Tool

    static let executeCode = ToolSchema(
        name: "execute_code",
        displayName: "Code Execution",
        description: "Execute code in a secure, sandboxed environment. Use for: calculations, data processing, algorithm implementation, testing code snippets, and generating programmatic outputs. Supports Python, JavaScript, Swift, HTML, CSS, and React.",
        icon: "play.rectangle.fill",
        category: .code,
        inputSchema: [
            "type": "object",
            "properties": [
                "language": [
                    "type": "string",
                    "enum": ["python", "javascript", "swift", "html", "css", "react"],
                    "description": "Programming language. Python for data/math, JavaScript for web/JSON, Swift for Apple ecosystem."
                ],
                "code": [
                    "type": "string",
                    "description": "Complete, executable code. Include all imports and print statements for output. Handle errors appropriately."
                ],
                "timeout": [
                    "type": "number",
                    "description": "Timeout in seconds (1-120). Default: 30. Increase for complex operations.",
                    "default": 30,
                    "minimum": 1,
                    "maximum": 120
                ],
                "capabilities": [
                    "type": "array",
                    "items": [
                        "type": "string",
                        "enum": ["filesystem.read", "filesystem.write", "network", "clipboard.read", "clipboard.write", "process.spawn"]
                    ],
                    "description": "Required capabilities (prompts user for permission). Only request what's needed."
                ]
            ],
            "required": ["language", "code"]
        ]
    )

    // MARK: - Shell Execution Tool

    static let executeShell = ToolSchema(
        name: "execute_shell",
        displayName: "Shell Execution",
        description: "Execute shell commands in a sandboxed environment. DANGEROUS: Only use when specifically requested. Supports Bash, Zsh, and PowerShell. Many dangerous commands are blocked for security. User permission required per session.",
        icon: "terminal.fill",
        category: .code,
        inputSchema: [
            "type": "object",
            "properties": [
                "shell_type": [
                    "type": "string",
                    "enum": ["bash", "zsh", "pwsh"],
                    "description": "Shell to use. 'bash' for Bash, 'zsh' for Zsh, 'pwsh' for PowerShell Core. Bash/Zsh always available on macOS. PowerShell requires separate installation."
                ],
                "code": [
                    "type": "string",
                    "description": "Shell commands to execute. Many dangerous patterns are blocked (sudo, rm -rf, chmod 777, etc). Keep scripts simple and focused."
                ],
                "working_directory": [
                    "type": "string",
                    "description": "Working directory for command execution. Defaults to a sandboxed temp directory. Custom paths require filesystem capability."
                ],
                "timeout": [
                    "type": "number",
                    "description": "Timeout in seconds (1-60). Default: 30. Shell commands have stricter time limits.",
                    "default": 30,
                    "minimum": 1,
                    "maximum": 60
                ]
            ],
            "required": ["shell_type", "code"]
        ]
    )

    // MARK: - Artifact Creation Tool

    static let createArtifact = ToolSchema(
        name: "create_artifact",
        displayName: "Create Artifact",
        description: "Create and display interactive visual content IMMEDIATELY in the app. The artifact renders instantly in a side panel. Use for: React components, HTML pages, charts, diagrams, SVG graphics, Mermaid flowcharts, and any visual demonstration or prototype.",
        icon: "wand.and.stars",
        category: .artifacts,
        inputSchema: [
            "type": "object",
            "properties": [
                "type": [
                    "type": "string",
                    "enum": ["react", "html", "svg", "mermaid"],
                    "description": "Content type: 'react' for interactive UI, 'html' for web pages, 'svg' for graphics, 'mermaid' for diagrams"
                ],
                "title": [
                    "type": "string",
                    "description": "Brief, descriptive title shown in the artifact panel header"
                ],
                "content": [
                    "type": "string",
                    "description": "Complete, self-contained code. React: function component. HTML: full document. SVG: complete element. Mermaid: diagram syntax."
                ]
            ],
            "required": ["type", "title", "content"]
        ]
    )

    // MARK: - Browser Automation Tool

    static let browserAutomation = ToolSchema(
        name: "browser_action",
        displayName: "Browser Control",
        description: "Control the integrated browser - navigate to URLs, click elements, type text, extract page content, and take screenshots. Use for web research, form filling, and page analysis.",
        icon: "globe",
        category: .web,
        inputSchema: [
            "type": "object",
            "properties": [
                "action": [
                    "type": "string",
                    "enum": ["navigate", "click", "type", "extract", "screenshot", "find", "scroll"],
                    "description": "Action to perform: navigate (go to URL), click (click element), type (enter text), extract (get page content), screenshot (capture page), find (locate elements), scroll (scroll page)"
                ],
                "url": [
                    "type": "string",
                    "description": "URL to navigate to (required for 'navigate' action). Include https:// prefix."
                ],
                "selector": [
                    "type": "string",
                    "description": "CSS selector or text description to find element (for click/type/find actions). Examples: '#submit-btn', 'button.primary', 'Sign In button'"
                ],
                "text": [
                    "type": "string",
                    "description": "Text to type into element (required for 'type' action)"
                ],
                "scroll_position": [
                    "type": "string",
                    "enum": ["top", "bottom", "element"],
                    "description": "Where to scroll (for 'scroll' action). Use 'element' with selector to scroll to specific element."
                ]
            ],
            "required": ["action"]
        ]
    )

    // MARK: - All Built-in Tools

    /// User-visible tools (shown in UI toggles)
    static let allBuiltIn: [ToolSchema] = [
        webSearch,
        executeCode,
        executeShell,
        createArtifact,
        browserAutomation
    ]

    /// All tools including internal helpers
    static let allTools: [ToolSchema] = allBuiltIn + allInternal

    // MARK: - Schema Retrieval

    /// Get tool schema by name (searches all tools including internal)
    static func schema(for name: String) -> ToolSchema? {
        allTools.first { $0.name == name }
    }

    /// Get all enabled built-in tools (user-visible only)
    @MainActor
    static func enabledSchemas() -> [ToolSchema] {
        let manager = BuiltInToolsManager.shared
        return allBuiltIn.filter { manager.isToolEnabled($0.name) }
    }

    /// Get all enabled tools including internal helpers (for API calls)
    @MainActor
    static func allEnabledSchemas() -> [ToolSchema] {
        let manager = BuiltInToolsManager.shared
        let enabledUserTools = allBuiltIn.filter { manager.isToolEnabled($0.name) }
        // Internal tools are always enabled
        return enabledUserTools + allInternal
    }

    /// Get tool schemas as OpenAI/Ollama format
    static func asOpenAIFormat(_ schemas: [ToolSchema]) -> [[String: Any]] {
        schemas.map { schema in
            [
                "type": "function",
                "function": [
                    "name": schema.name,
                    "description": schema.description,
                    "parameters": schema.inputSchema
                ]
            ]
        }
    }

    /// Get tool schemas as Anthropic format
    static func asAnthropicFormat(_ schemas: [ToolSchema]) -> [[String: Any]] {
        schemas.map { schema in
            [
                "name": schema.name,
                "description": schema.description,
                "input_schema": schema.inputSchema
            ]
        }
    }

    /// Get tool definitions as markdown for system prompt
    static func asMarkdown(_ schemas: [ToolSchema]) -> String {
        var result = ""
        for schema in schemas {
            result += "- **\(schema.name)**: \(schema.description)\n"
        }
        return result
    }
}

// MARK: - Tool Schema Model

/// Unified tool schema definition
struct ToolSchema: Identifiable, Sendable {
    let name: String
    let displayName: String
    let description: String
    let icon: String
    let category: ToolCategory
    let inputSchema: [String: Any]
    let isInternal: Bool

    var id: String { name }

    init(
        name: String,
        displayName: String,
        description: String,
        icon: String,
        category: ToolCategory,
        inputSchema: [String: Any],
        isInternal: Bool = false
    ) {
        self.name = name
        self.displayName = displayName
        self.description = description
        self.icon = icon
        self.category = category
        self.inputSchema = inputSchema
        self.isInternal = isInternal
    }

    /// Tool categories
    enum ToolCategory: String, CaseIterable, Sendable {
        case core = "Core"
        case web = "Web"
        case code = "Code"
        case artifacts = "Artifacts"

        var displayName: String { rawValue }
    }

    /// Convert to ToolInfo for SystemPrompts compatibility
    func asToolInfo() -> ToolInfo {
        ToolInfo(
            name: name,
            description: description,
            category: category.displayName,
            schema: inputSchema
        )
    }

    /// Convert to BuiltInTool for BuiltInToolsManager compatibility
    func asBuiltInTool(isEnabled: Bool = true) -> BuiltInTool {
        let builtInCategory: BuiltInTool.ToolCategory
        switch category {
        case .core: builtInCategory = .core
        case .web: builtInCategory = .web
        case .code: builtInCategory = .code
        case .artifacts: builtInCategory = .artifacts
        }

        return BuiltInTool(
            id: name,
            name: name,
            displayName: displayName,
            description: description,
            icon: icon,
            isEnabled: isEnabled,
            category: builtInCategory
        )
    }
}

// Make ToolSchema hashable for use in Sets
extension ToolSchema: Hashable {
    static func == (lhs: ToolSchema, rhs: ToolSchema) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

// MARK: - ToolInfo Extension

extension ToolInfo {
    /// Create from unified ToolSchema
    init(from schema: ToolSchema) {
        self.init(
            name: schema.name,
            description: schema.description,
            category: schema.category.displayName,
            schema: schema.inputSchema
        )
    }
}
