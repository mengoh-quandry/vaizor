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
    /// Store the current execution task for cancellation support
    private var currentExecutionTask: Task<[LLMProvider: ModelResponse], Never>?

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
        // Cancel any existing execution before starting a new one
        cancel()

        await MainActor.run {
            isExecuting = true
            responses = [:]
            errors = [:]
            streamingResponses = [:]
        }

        let configurations = config.configurations()

        // Create and store the execution task so it can be cancelled
        let executionTask = Task { [weak self] () -> [LLMProvider: ModelResponse] in
            guard let self else { return [:] }

            var startTimes: [LLMProvider: Date] = [:]
            var localResponses: [LLMProvider: ModelResponse] = [:]

            await withTaskGroup(of: (LLMProvider, Result<String, Error>).self) { group in
                // Start all model executions in parallel
                for (provider, providerConfig) in configurations {
                    // Check for cancellation before starting each provider
                    guard !Task.isCancelled else { break }

                    // Create provider instance using container's method
                    guard let providerInstance = await MainActor.run(body: { self.container.createLLMProvider(for: provider) }) else {
                        await MainActor.run {
                            self.errors[provider] = NSError(
                                domain: "ParallelModelExecutor",
                                code: 2,
                                userInfo: [NSLocalizedDescriptionKey: "Provider not available or API key not configured"]
                            )
                        }
                        continue
                    }

                    startTimes[provider] = Date()

                    group.addTask {
                        // Check for cancellation at the start of each task
                        guard !Task.isCancelled else {
                            return (provider, .failure(CancellationError()))
                        }

                        do {
                            let accumulator = ResponseAccumulator()

                            try await providerInstance.streamMessage(
                                text,
                                configuration: providerConfig,
                                conversationHistory: conversationHistory,
                                onChunk: { chunk in
                                    // Check cancellation before processing chunk
                                    guard !Task.isCancelled else { return }
                                    onChunk(provider, chunk)
                                    Task {
                                        await accumulator.append(chunk)
                                    }
                                },
                                onThinkingStatusUpdate: { _ in }
                            )

                            // Check cancellation before returning result
                            guard !Task.isCancelled else {
                                return (provider, .failure(CancellationError()))
                            }

                            let fullResponse = await accumulator.current()
                            return (provider, .success(fullResponse))
                        } catch {
                            return (provider, .failure(error))
                        }
                    }
                }

                // Collect results as they complete
                for await (provider, result) in group {
                    // Check for cancellation while collecting results
                    guard !Task.isCancelled else { break }

                    let startTime = startTimes[provider] ?? Date()
                    let latency = Date().timeIntervalSince(startTime)
                    guard let providerConfig = configurations[provider] else {
                        continue // Skip if configuration not found
                    }

                    switch result {
                    case .success(let response):
                        // Estimate token count (~4 chars per token for English text)
                        // Note: Actual token counts would require provider-specific parsing
                        // of response metadata, which varies by API and isn't available during streaming
                        let estimatedTokens = response.count / 4

                        let modelResponse = ModelResponse(
                            provider: provider,
                            model: providerConfig.model,
                            response: response,
                            error: nil,
                            latency: latency,
                            tokenCount: estimatedTokens,
                            completedAt: Date()
                        )

                        localResponses[provider] = modelResponse

                        await MainActor.run {
                            self.responses[provider] = modelResponse
                            self.errors.removeValue(forKey: provider)
                            self.streamingResponses[provider] = response
                        }

                    case .failure(let error):
                        // Don't report cancellation errors as real errors
                        if !(error is CancellationError) {
                            let modelResponse = ModelResponse(
                                provider: provider,
                                model: providerConfig.model,
                                response: "",
                                error: error,
                                latency: latency,
                                tokenCount: nil,
                                completedAt: Date()
                            )
                            localResponses[provider] = modelResponse

                            await MainActor.run {
                                self.errors[provider] = error
                                self.responses[provider] = modelResponse
                            }
                        }
                    }
                }
            }

            return localResponses
        }

        currentExecutionTask = executionTask

        let result = await executionTask.value

        await MainActor.run {
            isExecuting = false
            currentExecutionTask = nil
        }

        return result
    }

    /// Cancel all ongoing executions
    func cancel() {
        currentExecutionTask?.cancel()
        currentExecutionTask = nil
        isExecuting = false
    }

    deinit {
        // Ensure task is cancelled when executor is deallocated
        currentExecutionTask?.cancel()
    }
}
