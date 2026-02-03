import Foundation
import SwiftUI

/// Errors related to provider configuration and loading
enum OllamaLoadError: LocalizedError {
    case ollamaNotFound
    case ollamaNotRunning
    case failedToLoadModels(underlying: Error)
    case noModelsAvailable

    var errorDescription: String? {
        switch self {
        case .ollamaNotFound:
            return "Ollama not found. Please install Ollama from https://ollama.ai"
        case .ollamaNotRunning:
            return "Ollama is not running. Please start the Ollama application."
        case .failedToLoadModels(let underlying):
            return "Failed to load Ollama models: \(underlying.localizedDescription)"
        case .noModelsAvailable:
            return "No Ollama models installed. Run 'ollama pull <model>' to download a model."
        }
    }
}

@MainActor
class DependencyContainer: ObservableObject {
    @Published var currentProvider: LLMProvider = .ollama
    @Published var availableModels: [String] = []
    @Published var apiKeys: [LLMProvider: String] = [:] {
        didSet {
            guard !isLoadingKeys else { return }
            persistApiKeys()
        }
    }
    @Published var mcpManager = MCPServerManager()
    @Published var projectManager = ProjectManager()
    @Published var browserAutomation = BrowserAutomation()
    @Published var agentService = AgentService()
    /// Published error state for surfacing provider errors to the UI
    @Published var lastProviderError: Error?

    private let keychainService = KeychainService()
    private var isLoadingKeys = false

    /// Common paths where Ollama might be installed
    private static let ollamaPaths = [
        "/opt/homebrew/bin/ollama",     // Apple Silicon Homebrew
        "/usr/local/bin/ollama",         // Intel Mac Homebrew
        "/usr/bin/ollama",               // System install
        "/Applications/Ollama.app/Contents/Resources/ollama"  // App bundle
    ]

    /// Find the Ollama executable path
    /// This method must be nonisolated to be called from detached tasks
    private nonisolated static func findOllamaPath() -> String? {
        // First check common paths
        for path in ollamaPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallback: try to find via 'which' command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ollama"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty,
                   FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        } catch {
            // Silently fail - we'll return nil if not found
        }

