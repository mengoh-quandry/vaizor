import Foundation
#if os(macOS)
import AppKit
#endif

/// Represents a parsed tool call from Ollama's response
struct OllamaToolCall: Sendable {
    let name: String
    let arguments: [String: Any]

    var argumentsJSON: String {
        guard let data = try? JSONSerialization.data(withJSONObject: arguments),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

/// Tool execution result
struct ToolExecutionResult: Sendable {
    let toolName: String
    let success: Bool
    let result: String
    let artifact: Artifact?

    init(toolName: String, success: Bool, result: String, artifact: Artifact? = nil) {
        self.toolName = toolName
        self.success = success
        self.result = result
        self.artifact = artifact
    }
}

class OllamaProvider: LLMProviderProtocol, @unchecked Sendable {
    /// Default base URL for Ollama API
    private static let defaultBaseURL = "http://localhost:11434"

    /// Maximum number of tool call iterations to prevent infinite loops
    private static let maxToolIterations = 10

    /// Get the configured Ollama URL from AppSettings (must be called from async context)
    func getBaseURL() async -> String {
        await MainActor.run {
            AppSettings.shared.ollamaUrl.isEmpty ? Self.defaultBaseURL : AppSettings.shared.ollamaUrl
        }
    }

    func sendMessage(_ text: String, configuration: LLMConfiguration) async throws -> String {
        // This method is for non-streaming, but we'll implement streaming separately
        throw NSError(domain: "OllamaProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Use streaming method instead"])
    }

    /// Enhances a user prompt to improve clarity, structure, and effectiveness
    private func enhancePrompt(_ originalText: String) -> String {
        let trimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Don't enhance if the prompt is already well-structured or very short
        if trimmed.count < 20 {
            return trimmed
        }
        
        // Check if prompt already has structure (contains bullets, numbered lists, etc.)
        let hasStructure = trimmed.contains("•") || trimmed.contains("-") || 
                          trimmed.range(of: #"^\d+[\.\)]\s"#, options: .regularExpression) != nil ||
                          trimmed.contains("\n\n")
        
        // Don't enhance prompts that are already well-structured
        if hasStructure && trimmed.count > 100 {
            return trimmed
        }
        
        // Enhance the prompt by:
        // 1. Ensuring clear intent
        // 2. Adding structure for complex requests
        // 3. Clarifying ambiguous instructions
        
        var enhanced = trimmed
        
        // Add structure for questions that could benefit from it
        if trimmed.contains("?") && !trimmed.contains("\n") && trimmed.count > 50 {
            // For complex questions, add a brief structure
            if trimmed.lowercased().contains("how") || trimmed.lowercased().contains("explain") {
                enhanced = "Please provide a clear and detailed explanation:\n\n\(trimmed)"
            } else if trimmed.lowercased().contains("compare") || trimmed.lowercased().contains("difference") {
                enhanced = "Please provide a structured comparison:\n\n\(trimmed)"
            }
        }
        
        // Ensure code-related requests are clear
        if trimmed.lowercased().contains("code") || trimmed.lowercased().contains("function") || 
           trimmed.lowercased().contains("class") || trimmed.lowercased().contains("implement") {
            if !trimmed.contains("```") && !trimmed.contains("language") {
                // Add context for code requests
                enhanced = "\(trimmed)\n\nPlease provide well-documented, production-ready code."
            }
        }
        
        // Add clarity for list requests
        if trimmed.lowercased().contains("list") || trimmed.lowercased().contains("give me") {
            if !trimmed.contains(":") && !trimmed.contains("\n") {
                enhanced = "\(trimmed)\n\nPlease provide a clear, organized list."
            }
        }
        
        return enhanced
    }

    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void,
        onArtifactCreated: (@Sendable (Artifact) -> Void)? = nil,
        onToolCallUpdate: (@Sendable (ToolCallUpdateEvent) -> Void)? = nil
    ) async throws {
        let baseURL = await getBaseURL()
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw NSError(domain: "OllamaProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama URL: \(baseURL)/api/chat"])
        }

        // Get context enhancement settings
        let enableDatetimeInjection = await MainActor.run { AppSettings.shared.enableDatetimeInjection }
        let enableAutoRefresh = await MainActor.run { AppSettings.shared.enableAutoRefresh }

        // Apply context enhancement for local models
        var enhancedSystemPrompt = configuration.systemPrompt

