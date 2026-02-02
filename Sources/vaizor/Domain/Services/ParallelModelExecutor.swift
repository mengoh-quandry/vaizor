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
    private var isCancelled = false

    func append(_ chunk: String) {
        guard !isCancelled else { return }
        value += chunk
    }

    func current() -> String {
        value
    }

    func cancel() {
        isCancelled = true
    }

    func checkCancelled() -> Bool {
        isCancelled
    }
}

/// Actor to coordinate cancellation state across tasks
private actor CancellationCoordinator {
    private var isCancelled = false

    func cancel() {
        isCancelled = true
    }

    func checkCancelled() -> Bool {
        isCancelled
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
    /// Track individual provider tasks for proper cancellation
    private var providerTasks: [LLMProvider: Task<Void, Never>] = [:]
    /// Lock for thread-safe access to providerTasks
    private let taskLock = NSLock()
    /// Coordinator for signaling cancellation to running tasks
    private var cancellationCoordinator: CancellationCoordinator?

    init(container: DependencyContainer) {
        self.container = container
    }

    /// Thread-safe method to add a provider task
    private func addProviderTask(_ task: Task<Void, Never>, for provider: LLMProvider) {
        taskLock.lock()
        defer { taskLock.unlock() }
        providerTasks[provider] = task
    }

    /// Thread-safe method to remove a provider task
    private func removeProviderTask(for provider: LLMProvider) {
        taskLock.lock()
        defer { taskLock.unlock() }
        providerTasks.removeValue(forKey: provider)
    }

    /// Cancel all tracked provider tasks
    private func cancelAllProviderTasks() {
        taskLock.lock()
        let tasks = providerTasks
        providerTasks.removeAll()
        taskLock.unlock()

        for (_, task) in tasks {
            task.cancel()
        }
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

        // Create a new cancellation coordinator for this execution
        let coordinator = CancellationCoordinator()
        cancellationCoordinator = coordinator

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
                    let isCancelledByCoordinator = await coordinator.checkCancelled()
                    guard !Task.isCancelled && !isCancelledByCoordinator else { break }

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
                        let isCancelledByCoordinator = await coordinator.checkCancelled()
                        guard !Task.isCancelled && !isCancelledByCoordinator else {
                            return (provider, .failure(CancellationError()))
                        }

                        do {
                            let accumulator = ResponseAccumulator()

                            // Use withTaskCancellationHandler to ensure proper cleanup
                            try await withTaskCancellationHandler {
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
                            } onCancel: {
                                // Mark the accumulator as cancelled to stop processing
                                Task {
                                    await accumulator.cancel()
                                }
                            }

                            // Check cancellation before returning result
                            let isCancelledByCoordinator = await coordinator.checkCancelled()
                            guard !Task.isCancelled && !isCancelledByCoordinator else {
                                return (provider, .failure(CancellationError()))
                            }

                            let fullResponse = await accumulator.current()
                            return (provider, .success(fullResponse))
                        } catch {
                            // Check if this is a cancellation-related error
                            if error is CancellationError || Task.isCancelled {
                                return (provider, .failure(CancellationError()))
                            }
                            return (provider, .failure(error))
                        }
                    }
                }

                // Collect results as they complete
                for await (provider, result) in group {
                    // Check for cancellation while collecting results
                    let isCancelledByCoordinator = await coordinator.checkCancelled()
                    guard !Task.isCancelled && !isCancelledByCoordinator else { break }

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
            cancellationCoordinator = nil
        }

        return result
    }

    /// Cancel all ongoing executions
    func cancel() {
        // Signal cancellation to the coordinator for immediate effect
        if let coordinator = cancellationCoordinator {
            Task {
                await coordinator.cancel()
            }
        }
        cancellationCoordinator = nil
        // Cancel individual provider tasks
        cancelAllProviderTasks()
        // Then cancel the main execution task
        currentExecutionTask?.cancel()
        currentExecutionTask = nil
        isExecuting = false
    }

    deinit {
        // Ensure all tasks are cancelled when executor is deallocated
        // Note: Cannot call cancelAllProviderTasks() in deinit as it uses lock
        // Instead, cancel tasks directly
        taskLock.lock()
        for (_, task) in providerTasks {
            task.cancel()
        }
        providerTasks.removeAll()
        taskLock.unlock()
        currentExecutionTask?.cancel()
    }
}