        return nil
    }

    var configuredProviders: [LLMProvider] {
        return LLMProvider.allCases
    }

    init() {
        loadApiKeys()

        // Auto-start MCP servers after initialization
        Task { @MainActor in
            await initializeMCPServers()
        }
    }

    /// Initialize and auto-start all configured MCP servers
    private func initializeMCPServers() async {
        // Wait a brief moment for the app to finish launching
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let serverCount = mcpManager.availableServers.count
        if serverCount > 0 {
            AppLogger.shared.log("Auto-starting \(serverCount) MCP server(s)...", level: .info)
            await mcpManager.startAllServers()

            // Log results
            let enabledCount = mcpManager.enabledServers.count
            let toolCount = mcpManager.availableTools.count
            let resourceCount = mcpManager.availableResources.count
            let promptCount = mcpManager.availablePrompts.count

            AppLogger.shared.log(
                "MCP initialization complete: \(enabledCount)/\(serverCount) servers running, \(toolCount) tools, \(resourceCount) resources, \(promptCount) prompts available",
                level: .info
            )
        } else {
            AppLogger.shared.log("No MCP servers configured. Add servers in Settings → MCP Servers to enable tool support.", level: .info)
        }
    }

    private func loadApiKeys() {
        isLoadingKeys = true
        var loaded: [LLMProvider: String] = [:]
        for provider in LLMProvider.allCases where provider != .ollama {
            if let key = keychainService.getApiKey(for: provider) {
                loaded[provider] = key
            }
        }
        apiKeys = loaded
        isLoadingKeys = false
    }

    private func persistApiKeys() {
        for provider in LLMProvider.allCases where provider != .ollama {
            let key = apiKeys[provider]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if key.isEmpty {
                keychainService.removeApiKey(for: provider)
            } else {
                keychainService.setApiKey(key, for: provider)
            }
        }
    }

    func loadModelsForCurrentProvider() async {
        switch currentProvider {
        case .ollama:
            await loadOllamaModels()
        default:
            availableModels = currentProvider.defaultModels
        }
    }

    private func loadOllamaModels() async {
        // Clear previous error state
        lastProviderError = nil

        let result = await Task.detached(priority: .userInitiated) { () -> Result<[String], OllamaLoadError> in
            // Find Ollama executable
            guard let ollamaPath = DependencyContainer.findOllamaPath() else {
                return .failure(.ollamaNotFound)
            }

            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: ollamaPath)
                process.arguments = ["list"]

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                try process.run()
                process.waitUntilExit()

                // Check exit status
                if process.terminationStatus != 0 {
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrOutput = String(data: stderrData, encoding: .utf8) ?? ""

                    // Check for common "not running" error messages
                    if stderrOutput.contains("connect") || stderrOutput.contains("refused") || stderrOutput.contains("not running") {
                        return .failure(.ollamaNotRunning)
                    }

                    let error = NSError(domain: "Ollama", code: Int(process.terminationStatus),
                                       userInfo: [NSLocalizedDescriptionKey: stderrOutput.isEmpty ? "Unknown error" : stderrOutput])
                    return .failure(.failedToLoadModels(underlying: error))
                }

                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.split(separator: "\n")
                    guard lines.count > 1 else {
                        return .failure(.noModelsAvailable)
                    }

                    var models: [String] = []
                    for line in lines.dropFirst() {
                        let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                        if let modelName = parts.first {
                            models.append(String(modelName))
                        }
                    }

                    if models.isEmpty {
                        return .failure(.noModelsAvailable)
                    }

                    return .success(models)
                }

                return .failure(.noModelsAvailable)
            } catch {
                return .failure(.failedToLoadModels(underlying: error))
            }
        }.value

        switch result {
        case .success(let models):
            availableModels = models
            AppLogger.shared.log("Loaded \(models.count) Ollama models", level: .info)

        case .failure(let error):
            // Surface the error via published state
            lastProviderError = error
            AppLogger.shared.logError(error, context: "Failed to load Ollama models")

            // Fall back to default models so the app remains usable
            availableModels = currentProvider.defaultModels
        }
    }

    func createLLMProvider() -> any LLMProviderProtocol {
        return createLLMProvider(for: currentProvider) ?? PlaceholderLLMProvider()
    }
    
    func createLLMProvider(for provider: LLMProvider) -> (any LLMProviderProtocol)? {
        switch provider {
        case .ollama:
            let instance = OllamaProviderWithMCP()
            instance.mcpManager = mcpManager
            return instance
        case .anthropic:
            guard let apiKey = apiKeys[.anthropic], !apiKey.isEmpty else { return nil }
            return AnthropicProvider(apiKey: apiKey)
        case .openai:
            guard let apiKey = apiKeys[.openai], !apiKey.isEmpty else { return nil }
            return OpenAIProvider(apiKey: apiKey)
        case .gemini:
            guard let apiKey = apiKeys[.gemini], !apiKey.isEmpty else { return nil }
            return GeminiProvider(apiKey: apiKey)
        case .custom:
            return nil // Custom provider not supported
        }
    }
}

/// Error types for provider configuration issues
enum ProviderConfigurationError: LocalizedError {
    case noApiKey(provider: LLMProvider)
    case providerNotSupported(provider: LLMProvider)

    var errorDescription: String? {
        switch self {
        case .noApiKey(let provider):
            return "No API key configured for \(provider.displayName). Please add your API key in Settings."
        case .providerNotSupported(let provider):
            return "\(provider.displayName) is not yet supported."
        }
    }
}

/// Placeholder provider that throws configuration errors
class PlaceholderLLMProvider: LLMProviderProtocol, @unchecked Sendable {
    private let error: Error

    init(error: Error = ProviderConfigurationError.providerNotSupported(provider: .custom)) {
        self.error = error
    }

    func sendMessage(_ text: String, configuration: LLMConfiguration) async throws -> String {
        throw error
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
        throw error
    }
}
