import Foundation
import SwiftUI

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

    private let keychainService = KeychainService()
    private var isLoadingKeys = false

    var configuredProviders: [LLMProvider] {
        return LLMProvider.allCases
    }

    init() {
        loadApiKeys()
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
        let models = await Task.detached(priority: .userInitiated) { () -> [String] in
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ollama")
                process.arguments = ["list"]

                let pipe = Pipe()
                process.standardOutput = pipe

                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.split(separator: "\n")
                    guard lines.count > 1 else { return [] }

                    var models: [String] = []
                    for line in lines.dropFirst() {
                        let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                        if let modelName = parts.first {
                            models.append(String(modelName))
                        }
                    }
                    return models
                }
            } catch {
                Task { @MainActor in
                    AppLogger.shared.logError(error, context: "Failed to load Ollama models")
                }
            }
            return []
        }.value

        availableModels = models.isEmpty ? currentProvider.defaultModels : models
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
            // TODO: Implement GeminiProvider when available
            return nil
        case .custom:
            return nil // Custom provider not supported
        }
    }
}

// Placeholder LLM provider implementation
class PlaceholderLLMProvider: LLMProviderProtocol, @unchecked Sendable {
    func sendMessage(_ text: String, configuration: LLMConfiguration) async throws -> String {
        return "This is a placeholder response. Configure your API key in Settings."
    }

    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void
    ) async throws {
        let message = "Please configure your API key in Settings to use this provider."
        for char in message {
            onChunk(String(char))
        }
    }
}
