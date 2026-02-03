import Foundation

// Enhanced tool call error handling, retry logic, and recovery
@MainActor
class ToolCallErrorHandler {
    static let shared = ToolCallErrorHandler()

    // MARK: - Error Types

    enum ToolCallError: LocalizedError {
        case toolNotFound(String)
        case serverNotRunning(String)
        case invalidArguments(String, [String: Any])
        case executionFailed(String, String)
        case timeout(String)
        case parseError(String)
        case rateLimited(String, retryAfter: TimeInterval?)
        case networkError(String, underlying: Error?)
        case validationFailed(String, details: String)

        var errorDescription: String? {
            switch self {
            case .toolNotFound(let name):
                return "Tool '\(name)' not found. Check that the MCP server is enabled and the tool name is correct."
            case .serverNotRunning(let server):
                return "MCP server '\(server)' is not running. Enable it in Settings."
            case .invalidArguments(let tool, let args):
                return "Invalid arguments for '\(tool)': \(args.keys.joined(separator: ", "))"
            case .executionFailed(let tool, let message):
                return "Tool '\(tool)' execution failed: \(message)"
            case .timeout(let tool):
                return "Tool '\(tool)' timed out. The operation took too long to complete."
            case .parseError(let details):
                return "Failed to parse tool call: \(details)"
            case .rateLimited(let tool, _):
                return "Tool '\(tool)' is rate limited. Please wait before retrying."
            case .networkError(let tool, let underlying):
                return "Network error calling '\(tool)': \(underlying?.localizedDescription ?? "Connection failed")"
            case .validationFailed(let tool, let details):
                return "Tool '\(tool)' result validation failed: \(details)"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .toolNotFound:
                return "Enable the required MCP server in Settings > MCP Servers, or check the tool name spelling."
            case .serverNotRunning:
                return "Go to Settings > MCP Servers and enable the required server."
            case .invalidArguments:
                return "Check the tool documentation for required argument format."
            case .executionFailed:
                return "Check the MCP server logs or try restarting the server."
            case .timeout:
                return "Try again or increase the timeout duration in settings."
            case .parseError:
                return "The model may have generated an invalid tool call format. Try rephrasing your request."
            case .rateLimited(_, let retryAfter):
                if let delay = retryAfter {
                    return "Wait \(Int(delay)) seconds before retrying."
                }
                return "Wait a moment before retrying."
            case .networkError:
                return "Check your network connection and try again."
            case .validationFailed:
                return "The tool returned unexpected data. Try the request again."
            }
        }

        /// Whether this error type is transient and can be retried
        var isRetryable: Bool {
            switch self {
            case .toolNotFound, .invalidArguments, .parseError, .validationFailed:
                return false // Permanent errors
            case .serverNotRunning, .executionFailed, .timeout, .rateLimited, .networkError:
                return true // Transient errors
            }
        }

        /// Suggested delay before retry (for transient errors)
        var suggestedRetryDelay: TimeInterval {
            switch self {
            case .rateLimited(_, let retryAfter):
                return retryAfter ?? 5.0
            case .timeout:
                return 2.0
            case .networkError:
                return 1.0
            case .serverNotRunning:
                return 3.0 // Give server time to start
            case .executionFailed:
                return 1.0
            default:
                return 0
            }
        }
    }

    // MARK: - Retry Configuration

    struct RetryConfig {
        var maxRetries: Int = 3
        var baseDelay: TimeInterval = 1.0
        var maxDelay: TimeInterval = 30.0
        var backoffMultiplier: Double = 2.0
        var jitterFactor: Double = 0.1 // 10% jitter

        /// Calculate delay for a given attempt using exponential backoff with jitter
        func delayForAttempt(_ attempt: Int) -> TimeInterval {
            let exponentialDelay = baseDelay * pow(backoffMultiplier, Double(attempt))
            let cappedDelay = min(exponentialDelay, maxDelay)

            // Add jitter to prevent thundering herd
            let jitter = cappedDelay * jitterFactor * (Double.random(in: -1...1))
            return max(0.1, cappedDelay + jitter)
        }
    }

