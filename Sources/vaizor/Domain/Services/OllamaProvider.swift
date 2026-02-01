import Foundation

class OllamaProvider: LLMProviderProtocol, @unchecked Sendable {
    /// Default base URL for Ollama API
    private static let defaultBaseURL = "http://localhost:11434"

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
        onArtifactCreated: (@Sendable (Artifact) -> Void)? = nil
    ) async throws {
        let baseURL = await getBaseURL()
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw NSError(domain: "OllamaProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama URL: \(baseURL)/api/chat"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Get context enhancement settings
        let enableDatetimeInjection = await MainActor.run { AppSettings.shared.enableDatetimeInjection }
        let enableAutoRefresh = await MainActor.run { AppSettings.shared.enableAutoRefresh }

        // Apply context enhancement for local models
        var enhancedSystemPrompt = configuration.systemPrompt
        var contextEnhanced = false

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
                contextEnhanced = true

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

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "stream": true,
            "options": [
                "temperature": configuration.temperature,
                "num_predict": configuration.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Use concurrent URLSession configuration for better performance
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

        var fullResponse = ""

        for try await line in asyncBytes.lines {
            guard !line.isEmpty else { continue }

            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messageContent = json["message"] as? [String: Any],
               let content = messageContent["content"] as? String {
                fullResponse += content
                onChunk(content)
            }
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
        onArtifactCreated: (@Sendable (Artifact) -> Void)? = nil
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
        onArtifactCreated: (@Sendable (Artifact) -> Void)? = nil
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
        onArtifactCreated: (@Sendable (Artifact) -> Void)? = nil
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
