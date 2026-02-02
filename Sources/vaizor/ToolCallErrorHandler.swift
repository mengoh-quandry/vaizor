import Foundation

// Enhanced tool call error handling and recovery
@MainActor
class ToolCallErrorHandler {
    enum ToolCallError: LocalizedError {
        case toolNotFound(String)
        case serverNotRunning(String)
        case invalidArguments(String, [String: Any])
        case executionFailed(String, String)
        case timeout(String)
        case parseError(String)
        
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
            }
        }
    }
    
    // Log and format error for user display
    func handleError(_ error: ToolCallError) -> String {
        var message = "⚠️ Tool Error\n\n"
        
        if let description = error.errorDescription {
            message += description
        }
        
        if let suggestion = error.recoverySuggestion {
            message += "\n\n💡 Suggestion: \(suggestion)"
        }
        
        // Log to console for debugging
        print("🔧 ToolCallError: \(error)")
        
        return message
    }
    
    // Attempt automatic recovery for certain errors
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
                    print("Failed to auto-start server: \(error)")
                    return false
                }
            }
            return false
            
        default:
            return false
        }
    }
    
    // Create user-friendly error message for tool result
    func formatToolErrorResult(_ error: Error) -> String {
        if let toolError = error as? ToolCallError {
            return handleError(toolError)
        }
        
        return """
        {
          "error": "Tool execution failed",
          "message": "\(error.localizedDescription)",
          "type": "execution_error"
        }
        """
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