        if enableDatetimeInjection || enableAutoRefresh {
            let contextEnhancer = await MainActor.run { ContextEnhancer.shared }

            // Enhance context (datetime injection + staleness detection)
            let enhancedContext = await contextEnhancer.enhanceContext(
                message: text,
                model: configuration.model,
                enableAutoRefresh: enableAutoRefresh
            )

            // Show chain-of-thought notes if staleness was detected
            if enhancedContext.stalenessDetected {
                for note in enhancedContext.chainOfThoughtNotes {
                    onThinkingStatusUpdate(note)
                }
            }

            // Build enhanced system prompt with datetime and fresh data
            if enableDatetimeInjection || enhancedContext.hasFreshData {
                enhancedSystemPrompt = await contextEnhancer.buildEnhancedSystemPrompt(
                    basePrompt: configuration.systemPrompt,
                    context: enhancedContext
                )

                // Log enhancement
                if enhancedContext.hasFreshData {
                    await MainActor.run {
                        AppLogger.shared.log("Context enhanced with fresh data for query: \(enhancedContext.staleTriggers.joined(separator: ", "))", level: .info)
                    }
                }

                // Post notification about context enhancement
                let showIndicator = await MainActor.run { AppSettings.shared.showContextEnhancementIndicator }
                if showIndicator {
                    var details = "DateTime injected"
                    if enhancedContext.hasFreshData {
                        details = "Fresh data fetched for: \(enhancedContext.staleTriggers.prefix(3).joined(separator: ", "))"
                    }
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .contextEnhanced,
                            object: nil,
                            userInfo: [
                                "enhanced": true,
                                "hasFreshData": enhancedContext.hasFreshData,
                                "details": details
                            ]
                        )
                    }
                }
            }
        }

        // Build messages array from conversation history
        var messages: [[String: Any]] = []

        // Add enhanced system prompt if available, otherwise use original
        if let systemPrompt = enhancedSystemPrompt {
            messages.append([
                "role": "system",
                "content": systemPrompt
            ])
        }

        // Add conversation history
        for message in conversationHistory {
            messages.append([
                "role": message.role == .user ? "user" : "assistant",
                "content": message.content
            ])
        }

        // Enhance the current message if prompt enhancement is enabled
        let finalText = configuration.enablePromptEnhancement ? enhancePrompt(text) : text

        // Add current message
        messages.append([
            "role": "user",
            "content": finalText
        ])

        // Get enabled tools from BuiltInToolsManager
        let toolSchemas = await MainActor.run {
            BuiltInToolsManager.shared.getToolSchemasOpenAI()
        }

        // Get context window size from settings
        let contextWindow = await MainActor.run {
            AppSettings.shared.ollamaContextWindow
        }

        var body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "stream": true,
            "options": [
                "temperature": configuration.temperature,
                "num_predict": configuration.maxTokens,
                "num_ctx": contextWindow
            ]
        ]

        // Include tools if any are enabled (Ollama supports OpenAI-style tool format)
        if !toolSchemas.isEmpty {
            body["tools"] = toolSchemas
        }

        var currentMessages = messages
        var fullResponse = ""

        // Tool execution loop - keep processing until we get a final response or hit iteration limit
        var iteration = 0
        while iteration < Self.maxToolIterations {
            iteration += 1

            // Stream the response (creates fresh request each iteration)
            let streamResult = try await streamOllamaResponse(
                url: url,
                body: body,
                currentMessages: currentMessages,
                toolSchemas: toolSchemas,
                configuration: configuration,
                onChunk: onChunk
            )

            fullResponse += streamResult.content

            // If no tool calls, we're done
            if streamResult.toolCalls.isEmpty {
                break
            }

            // Execute tool calls
            onThinkingStatusUpdate("Executing \(streamResult.toolCalls.count) tool(s)...")

            // First, add the assistant message with all tool calls
            var toolCallsArray: [[String: Any]] = []
            for toolCall in streamResult.toolCalls {
                toolCallsArray.append([
                    "function": [
                        "name": toolCall.name,
                        "arguments": toolCall.arguments
                    ]
                ])
            }

            let assistantMessage: [String: Any] = [
                "role": "assistant",
                "content": streamResult.content,
                "tool_calls": toolCallsArray
            ]
            currentMessages.append(assistantMessage)

            // Then execute each tool and add its result
            for toolCall in streamResult.toolCalls {
                onThinkingStatusUpdate("Running \(toolCall.name)...")

                let result = await executeToolCall(toolCall, onArtifactCreated: onArtifactCreated)

                // Add tool response with tool_name (required by Ollama API)
                let toolMessage: [String: Any] = [
                    "role": "tool",
                    "tool_name": toolCall.name,
                    "content": result.result
                ]
                currentMessages.append(toolMessage)
            }

            // Update body with new messages for next iteration
            body["messages"] = currentMessages
        }

        if iteration >= Self.maxToolIterations {
            onChunk("\n\n[Tool execution limit reached]")
        }
    }

    /// Stream Ollama response and parse tool calls
    private func streamOllamaResponse(
        url: URL,
        body: [String: Any],
        currentMessages: [[String: Any]],
        toolSchemas: [[String: Any]],
        configuration: LLMConfiguration,
        onChunk: @escaping @Sendable (String) -> Void
    ) async throws -> (content: String, toolCalls: [OllamaToolCall]) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var requestBody = body
        requestBody["messages"] = currentMessages
        if !toolSchemas.isEmpty {
            requestBody["tools"] = toolSchemas
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpMaximumConnectionsPerHost = 10
        sessionConfig.timeoutIntervalForRequest = 300
        sessionConfig.timeoutIntervalForResource = 600
        let session = URLSession(configuration: sessionConfig)

        let (asyncBytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "OllamaProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to Ollama"])
        }

        var content = ""
        var toolCalls: [OllamaToolCall] = []

        for try await line in asyncBytes.lines {
            guard !line.isEmpty else { continue }

            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messageContent = json["message"] as? [String: Any] {

                // Check for regular content
                if let textContent = messageContent["content"] as? String, !textContent.isEmpty {
                    content += textContent
                    onChunk(textContent)
                }

                // Check for tool calls
                if let toolCallsArray = messageContent["tool_calls"] as? [[String: Any]] {
                    for toolCallDict in toolCallsArray {
                        if let function = toolCallDict["function"] as? [String: Any],
                           let name = function["name"] as? String {
                            let arguments = function["arguments"] as? [String: Any] ?? [:]
                            toolCalls.append(OllamaToolCall(name: name, arguments: arguments))
                        }
                    }
                }
            }
        }

        return (content, toolCalls)
    }

    /// Execute a tool call and return the result
    private func executeToolCall(
        _ toolCall: OllamaToolCall,
        onArtifactCreated: (@Sendable (Artifact) -> Void)?
    ) async -> ToolExecutionResult {
        switch toolCall.name {
        // User-visible tools
        case "web_search":
            return await executeWebSearch(toolCall.arguments)

        case "execute_code":
            return await executeCode(toolCall.arguments)

        case "execute_shell":
            return await executeShell(toolCall.arguments)

        case "create_artifact":
            return await createArtifact(toolCall.arguments, onArtifactCreated: onArtifactCreated)

        case "browser_action":
            return await executeBrowserAction(toolCall.arguments)

        // Internal helper tools
        case "get_current_time":
            return executeGetCurrentTime(toolCall.arguments)

        case "get_location":
            return await executeGetLocation()

        case "get_system_info":
            return await executeGetSystemInfo()

        case "get_clipboard":
            return await executeGetClipboard()

        case "set_clipboard":
            return await executeSetClipboard(toolCall.arguments)

        case "get_weather":
            return await executeGetWeather(toolCall.arguments)

        default:
            return ToolExecutionResult(
                toolName: toolCall.name,
                success: false,
                result: "Unknown tool: \(toolCall.name)"
            )
        }
    }

    // MARK: - Tool Executors

    /// Execute web search tool
    private func executeWebSearch(_ arguments: [String: Any]) async -> ToolExecutionResult {
        guard let query = arguments["query"] as? String else {
            return ToolExecutionResult(toolName: "web_search", success: false, result: "Missing required 'query' parameter")
        }

        let maxResults = arguments["max_results"] as? Int ?? 5

        do {
            let results = await MainActor.run {
                Task {
                    try await WebSearchService.shared.search(query, maxResults: maxResults)
                }
            }

            let searchResults = try await results.value

            // Format results as JSON for the model
            var formattedResults: [[String: String]] = []
            for result in searchResults {
                formattedResults.append([
                    "title": result.title,
                    "url": result.url,
                    "snippet": result.snippet
                ])
            }

            let resultJSON = try JSONSerialization.data(withJSONObject: formattedResults, options: .prettyPrinted)
            let resultString = String(data: resultJSON, encoding: .utf8) ?? "[]"

            return ToolExecutionResult(
                toolName: "web_search",
                success: true,
                result: "Search results for '\(query)':\n\(resultString)"
            )
        } catch {
            return ToolExecutionResult(
                toolName: "web_search",
                success: false,
                result: "Search failed: \(error.localizedDescription)"
            )
        }
    }

    /// Execute code execution tool
    private func executeCode(_ arguments: [String: Any]) async -> ToolExecutionResult {
        guard let languageStr = arguments["language"] as? String,
              let code = arguments["code"] as? String else {
            return ToolExecutionResult(toolName: "execute_code", success: false, result: "Missing required 'language' or 'code' parameter")
        }

        guard let language = CodeLanguage(rawValue: languageStr) else {
            return ToolExecutionResult(toolName: "execute_code", success: false, result: "Unsupported language: \(languageStr)")
        }

        let timeout = arguments["timeout"] as? Double ?? 30.0
        let capabilitiesStrs = arguments["capabilities"] as? [String] ?? []
        let capabilities = capabilitiesStrs.compactMap { ExecutionCapability(rawValue: $0) }

        do {
            let result = await MainActor.run {
                Task {
                    try await ExecutionBroker.shared.requestExecution(
                        conversationId: UUID(),
                        language: language,
                        code: code,
                        requestedCapabilities: capabilities,
                        timeout: timeout
                    )
                }
            }

            let executionResult = try await result.value

            var output = ""
            if !executionResult.stdout.isEmpty {
                output += "Output:\n\(executionResult.stdout)"
            }
            if !executionResult.stderr.isEmpty {
                output += "\nErrors:\n\(executionResult.stderr)"
            }
            output += "\nExit code: \(executionResult.exitCode)"

            return ToolExecutionResult(
                toolName: "execute_code",
                success: executionResult.exitCode == 0,
                result: output.isEmpty ? "Code executed successfully (no output)" : output
            )
        } catch {
            return ToolExecutionResult(
                toolName: "execute_code",
                success: false,
                result: "Execution failed: \(error.localizedDescription)"
            )
        }
    }

    /// Execute shell command tool
    private func executeShell(_ arguments: [String: Any]) async -> ToolExecutionResult {
        guard let shellTypeStr = arguments["shell_type"] as? String,
              let code = arguments["code"] as? String else {
            return ToolExecutionResult(toolName: "execute_shell", success: false, result: "Missing required 'shell_type' or 'code' parameter")
        }

        let language: CodeLanguage
        switch shellTypeStr {
        case "bash": language = .bash
        case "zsh": language = .zsh
        case "pwsh": language = .powershell
        default:
            return ToolExecutionResult(toolName: "execute_shell", success: false, result: "Unsupported shell type: \(shellTypeStr)")
        }

        let timeout = min(arguments["timeout"] as? Double ?? 30.0, 60.0)

        do {
            let result = await MainActor.run {
                Task {
                    try await ExecutionBroker.shared.requestExecution(
                        conversationId: UUID(),
                        language: language,
                        code: code,
                        requestedCapabilities: [.shellExecution],
                        timeout: timeout
                    )
                }
            }

            let executionResult = try await result.value

            var output = ""
            if !executionResult.stdout.isEmpty {
                output += executionResult.stdout
            }
            if !executionResult.stderr.isEmpty {
                output += "\nStderr:\n\(executionResult.stderr)"
            }
            output += "\nExit code: \(executionResult.exitCode)"

            return ToolExecutionResult(
                toolName: "execute_shell",
                success: executionResult.exitCode == 0,
                result: output.isEmpty ? "Command executed successfully (no output)" : output
            )
        } catch {
            return ToolExecutionResult(
                toolName: "execute_shell",
                success: false,
                result: "Shell execution failed: \(error.localizedDescription)"
            )
        }
    }

    /// Create artifact tool
    private func createArtifact(
        _ arguments: [String: Any],
        onArtifactCreated: (@Sendable (Artifact) -> Void)?
    ) async -> ToolExecutionResult {
        guard let typeStr = arguments["type"] as? String,
              let title = arguments["title"] as? String,
              let content = arguments["content"] as? String else {
            return ToolExecutionResult(toolName: "create_artifact", success: false, result: "Missing required 'type', 'title', or 'content' parameter")
        }

        let artifactType: ArtifactType
        let language: String
        switch typeStr.lowercased() {
        case "react":
            artifactType = .react
            language = "jsx"
        case "html":
            artifactType = .html
            language = "html"
        case "svg":
            artifactType = .svg
            language = "svg"
        case "mermaid":
            artifactType = .mermaid
            language = "mermaid"
        default:
            return ToolExecutionResult(toolName: "create_artifact", success: false, result: "Unsupported artifact type: \(typeStr)")
        }

        let artifact = Artifact(
            id: UUID(),
            type: artifactType,
            title: title,
            content: content,
            language: language,
            createdAt: Date()
        )

        // Notify about artifact creation
        if let callback = onArtifactCreated {
            callback(artifact)
        }

        return ToolExecutionResult(
            toolName: "create_artifact",
            success: true,
            result: "Created \(typeStr) artifact: '\(title)'. The artifact is now displayed in the artifact panel.",
            artifact: artifact
        )
    }

    /// Execute browser action tool
    private func executeBrowserAction(_ arguments: [String: Any]) async -> ToolExecutionResult {
        guard let action = arguments["action"] as? String else {
            return ToolExecutionResult(toolName: "browser_action", success: false, result: "Missing required 'action' parameter")
        }

        switch action {
        case "navigate":
            guard let url = arguments["url"] as? String else {
                return ToolExecutionResult(toolName: "browser_action", success: false, result: "Missing 'url' for navigate action")
            }
            // Navigate browser (fire and forget, navigation happens asynchronously)
            _ = await MainActor.run {
                Task {
                    await BrowserService.shared.navigate(to: url)
                }
            }
            return ToolExecutionResult(toolName: "browser_action", success: true, result: "Navigated to: \(url)")

        case "extract":
            let content = await MainActor.run {
                Task {
                    await BrowserService.shared.extractPageContent()
                }
            }
            if let pageContent = await content.value {
                let summary = """
                Title: \(pageContent.title)
                URL: \(pageContent.url.absoluteString)

                Content (truncated to 2000 chars):
                \(String(pageContent.text.prefix(2000)))

                Links found: \(pageContent.links.count)
                Images found: \(pageContent.images.count)
                Forms found: \(pageContent.forms.count)
                """
                return ToolExecutionResult(toolName: "browser_action", success: true, result: summary)
            } else {
                return ToolExecutionResult(toolName: "browser_action", success: false, result: "Failed to extract page content")
            }

        case "click":
            guard let selector = arguments["selector"] as? String else {
                return ToolExecutionResult(toolName: "browser_action", success: false, result: "Missing 'selector' for click action")
            }
            let elements = await MainActor.run {
                Task {
                    await BrowserService.shared.findElements(matching: selector)
                }
            }
            let foundElements = await elements.value
            if let element = foundElements.first {
                let success = await MainActor.run {
                    Task {
                        await BrowserService.shared.click(element: element, requireConfirmation: false)
                    }
                }
                let clicked = await success.value
                return ToolExecutionResult(toolName: "browser_action", success: clicked, result: clicked ? "Clicked element: \(selector)" : "Failed to click element")
            } else {
                return ToolExecutionResult(toolName: "browser_action", success: false, result: "Element not found: \(selector)")
            }

        case "type":
            guard let selector = arguments["selector"] as? String,
                  let text = arguments["text"] as? String else {
                return ToolExecutionResult(toolName: "browser_action", success: false, result: "Missing 'selector' or 'text' for type action")
            }
            let elements = await MainActor.run {
                Task {
                    await BrowserService.shared.findElements(matching: selector)
                }
            }
            let foundElements = await elements.value
            if let element = foundElements.first {
                let success = await MainActor.run {
                    Task {
                        await BrowserService.shared.type(text: text, into: element, requireConfirmation: false)
                    }
                }
                let typed = await success.value
                return ToolExecutionResult(toolName: "browser_action", success: typed, result: typed ? "Typed into element: \(selector)" : "Failed to type into element")
            } else {
                return ToolExecutionResult(toolName: "browser_action", success: false, result: "Element not found: \(selector)")
            }

        case "screenshot":
            let image = await MainActor.run {
                Task {
                    await BrowserService.shared.takeScreenshot()
                }
            }
            if await image.value != nil {
                return ToolExecutionResult(toolName: "browser_action", success: true, result: "Screenshot captured successfully")
            } else {
                return ToolExecutionResult(toolName: "browser_action", success: false, result: "Failed to capture screenshot")
            }

        case "find":
            guard let selector = arguments["selector"] as? String else {
                return ToolExecutionResult(toolName: "browser_action", success: false, result: "Missing 'selector' for find action")
            }
            let elements = await MainActor.run {
                Task {
                    await BrowserService.shared.findElements(matching: selector)
                }
            }
            let foundElements = await elements.value
            var result = "Found \(foundElements.count) element(s):\n"
            for (index, element) in foundElements.prefix(10).enumerated() {
                result += "\(index + 1). \(element.tagName): \(element.text ?? element.selector)\n"
            }
            return ToolExecutionResult(toolName: "browser_action", success: true, result: result)

        case "scroll":
            let position = arguments["scroll_position"] as? String ?? "top"
            let scrollPos: ScrollPosition
            switch position {
            case "bottom": scrollPos = .bottom
            case "element":
                if let selector = arguments["selector"] as? String {
                    scrollPos = .element(selector: selector)
                } else {
                    scrollPos = .top
                }
            default: scrollPos = .top
            }
            // Scroll browser (fire and forget)
            _ = await MainActor.run {
                Task {
                    await BrowserService.shared.scroll(to: scrollPos)
                }
            }
            return ToolExecutionResult(toolName: "browser_action", success: true, result: "Scrolled to: \(position)")

        default:
            return ToolExecutionResult(toolName: "browser_action", success: false, result: "Unknown browser action: \(action)")
        }
    }

    // MARK: - Internal Helper Tool Executors

    /// Get current date and time
    private func executeGetCurrentTime(_ arguments: [String: Any]) -> ToolExecutionResult {
        let format = arguments["format"] as? String ?? "full"
        let now = Date()
        let calendar = Calendar.current
        let timezone = TimeZone.current

        let result: String
        switch format {
        case "date_only":
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .none
            formatter.timeZone = timezone
            result = formatter.string(from: now)

        case "time_only":
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .medium
            formatter.timeZone = timezone
            result = "\(formatter.string(from: now)) (\(timezone.identifier))"

        case "iso8601":
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = timezone
            result = formatter.string(from: now)

        case "unix":
            result = String(Int(now.timeIntervalSince1970))

        default: // "full"
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .medium
            formatter.timeZone = timezone

            let weekOfYear = calendar.component(.weekOfYear, from: now)

            // Calculate day of year manually for compatibility
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let dayOfYear = calendar.dateComponents([.day], from: startOfYear, to: now).day! + 1

            result = """
            Date and Time: \(formatter.string(from: now))
            Timezone: \(timezone.identifier) (UTC\(timezone.secondsFromGMT() >= 0 ? "+" : "")\(timezone.secondsFromGMT() / 3600))
            Week of Year: \(weekOfYear)
            Day of Year: \(dayOfYear)
            Is Daylight Saving: \(timezone.isDaylightSavingTime(for: now))
            """
        }

        return ToolExecutionResult(toolName: "get_current_time", success: true, result: result)
    }

    /// Get user's approximate location from IP geolocation + system settings
    private func executeGetLocation() async -> ToolExecutionResult {
        let timezone = TimeZone.current
        let locale = Locale.current

        // Get language and region from locale
        let languageCode = locale.language.languageCode?.identifier ?? "unknown"
        let regionCode = locale.region?.identifier ?? "unknown"

        // Try IP-based geolocation first for more accuracy
        var ipLocation: (city: String, region: String, country: String, lat: Double, lon: Double)?

        do {
            // Use ip-api.com (free, no API key needed, 45 requests/minute)
            guard let url = URL(string: "http://ip-api.com/json/?fields=status,city,regionName,country,lat,lon,timezone,isp") else {
                throw NSError(domain: "Location", code: -1, userInfo: nil)
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 5

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String,
                  status == "success" else {
                throw NSError(domain: "Location", code: -1, userInfo: nil)
            }

            let city = json["city"] as? String ?? "Unknown"
            let region = json["regionName"] as? String ?? "Unknown"
            let country = json["country"] as? String ?? "Unknown"
            let lat = json["lat"] as? Double ?? 0
            let lon = json["lon"] as? Double ?? 0

            ipLocation = (city, region, country, lat, lon)
        } catch {
            // IP geolocation failed, will fall back to timezone-based
        }

        // Build result with IP location if available, fallback to timezone
        let result: String
        if let loc = ipLocation {
            result = """
            User Location (via IP geolocation):
            City: \(loc.city)
            Region: \(loc.region)
            Country: \(loc.country)
            Coordinates: \(String(format: "%.4f", loc.lat)), \(String(format: "%.4f", loc.lon))
            Timezone: \(timezone.identifier)
            UTC Offset: \(timezone.secondsFromGMT() >= 0 ? "+" : "")\(timezone.secondsFromGMT() / 3600) hours
            Language: \(languageCode)

            Note: Location based on IP address, approximate to city level.
            """
        } else {
            // Fallback to timezone-based estimation
            let timezoneCity = timezone.identifier.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? "Unknown"
            let timezoneRegion = timezone.identifier.components(separatedBy: "/").first ?? "Unknown"
            let regionName = locale.localizedString(forRegionCode: regionCode) ?? regionCode

            result = """
            Approximate Location (based on system settings):
            City/Area: \(timezoneCity)
            Region: \(timezoneRegion)
            Country: \(regionName) (\(regionCode))
            Timezone: \(timezone.identifier)
            UTC Offset: \(timezone.secondsFromGMT() >= 0 ? "+" : "")\(timezone.secondsFromGMT() / 3600) hours
            Language: \(languageCode)

            Note: IP geolocation unavailable, using timezone/locale settings.
            """
        }

        return ToolExecutionResult(toolName: "get_location", success: true, result: result)
    }

    /// Get system information
    private func executeGetSystemInfo() async -> ToolExecutionResult {
        let processInfo = Foundation.ProcessInfo.processInfo
        let fileManager = FileManager.default

        // Get OS version
        let osVersion = processInfo.operatingSystemVersionString

        // Get device/host name
        let hostName = processInfo.hostName

        // Get memory
        let physicalMemory = processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / 1_073_741_824.0

        // Get processor count
        let processorCount = processInfo.processorCount
        let activeProcessorCount = processInfo.activeProcessorCount

        // Get locale info
        let locale = Locale.current
        let languageCode = locale.language.languageCode?.identifier ?? "unknown"

        // Get available disk space
        var diskSpace = "Unknown"
        if let homeURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            if let values = try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
               let capacity = values.volumeAvailableCapacityForImportantUsage {
                let gbAvailable = Double(capacity) / 1_073_741_824.0
                diskSpace = String(format: "%.1f GB available", gbAvailable)
            }
        }

        // Get app info
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

        let result = """
        System Information:
        OS: macOS \(osVersion)
        Host: \(hostName)
        Memory: \(String(format: "%.1f", memoryGB)) GB
        Processors: \(activeProcessorCount) active / \(processorCount) total
        Disk Space: \(diskSpace)
        Language: \(languageCode)
        App Version: Vaizor \(appVersion)
        """

        return ToolExecutionResult(toolName: "get_system_info", success: true, result: result)
    }

    /// Get clipboard contents
    private func executeGetClipboard() async -> ToolExecutionResult {
        return await MainActor.run {
            #if os(macOS)
            let pasteboard = NSPasteboard.general
            if let string = pasteboard.string(forType: .string) {
                let truncated = string.count > 5000 ? String(string.prefix(5000)) + "\n... [truncated]" : string
                return ToolExecutionResult(
                    toolName: "get_clipboard",
                    success: true,
                    result: "Clipboard contents:\n\(truncated)"
                )
            } else {
                return ToolExecutionResult(
                    toolName: "get_clipboard",
                    success: false,
                    result: "Clipboard is empty or contains non-text content"
                )
            }
            #else
            return ToolExecutionResult(
                toolName: "get_clipboard",
                success: false,
                result: "Clipboard access not available on this platform"
            )
            #endif
        }
    }

    /// Set clipboard contents
    private func executeSetClipboard(_ arguments: [String: Any]) async -> ToolExecutionResult {
        guard let text = arguments["text"] as? String else {
            return ToolExecutionResult(toolName: "set_clipboard", success: false, result: "Missing required 'text' parameter")
        }

        return await MainActor.run {
            #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return ToolExecutionResult(
                toolName: "set_clipboard",
                success: true,
                result: "Copied \(text.count) characters to clipboard"
            )
            #else
            return ToolExecutionResult(
                toolName: "set_clipboard",
                success: false,
                result: "Clipboard access not available on this platform"
            )
            #endif
        }
    }

    /// Get weather for a location
    private func executeGetWeather(_ arguments: [String: Any]) async -> ToolExecutionResult {
        var location = arguments["location"] as? String ?? "auto"

        // If auto, get from timezone
        if location == "auto" || location.isEmpty {
            let timezoneCity = TimeZone.current.identifier.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? ""
            location = timezoneCity
        }

        guard !location.isEmpty else {
            return ToolExecutionResult(
                toolName: "get_weather",
                success: false,
                result: "Could not determine location. Please specify a city name."
            )
        }

        // Use wttr.in API (free, no API key required)
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
        guard let url = URL(string: "https://wttr.in/\(encodedLocation)?format=j1") else {
            return ToolExecutionResult(toolName: "get_weather", success: false, result: "Invalid location")
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Vaizor/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return ToolExecutionResult(
                    toolName: "get_weather",
                    success: false,
                    result: "Weather service unavailable for location: \(location)"
                )
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let currentCondition = (json["current_condition"] as? [[String: Any]])?.first,
                  let nearestArea = (json["nearest_area"] as? [[String: Any]])?.first else {
                return ToolExecutionResult(
                    toolName: "get_weather",
                    success: false,
                    result: "Could not parse weather data for: \(location)"
                )
            }

            // Extract weather data
            let tempC = currentCondition["temp_C"] as? String ?? "?"
            let tempF = currentCondition["temp_F"] as? String ?? "?"
            let feelsLikeC = currentCondition["FeelsLikeC"] as? String ?? "?"
            let humidity = currentCondition["humidity"] as? String ?? "?"
            let weatherDesc = (currentCondition["weatherDesc"] as? [[String: Any]])?.first?["value"] as? String ?? "Unknown"
            let windSpeedKmph = currentCondition["windspeedKmph"] as? String ?? "?"
            let windDir = currentCondition["winddir16Point"] as? String ?? "?"
            let visibility = currentCondition["visibility"] as? String ?? "?"
            let uvIndex = currentCondition["uvIndex"] as? String ?? "?"

            let areaName = (nearestArea["areaName"] as? [[String: Any]])?.first?["value"] as? String ?? location
            let country = (nearestArea["country"] as? [[String: Any]])?.first?["value"] as? String ?? ""

            let result = """
            Weather for \(areaName), \(country):

            Conditions: \(weatherDesc)
            Temperature: \(tempC)°C / \(tempF)°F
            Feels Like: \(feelsLikeC)°C
            Humidity: \(humidity)%
            Wind: \(windSpeedKmph) km/h from \(windDir)
            Visibility: \(visibility) km
            UV Index: \(uvIndex)
            """

            return ToolExecutionResult(toolName: "get_weather", success: true, result: result)

        } catch {
            return ToolExecutionResult(
                toolName: "get_weather",
                success: false,
                result: "Failed to fetch weather: \(error.localizedDescription)"
            )
        }
    }
}

