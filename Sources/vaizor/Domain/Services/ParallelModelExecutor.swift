import Foundation

/// Result from a single model execution
struct ModelResponse {
    let provider: LLMProvider
    let model: String
    let response: String
    let error: Error?
    let latency: TimeInterval
    let tokenCount: Int?
    let completedAt: Date
}

/// Configuration for parallel execution
struct ParallelExecutionConfig {
    let providers: Set<LLMProvider>
    let baseConfiguration: LLMConfiguration
    
    /// Create configurations for each provider
    func configurations() -> [LLMProvider: LLMConfiguration] {
        var configs: [LLMProvider: LLMConfiguration] = [:]
        for provider in providers {
            // Use the first available model for each provider, or fallback to default
            let model = provider.defaultModels.first ?? "default"
            configs[provider] = LLMConfiguration(
                provider: provider,
                model: model,
                temperature: baseConfiguration.temperature,
                maxTokens: baseConfiguration.maxTokens,
                systemPrompt: baseConfiguration.systemPrompt,
                enableChainOfThought: baseConfiguration.enableChainOfThought,
                enablePromptEnhancement: baseConfiguration.enablePromptEnhancement
            )
        }
        return configs
    }
}

private actor ResponseAccumulator {
    private var value = ""

    func append(_ chunk: String) {
        value += chunk
    }

    func current() -> String {
        value
    }
}

/// Executes the same prompt across multiple LLM models in parallel
@MainActor
class ParallelModelExecutor: ObservableObject {
    @Published var responses: [LLMProvider: ModelResponse] = [:]
    @Published var isExecuting: Bool = false
    @Published var errors: [LLMProvider: Error] = [:]
    @Published var streamingResponses: [LLMProvider: String] = [:]
    
    private let container: DependencyContainer
    
    init(container: DependencyContainer) {
        self.container = container
    }
    
    /// Execute a prompt across multiple models in parallel
    /// - Parameters:
    ///   - text: The prompt text
    ///   - config: Parallel execution configuration
    ///   - conversationHistory: Previous messages in conversation
    ///   - onChunk: Callback for streaming chunks (provider, chunk)
    /// - Returns: Dictionary of provider to final response
    func executeParallel(
        text: String,
        config: ParallelExecutionConfig,
        conversationHistory: [Message],
        onChunk: @escaping @Sendable (LLMProvider, String) -> Void
    ) async -> [LLMProvider: ModelResponse] {
        await MainActor.run {
            isExecuting = true
            responses = [:]
            errors = [:]
            streamingResponses = [:]
        }
        
        let configurations = config.configurations()
        var startTimes: [LLMProvider: Date] = [:]
        
        await withTaskGroup(of: (LLMProvider, Result<String, Error>).self) { group in
            // Start all model executions in parallel
            for (provider, providerConfig) in configurations {
                // Create provider instance using container's method
                guard let providerInstance = container.createLLMProvider(for: provider) else {
                    await MainActor.run {
                        errors[provider] = NSError(
                            domain: "ParallelModelExecutor",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Provider not available or API key not configured"]
                        )
                    }
                    continue
                }
                
                startTimes[provider] = Date()
                
                group.addTask {
                    do {
                        let accumulator = ResponseAccumulator()
                        
                        try await providerInstance.streamMessage(
                            text,
                            configuration: providerConfig,
                            conversationHistory: conversationHistory,
                            onChunk: { chunk in
                                onChunk(provider, chunk)
                                Task {
                                    await accumulator.append(chunk)
                                }
                            },
                            onThinkingStatusUpdate: { _ in }
                        )
                        
                        let fullResponse = await accumulator.current()
                        return (provider, .success(fullResponse))
                    } catch {
                        return (provider, .failure(error))
                    }
                }
            }
            
            // Collect results as they complete
            for await (provider, result) in group {
                let startTime = startTimes[provider] ?? Date()
                let latency = Date().timeIntervalSince(startTime)
                let providerConfig = configurations[provider]!
                
                switch result {
                case .success(let response):
                    let modelResponse = ModelResponse(
                        provider: provider,
                        model: providerConfig.model,
                        response: response,
                        error: nil,
                        latency: latency,
                        tokenCount: nil, // TODO: Extract from provider if available
                        completedAt: Date()
                    )
                    
                    await MainActor.run {
                        responses[provider] = modelResponse
                        errors.removeValue(forKey: provider)
                        streamingResponses[provider] = response
                    }
                    
                case .failure(let error):
                    await MainActor.run {
                        errors[provider] = error
                        let modelResponse = ModelResponse(
                            provider: provider,
                            model: providerConfig.model,
                            response: "",
                            error: error,
                            latency: latency,
                            tokenCount: nil,
                            completedAt: Date()
                        )
                        responses[provider] = modelResponse
                    }
                }
            }
        }
        
        await MainActor.run {
            isExecuting = false
        }
        
        return responses
    }
    
    /// Cancel all ongoing executions
    func cancel() {
        // Note: Individual tasks will need to check cancellation
        // This is a placeholder for cancellation logic
        isExecuting = false
    }
}