    var defaultRetryConfig = RetryConfig()

    // Per-tool retry configurations
    private var toolRetryConfigs: [String: RetryConfig] = [:]

    /// Set custom retry config for a specific tool
    func setRetryConfig(_ config: RetryConfig, forTool toolName: String) {
        toolRetryConfigs[toolName] = config
    }

    /// Get retry config for a tool (falls back to default)
    func retryConfig(forTool toolName: String) -> RetryConfig {
        return toolRetryConfigs[toolName] ?? defaultRetryConfig
    }

    // MARK: - Retry State Tracking

    /// Tracks retry state for a tool call
    struct RetryState {
        let toolCallId: UUID
        let toolName: String
        let arguments: [String: Any]
        var attemptCount: Int = 0
        var lastError: ToolCallError?
        var lastAttemptTime: Date?

        var canRetry: Bool {
            guard let error = lastError else { return true }
            return error.isRetryable
        }
    }

    private var retryStates: [UUID: RetryState] = [:]

    /// Create or update retry state for a tool call
    func trackRetry(
        toolCallId: UUID,
        toolName: String,
        arguments: [String: Any],
        error: ToolCallError?
    ) -> RetryState {
        var state = retryStates[toolCallId] ?? RetryState(
            toolCallId: toolCallId,
            toolName: toolName,
            arguments: arguments
        )
        state.attemptCount += 1
        state.lastError = error
        state.lastAttemptTime = Date()
        retryStates[toolCallId] = state
        return state
    }

    /// Get retry state for a tool call
    func getRetryState(_ toolCallId: UUID) -> RetryState? {
        return retryStates[toolCallId]
    }

    /// Clear retry state (on success or cancellation)
    func clearRetryState(_ toolCallId: UUID) {
        retryStates.removeValue(forKey: toolCallId)
    }

    /// Check if a tool call should be retried
    func shouldRetry(
        toolCallId: UUID,
        error: ToolCallError,
        config: RetryConfig? = nil
    ) -> (shouldRetry: Bool, delay: TimeInterval) {
        let retryConfig = config ?? defaultRetryConfig

        guard error.isRetryable else {
            return (false, 0)
        }

        let state = retryStates[toolCallId]
        let attemptCount = state?.attemptCount ?? 0

        guard attemptCount < retryConfig.maxRetries else {
            return (false, 0)
        }

        // Use error's suggested delay or calculate exponential backoff
        let delay = max(error.suggestedRetryDelay, retryConfig.delayForAttempt(attemptCount))
        return (true, delay)
    }
    
    // MARK: - Error Handling

    /// Log and format error for user display
    func handleError(_ error: ToolCallError, attemptNumber: Int? = nil) -> String {
        var message = "⚠️ Tool Error"

        if let attempt = attemptNumber {
            message += " (Attempt \(attempt))"
        }

        message += "\n\n"

        if let description = error.errorDescription {
            message += description
        }

        if let suggestion = error.recoverySuggestion {
            message += "\n\n💡 Suggestion: \(suggestion)"
        }

        if error.isRetryable {
            message += "\n\n🔄 This error may be temporary. Retry available."
        }

        // Log to console for debugging
        AppLogger.shared.log("ToolCallError: \(error)", level: .warning)

        return message
    }

    /// Attempt automatic recovery for certain errors
    func attemptRecovery(
        for error: ToolCallError,
        mcpManager: MCPServerManager
    ) async -> Bool {
        switch error {
        case .serverNotRunning(let serverName):
            // Try to find and start the server
            if let server = mcpManager.availableServers.first(where: {
                $0.name.lowercased() == serverName.lowercased() ||
                $0.id.lowercased() == serverName.lowercased()
            }) {
                do {
                    try await mcpManager.startServer(server)
                    return true
                } catch {
                    AppLogger.shared.logError(error, context: "Failed to auto-start server")
                    return false
                }
            }
            return false

        case .networkError:
            // Brief pause before retry for network errors
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            return true

        default:
            return false
        }
    }