// Anthropic Provider with Prompt Caching Support
class AnthropicProvider: LLMProviderProtocol, @unchecked Sendable {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"

    /// Minimum token threshold for caching (Claude 3.5 Sonnet and Opus)
    private let minCacheTokens = 1024

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func sendMessage(_ text: String, configuration: LLMConfiguration) async throws -> String {
        throw NSError(domain: "AnthropicProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Use streaming method instead"])
    }

    /// Check if prompt caching is enabled in settings
    private func isPromptCachingEnabled() async -> Bool {
        await MainActor.run {
            AppSettings.shared.enablePromptCaching
        }
    }

    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void,
        onArtifactCreated: (@Sendable (Artifact) -> Void)? = nil,
        onToolCallUpdate: (@Sendable (ToolCallUpdateEvent) -> Void)? = nil
    ) async throws {
        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "AnthropicProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Anthropic API URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        let cachingEnabled = await isPromptCachingEnabled()

        // Build messages array with optional caching
        var messages: [[String: Any]] = []

        for (index, message) in conversationHistory.enumerated() {
            var messageDict: [String: Any] = [
                "role": message.role == .user ? "user" : "assistant"
            ]

            // For caching, we need to use content blocks format for the last message in history
            // to add cache_control marker
            if cachingEnabled && index == conversationHistory.count - 1 && conversationHistory.count >= 2 {
                // Use content block format for the last history message to enable caching
                let contentBlock: [String: Any] = [
                    "type": "text",
                    "text": message.content,
                    "cache_control": ["type": "ephemeral"]
                ]
                messageDict["content"] = [contentBlock]
            } else {
                messageDict["content"] = message.content
            }

            messages.append(messageDict)
        }

        // Add current user message
        messages.append([
            "role": "user",
            "content": text
        ])

        var body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "max_tokens": configuration.maxTokens,
            "stream": true
        ]

        // Add system prompt with caching support
        if let systemPrompt = configuration.systemPrompt, !systemPrompt.isEmpty {
            if cachingEnabled {
                // Use content block format for system prompt to enable caching
                // System prompt is ideal for caching as it's static across requests
                let systemBlock: [String: Any] = [
                    "type": "text",
                    "text": systemPrompt,
                    "cache_control": ["type": "ephemeral"]
                ]
                body["system"] = [systemBlock]
            } else {
                body["system"] = systemPrompt
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AnthropicProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Anthropic"])
        }

        // Handle HTTP errors with specific messages
        if httpResponse.statusCode != 200 {
            let errorMessage: String
            switch httpResponse.statusCode {
            case 400:
                errorMessage = "Bad request - check your message format"
            case 401:
                errorMessage = "Invalid API key - please check your Anthropic API key in Settings"
            case 403:
                errorMessage = "Access forbidden - your API key may not have access to this model"
            case 429:
                errorMessage = "Rate limit exceeded - please wait before sending more requests"
            case 500...599:
                errorMessage = "Anthropic server error - please try again later"
            default:
                errorMessage = "Request failed with status \(httpResponse.statusCode)"
            }
            throw NSError(domain: "AnthropicProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // Track token usage for cost calculation
        var inputTokens = 0
        var outputTokens = 0
        var cacheCreationTokens = 0
        var cacheReadTokens = 0

        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            guard !jsonString.contains("[DONE]"),
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Handle content delta
            if let type = json["type"] as? String,
               type == "content_block_delta",
               let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                onChunk(text)
            }

            // Handle message_start event which contains usage info including cache stats
            if let type = json["type"] as? String, type == "message_start",
               let message = json["message"] as? [String: Any],
               let usage = message["usage"] as? [String: Any] {
                inputTokens = usage["input_tokens"] as? Int ?? 0
                cacheCreationTokens = usage["cache_creation_input_tokens"] as? Int ?? 0
                cacheReadTokens = usage["cache_read_input_tokens"] as? Int ?? 0
            }

            // Handle message_delta event which contains final output token count
            if let type = json["type"] as? String, type == "message_delta",
               let usage = json["usage"] as? [String: Any] {
                outputTokens = usage["output_tokens"] as? Int ?? 0
            }
        }

        // Record usage with cache information
        if inputTokens > 0 || outputTokens > 0 || cacheReadTokens > 0 || cacheCreationTokens > 0 {
            Task { @MainActor in
                CostTracker.shared.recordUsage(
                    model: configuration.model,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cacheReadTokens: cacheReadTokens > 0 ? cacheReadTokens : nil,
                    cacheWriteTokens: cacheCreationTokens > 0 ? cacheCreationTokens : nil,
                    conversationId: nil
                )

                // Update cache statistics
                if cacheReadTokens > 0 || cacheCreationTokens > 0 {
                    CostTracker.shared.recordCacheStats(
                        cacheHit: cacheReadTokens > 0,
                        cacheReadTokens: cacheReadTokens,
                        cacheWriteTokens: cacheCreationTokens
                    )
                }
            }
        }
    }
}

