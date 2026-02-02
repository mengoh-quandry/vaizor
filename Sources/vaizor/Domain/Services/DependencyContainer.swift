import Foundation
import SwiftUI

@MainActor
class DependencyContainer: ObservableObject {
    @Published var currentProvider: LLMProvider = .ollama
    @Published var availableModels: [String] = []
    @Published var apiKeys: [LLMProvider: String] = [:]
    @Published var mcpManager = MCPServerManager()
    @Published var browserAutomation = BrowserAutomation()

    var configuredProviders: [LLMProvider] {
        return LLMProvider.allCases
    }
    
    // Computed properties for browser tools
    var browserTool: BrowserTool {
        BrowserTool(automation: browserAutomation)
    }
    
    var localBrowserTool: LocalBrowserToolAdapter {
        LocalBrowserToolAdapter(tool: browserTool)
    }

    init() {
        // Basic initialization
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
                let models = parseOllamaModels(from: output)
                availableModels = models.isEmpty ? currentProvider.defaultModels : models
            } else {
                availableModels = currentProvider.defaultModels
            }
        } catch {
            print("Error loading Ollama models: \(error)")
            availableModels = currentProvider.defaultModels
        }
    }

    private func parseOllamaModels(from output: String) -> [String] {
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

    func createLLMProvider() -> any LLMProviderProtocol {
        switch currentProvider {
        case .ollama:
            let provider = OllamaProviderWithMCP()
            provider.mcpManager = mcpManager
            provider.browserTool = browserTool
            return provider
        case .anthropic:
            if let apiKey = apiKeys[.anthropic], !apiKey.isEmpty {
                return AnthropicProvider(apiKey: apiKey)
            }
            return PlaceholderLLMProvider()
        case .openai:
            if let apiKey = apiKeys[.openai], !apiKey.isEmpty {
                return OpenAIProvider(apiKey: apiKey)
            }
            return PlaceholderLLMProvider()
        case .gemini, .custom:
            return PlaceholderLLMProvider()
        }
    }
}

// Placeholder LLM provider implementation
class PlaceholderLLMProvider: LLMProviderProtocol {
    func sendMessage(_ text: String, configuration: LLMConfiguration) async throws -> String {
        return "This is a placeholder response. Configure your API key in Settings."
    }

    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping (String) -> Void
    ) async throws {
        let message = "Please configure your API key in Settings to use this provider."
        for char in message {
            onChunk(String(char))
            try await Task.sleep(nanoseconds: 30_000_000)
        }
    }
}