    /// Create user-friendly error message for tool result
    func formatToolErrorResult(_ error: Error, toolCallId: UUID? = nil) -> String {
        if let toolError = error as? ToolCallError {
            let attemptNumber = toolCallId.flatMap { retryStates[$0]?.attemptCount }
            return handleError(toolError, attemptNumber: attemptNumber)
        }

        return """
        {
          "error": "Tool execution failed",
          "message": "\(error.localizedDescription)",
          "type": "execution_error",
          "retryable": false
        }
        """
    }

    // MARK: - Self-Healing & Partial Results

    /// Represents a self-healed result with partial data
    struct SelfHealedResult {
        let partialData: String?
        let successfulParts: [String]
        let failedParts: [String]
        let explanation: String
        let canContinue: Bool
        let suggestions: [String]
    }

    /// Attempt to extract partial results from a failed tool call
    func extractPartialResults(from result: MCPToolResult, toolName: String) -> SelfHealedResult? {
        // Only attempt self-healing if there's actual content
        let content = result.content.compactMap { $0.text }.joined(separator: "\n")
        guard !content.isEmpty else { return nil }

        var successfulParts: [String] = []
        var failedParts: [String] = []
        var partialData: String? = nil
        var canContinue = false

        // Check for truncation
        if content.contains("[truncated]") || content.contains("...truncated") {
            let truncatedContent = content.replacingOccurrences(of: "[truncated]", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !truncatedContent.isEmpty {
                successfulParts.append("Retrieved partial data before truncation")
                partialData = truncatedContent
                canContinue = true
            }
            failedParts.append("Full result was too large and was truncated")
        }

        // Check for partial JSON responses
        if let jsonRange = content.range(of: "\\{[^{}]*\\}", options: .regularExpression) {
            let jsonPart = String(content[jsonRange])
            if let data = jsonPart.data(using: .utf8),
               let _ = try? JSONSerialization.jsonObject(with: data) {
                successfulParts.append("Extracted valid JSON fragment")
                partialData = (partialData ?? "") + "\n" + jsonPart
                canContinue = true
            }
        }

        // Check for error + data pattern (some tools return both)
        let lines = content.components(separatedBy: "\n")
        var dataLines: [String] = []
        var errorLines: [String] = []

        for line in lines {
            let lowerLine = line.lowercased()
            if lowerLine.contains("error") || lowerLine.contains("failed") || lowerLine.contains("exception") {
                errorLines.append(line)
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                dataLines.append(line)
            }
        }

        if !dataLines.isEmpty {
            successfulParts.append("Found \(dataLines.count) lines of data")
            partialData = dataLines.joined(separator: "\n")
            canContinue = true
        }

        if !errorLines.isEmpty {
            failedParts.append(contentsOf: errorLines.prefix(3).map { $0.prefix(100) + "..." })
        }

        // Generate explanation
        let explanation = generateExplanation(
            toolName: toolName,
            successfulParts: successfulParts,
            failedParts: failedParts
        )

        // Generate suggestions
        let suggestions = generateSuggestions(
            toolName: toolName,
            failedParts: failedParts,
            hasPartialData: partialData != nil
        )

        // Only return self-healed result if we have something useful
        guard canContinue || !successfulParts.isEmpty else { return nil }

        return SelfHealedResult(
            partialData: partialData,
            successfulParts: successfulParts,
            failedParts: failedParts,
            explanation: explanation,
            canContinue: canContinue,
            suggestions: suggestions
        )
    }

    /// Generate human-readable explanation of what happened
    private func generateExplanation(
        toolName: String,
        successfulParts: [String],
        failedParts: [String]
    ) -> String {
        var explanation = ""

        if !successfulParts.isEmpty {
            explanation += "✓ **What worked:**\n"
            for part in successfulParts {
                explanation += "  • \(part)\n"
            }
        }

        if !failedParts.isEmpty {
            explanation += "\n✗ **What failed:**\n"
            for part in failedParts.prefix(3) {
                explanation += "  • \(part)\n"
            }
        }

        return explanation
    }

    /// Generate actionable suggestions based on failure
    private func generateSuggestions(
        toolName: String,
        failedParts: [String],
        hasPartialData: Bool
    ) -> [String] {
        var suggestions: [String] = []
        let failureText = failedParts.joined(separator: " ").lowercased()

        if failureText.contains("timeout") {
            suggestions.append("Try a more specific query to reduce response size")
            suggestions.append("Break the request into smaller parts")
        }

        if failureText.contains("truncat") {
            suggestions.append("Request smaller chunks of data")
            suggestions.append("Use pagination if the tool supports it")
        }

        if failureText.contains("rate") || failureText.contains("limit") {
            suggestions.append("Wait a few seconds before retrying")
            suggestions.append("Reduce request frequency")
        }

        if failureText.contains("auth") || failureText.contains("permission") {
            suggestions.append("Check API credentials in settings")
            suggestions.append("Verify the tool has required permissions")
        }

        if failureText.contains("network") || failureText.contains("connection") {
            suggestions.append("Check your internet connection")
            suggestions.append("The service may be temporarily unavailable")
        }

        if hasPartialData {
            suggestions.insert("Review the partial results below - they may contain useful information", at: 0)
        }

        return suggestions
    }

    /// Format a self-healed result for display
    func formatSelfHealedResult(_ healed: SelfHealedResult, toolName: String) -> String {
        var output = "## Partial Results Available\n\n"
        output += "The `\(toolName)` tool encountered an issue but recovered some data.\n\n"
        output += healed.explanation

        if !healed.suggestions.isEmpty {
            output += "\n💡 **Suggestions:**\n"
            for suggestion in healed.suggestions {
                output += "  • \(suggestion)\n"
            }
        }

        if let data = healed.partialData {
            output += "\n---\n\n### Retrieved Data\n\n"
            // Truncate very long partial data for display
            if data.count > 5000 {
                output += String(data.prefix(5000)) + "\n\n*[Showing first 5000 characters]*"
            } else {
                output += data
            }
        }

        return output
    }

    /// Process a tool result with self-healing
    func processWithSelfHealing(
        result: MCPToolResult,
        toolName: String
    ) -> MCPToolResult {
        // If not an error, return as-is
        guard result.isError else { return result }

        // Attempt to extract partial results
        guard let healed = extractPartialResults(from: result, toolName: toolName),
              healed.canContinue else {
            return result
        }

        // Create a new result with the self-healed content
        let formattedContent = formatSelfHealedResult(healed, toolName: toolName)

        AppLogger.shared.log(
            "Self-healing recovered partial results for \(toolName): \(healed.successfulParts.count) parts",
            level: .info
        )

        return MCPToolResult(
            content: [MCPContent(type: "text", text: formattedContent)],
            isError: false // Mark as non-error since we have usable data
        )
    }

    // MARK: - Retry Execution

    /// Execute a tool call with automatic retry
    func executeWithRetry(
        toolName: String,
        arguments: [String: Any],
        mcpManager: MCPServerManager,
        conversationId: UUID,
        config: RetryConfig? = nil,
        onAttempt: ((Int, TimeInterval?) -> Void)? = nil
    ) async -> MCPToolResult {
        let toolCallId = UUID()
        let retryConfig = config ?? self.retryConfig(forTool: toolName)
        var lastResult: MCPToolResult?

        for attempt in 0..<(retryConfig.maxRetries + 1) {
            // Notify of attempt
            let delay: TimeInterval? = attempt > 0 ? retryConfig.delayForAttempt(attempt - 1) : nil
            onAttempt?(attempt + 1, delay)

            // Wait for delay if this is a retry
            if let delay = delay, attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            // Execute the tool
            let result = await mcpManager.callTool(
                toolName: toolName,
                arguments: arguments,
                conversationId: conversationId
            )

            lastResult = result

            // Success - clear retry state and return
            if !result.isError {
                clearRetryState(toolCallId)
                return result
            }

            // Check if we should retry
            let error = classifyError(from: result, toolName: toolName)
            let state = trackRetry(
                toolCallId: toolCallId,
                toolName: toolName,
                arguments: arguments,
                error: error
            )

            let (shouldRetry, _) = self.shouldRetry(
                toolCallId: toolCallId,
                error: error,
                config: retryConfig
            )

            if !shouldRetry || !state.canRetry {
                break
            }

            // Attempt recovery before retry
            _ = await attemptRecovery(for: error, mcpManager: mcpManager)

            AppLogger.shared.log(
                "Retrying tool \(toolName) (attempt \(attempt + 2)/\(retryConfig.maxRetries + 1))",
                level: .info
            )
        }

        clearRetryState(toolCallId)

        // Attempt self-healing on the final result
        if let finalResult = lastResult {
            let healedResult = processWithSelfHealing(result: finalResult, toolName: toolName)
            if !healedResult.isError {
                AppLogger.shared.log(
                    "Self-healing succeeded for \(toolName) after \(retryConfig.maxRetries + 1) attempts",
                    level: .info
                )
                return healedResult
            }
            return finalResult
        }

        return MCPToolResult(
            content: [MCPContent(type: "text", text: "Tool execution failed after \(retryConfig.maxRetries + 1) attempts")],
            isError: true
        )
    }

    /// Classify an error from a tool result
    func classifyError(from result: MCPToolResult, toolName: String) -> ToolCallError {
        let errorText = result.content.compactMap { $0.text }.joined(separator: " ").lowercased()

        if errorText.contains("not found") || errorText.contains("does not exist") {
            return .toolNotFound(toolName)
        }
        if errorText.contains("not running") || errorText.contains("server") && errorText.contains("stopped") {
            return .serverNotRunning(toolName)
        }
        if errorText.contains("timeout") || errorText.contains("timed out") {
            return .timeout(toolName)
        }
        if errorText.contains("rate limit") || errorText.contains("too many requests") {
            return .rateLimited(toolName, retryAfter: nil)
        }
        if errorText.contains("network") || errorText.contains("connection") {
            return .networkError(toolName, underlying: nil)
        }
        if errorText.contains("invalid") && errorText.contains("argument") {
            return .invalidArguments(toolName, [:])
        }

        return .executionFailed(toolName, errorText)
    }
}

// MARK: - Retryable Tool Call Model

/// Represents a tool call that can be retried from the UI
struct RetryableToolCall: Identifiable, Equatable {
    let id: UUID
    let toolName: String
    let arguments: [String: Any]
    let conversationId: UUID
    var retryCount: Int = 0
    var lastError: String?
    var isRetrying: Bool = false

    static func == (lhs: RetryableToolCall, rhs: RetryableToolCall) -> Bool {
        lhs.id == rhs.id && lhs.retryCount == rhs.retryCount && lhs.isRetrying == rhs.isRetrying
    }
}

// Enhanced tool call validation
extension OllamaProviderWithMCP {
    func validateToolCall(_ toolCall: ToolCallParser.ParsedToolCall) -> Result<Void, ToolCallErrorHandler.ToolCallError> {
        // Check tool name format
        let components = toolCall.name.split(separator: "::")
        guard components.count == 2 else {
            return .failure(.parseError("Tool name must be in format 'server::tool', got '\(toolCall.name)'"))
        }
        
        // Validate arguments
        guard !toolCall.arguments.isEmpty else {
            // Some tools might not require arguments
            return .success(())
        }
        
        return .success(())
    }
}