// Gemini Provider
class GeminiProvider: LLMProviderProtocol, @unchecked Sendable {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func sendMessage(_ text: String, configuration: LLMConfiguration) async throws -> String {
        throw NSError(domain: "GeminiProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Use streaming method instead"])
    }

    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void,
        onArtifactCreated: (@Sendable (Artifact) -> Void)? = nil,
        onToolCallUpdate: (@Sendable (ToolCallUpdateEvent) -> Void)? = nil
    ) async throws {
        let model = configuration.model.isEmpty ? "gemini-pro" : configuration.model
        guard let url = URL(string: "\(baseURL)/models/\(model):streamGenerateContent?key=\(apiKey)&alt=sse") else {
            throw NSError(domain: "GeminiProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini API URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        // Build contents array from conversation history
        var contents: [[String: Any]] = []

        // Add system instruction if provided
        var systemInstruction: [String: Any]? = nil
        if let systemPrompt = configuration.systemPrompt, !systemPrompt.isEmpty {
            systemInstruction = ["parts": [["text": systemPrompt]]]
        }

        // Add conversation history
        for message in conversationHistory {
            contents.append([
                "role": message.role == .user ? "user" : "model",
                "parts": [["text": message.content]]
            ])
        }

        // Add current message
        contents.append([
            "role": "user",
            "parts": [["text": text]]
        ])

        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": configuration.temperature,
                "maxOutputTokens": configuration.maxTokens
            ]
        ]

        if let systemInstruction = systemInstruction {
            body["systemInstruction"] = systemInstruction
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GeminiProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Gemini"])
        }

        // Handle HTTP errors with specific messages
        if httpResponse.statusCode != 200 {
            let errorMessage: String
            switch httpResponse.statusCode {
            case 400:
                errorMessage = "Bad request - check your message format"
            case 401, 403:
                errorMessage = "Invalid API key - please check your Gemini API key in Settings"
            case 429:
                errorMessage = "Rate limit exceeded - please wait before sending more requests"
            case 500...599:
                errorMessage = "Google server error - please try again later"
            default:
                errorMessage = "Request failed with status \(httpResponse.statusCode)"
            }
            throw NSError(domain: "GeminiProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            guard !jsonString.isEmpty,
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Parse Gemini response format
            if let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                onChunk(text)
            }
        }
    }
}

// OpenAI Provider with Automatic Prompt Caching Support
// OpenAI automatically caches prompts >= 1024 tokens with 50% discount on cached tokens
class OpenAIProvider: LLMProviderProtocol, @unchecked Sendable {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func sendMessage(_ text: String, configuration: LLMConfiguration) async throws -> String {
        throw NSError(domain: "OpenAIProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Use streaming method instead"])
    }

    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void,
        onArtifactCreated: (@Sendable (Artifact) -> Void)? = nil,
        onToolCallUpdate: (@Sendable (ToolCallUpdateEvent) -> Void)? = nil
    ) async throws {
        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "OpenAIProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid OpenAI API URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        var messages: [[String: Any]] = []

        if let systemPrompt = configuration.systemPrompt {
            messages.append([
                "role": "system",
                "content": systemPrompt
            ])
        }

        for message in conversationHistory {
            messages.append([
                "role": message.role == .user ? "user" : "assistant",
                "content": message.content
            ])
        }

        messages.append([
            "role": "user",
            "content": text
        ])

        var body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "temperature": configuration.temperature,
            "max_tokens": configuration.maxTokens,
            "stream": true
        ]

        // Request usage info in streaming response to track cache hits
        body["stream_options"] = ["include_usage": true]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from OpenAI"])
        }

        // Handle HTTP errors with specific messages
        if httpResponse.statusCode != 200 {
            let errorMessage: String
            switch httpResponse.statusCode {
            case 400:
                errorMessage = "Bad request - check your message format"
            case 401:
                errorMessage = "Invalid API key - please check your OpenAI API key in Settings"
            case 403:
                errorMessage = "Access forbidden - your API key may not have access to this model"
            case 429:
                errorMessage = "Rate limit exceeded - please wait before sending more requests"
            case 500...599:
                errorMessage = "OpenAI server error - please try again later"
            default:
                errorMessage = "Request failed with status \(httpResponse.statusCode)"
            }
            throw NSError(domain: "OpenAIProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // Track token usage for cost calculation
        var inputTokens = 0
        var outputTokens = 0
        var cachedTokens = 0

        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            guard !jsonString.contains("[DONE]"),
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Handle content delta
            if let choices = json["choices"] as? [[String: Any]],
               let delta = choices.first?["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                onChunk(content)
            }

            // Handle usage info (comes at the end of stream with stream_options.include_usage)
            if let usage = json["usage"] as? [String: Any] {
                inputTokens = usage["prompt_tokens"] as? Int ?? 0
                outputTokens = usage["completion_tokens"] as? Int ?? 0

                // OpenAI provides cached token info in prompt_tokens_details
                if let promptDetails = usage["prompt_tokens_details"] as? [String: Any] {
                    cachedTokens = promptDetails["cached_tokens"] as? Int ?? 0
                }
            }
        }

        // Record usage with cache information
        // OpenAI caching is automatic with 50% discount on cached tokens
        if inputTokens > 0 || outputTokens > 0 {
            Task { @MainActor in
                // For OpenAI, cached tokens are part of input tokens (not separate)
                // The pricing model gives 50% discount automatically
                CostTracker.shared.recordUsage(
                    model: configuration.model,
                    inputTokens: inputTokens - cachedTokens, // Non-cached input tokens
                    outputTokens: outputTokens,
                    cacheReadTokens: cachedTokens > 0 ? cachedTokens : nil,
                    cacheWriteTokens: nil, // OpenAI doesn't charge for cache writes
                    conversationId: nil
                )

                // Update cache statistics if there was a cache hit
                if cachedTokens > 0 {
                    CostTracker.shared.recordCacheStats(
                        cacheHit: true,
                        cacheReadTokens: cachedTokens,
                        cacheWriteTokens: 0
                    )
                }
            }
        }
    }
}
