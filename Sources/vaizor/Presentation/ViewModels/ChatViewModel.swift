import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isStreaming = false
    @Published var currentStreamingText = ""
    @Published var error: String?
    @Published var showChainOfThought = false
    @Published var thinkingStatus = "Thinking..."
    @Published var targetReplaceIndex: Int? = nil
    
    // Pagination state
    @Published var isLoadingMore: Bool = false
    @Published var hasMoreMessages: Bool = false
    @Published var isLoadingInitial: Bool = true
    
    // Parallel execution state
    @Published var isParallelMode: Bool = false
    @Published var selectedModels: Set<LLMProvider> = []
    @Published var parallelResponses: [LLMProvider: String] = [:]
    @Published var parallelErrors: [LLMProvider: Error] = [:]

    private let conversationId: UUID
    private let conversationRepository: ConversationRepository
    private var llmProvider: (any LLMProviderProtocol)?
    private var streamTask: Task<Void, Never>?
    private let maxHistoryMessages = 12
    private var parallelExecutor: ParallelModelExecutor?
    
    // Streaming buffer optimization
    private var streamingBuffer: String = ""
    private var bufferUpdateTask: Task<Void, Never>?
    private let bufferUpdateInterval: TimeInterval = 0.05 // 50ms
    
    // Pagination cursor
    private var oldestMessageCursor: (Date, UUID)? = nil

    init(conversationId: UUID, conversationRepository: ConversationRepository, container: DependencyContainer? = nil) {
        self.conversationId = conversationId
        self.conversationRepository = conversationRepository
        
        // Parallel executor will be set when container is available
        if let container = container {
            self.parallelExecutor = ParallelModelExecutor(container: container)
        }

        // Load initial messages chunk
        Task {
            await loadInitialMessages()
        }
    }
    
    func setContainer(_ container: DependencyContainer) {
        if parallelExecutor == nil {
            parallelExecutor = ParallelModelExecutor(container: container)
        }
    }

    func loadInitialMessages() async {
        isLoadingInitial = true
        let result = await conversationRepository.loadMessages(for: conversationId, limit: 100)
        messages = result.messages
        hasMoreMessages = result.hasMore
        oldestMessageCursor = result.lastCursor
        isLoadingInitial = false
    }
    
    func loadMoreMessages() async {
        guard !isLoadingMore && hasMoreMessages, let cursor = oldestMessageCursor else {
            return
        }
        
        isLoadingMore = true
        let result = await conversationRepository.loadMessages(
            for: conversationId,
            after: cursor,
            limit: 100
        )
        
        // Prepend older messages to the beginning
        messages.insert(contentsOf: result.messages, at: 0)
        hasMoreMessages = result.hasMore
        oldestMessageCursor = result.lastCursor
        isLoadingMore = false
    }

    func updateProvider(_ provider: any LLMProviderProtocol) {
        self.llmProvider = provider
    }

    func stopStreaming() {
        streamTask?.cancel()
        bufferUpdateTask?.cancel()
        parallelExecutor?.cancel()
        streamTask = nil
        bufferUpdateTask = nil
        isStreaming = false
        currentStreamingText = ""
        streamingBuffer = ""
        parallelResponses = [:]
        parallelErrors = [:]
        thinkingStatus = "Thinking..."
    }

    func sendMessage(_ text: String, configuration: LLMConfiguration, replaceAtIndex: Int? = nil, attachments: [MessageAttachment]? = nil) async {
        AppLogger.shared.log("Sending message", level: .info)
        
        // Cancel any existing stream
        stopStreaming()
        
        // Handle parallel mode
        if isParallelMode && !selectedModels.isEmpty {
            await sendMessageParallel(text: text, configuration: configuration, replaceAtIndex: replaceAtIndex)
            return
        }

        guard let provider = llmProvider else {
            let errorMsg = "No LLM provider configured"
            AppLogger.shared.log(errorMsg, level: .error)
            error = errorMsg
            return
        }

        let userMessage = Message(
            conversationId: conversationId,
            role: .user,
            content: text,
            attachments: attachments
        )

        // If replacing at a specific index, insert there; otherwise append
        if let replaceIndex = replaceAtIndex, replaceIndex <= messages.count {
            messages.insert(userMessage, at: replaceIndex)
        } else {
            messages.append(userMessage)
        }
        await conversationRepository.saveMessage(userMessage)

        isStreaming = true
        currentStreamingText = ""
        error = nil
        thinkingStatus = "Analyzing request..."

        streamTask = Task { @MainActor in
            do {
                // Get conversation history (excluding the current message)
                let history = messages.dropLast()
                let trimmedHistory = Array(history.suffix(maxHistoryMessages))

                try await AppLogger.shared.measurePerformanceAsync("sendMessage") {
                    try await provider.streamMessage(
                        text,
                        configuration: configuration,
                        conversationHistory: trimmedHistory,
                        onChunk: { [weak self] chunk in
                            guard !Task.isCancelled else { return }
                            
                            // Buffer chunks for batched UI updates
                            Task { @MainActor [weak self] in
                                guard let self = self else { return }
                                self.streamingBuffer += chunk
                                
                                // Schedule buffer flush if not already scheduled
                                if self.bufferUpdateTask == nil {
                                    self.bufferUpdateTask = Task {
                                        try? await Task.sleep(nanoseconds: UInt64(self.bufferUpdateInterval * 1_000_000_000))
                                        guard !Task.isCancelled else { return }
                                        await MainActor.run {
                                            self.flushStreamingBuffer()
                                        }
                                    }
                                }
                            }
                        },
                        onThinkingStatusUpdate: { [weak self] status in
                            // Direct MainActor update for status (low frequency)
                            Task { @MainActor [weak self] in
                                self?.thinkingStatus = status
                            }
                        }
                    )
                }
                
                // Flush any remaining buffer
                flushStreamingBuffer()

                guard !Task.isCancelled else {
                    currentStreamingText = ""
                    return
                }

                // Save the complete response
                let assistantMessage = Message(
                    conversationId: conversationId,
                    role: .assistant,
                    content: currentStreamingText
                )

                // If replacing at a specific index, insert there; otherwise append
                if let replaceIndex = replaceAtIndex, replaceIndex < messages.count {
                    messages.insert(assistantMessage, at: replaceIndex + 1)
                } else {
                    messages.append(assistantMessage)
                }
                await conversationRepository.saveMessage(assistantMessage)
                
                // Clear replace index after use
                targetReplaceIndex = nil

                isStreaming = false
                currentStreamingText = ""
                thinkingStatus = "Thinking..."
                streamTask = nil
                
                AppLogger.shared.log("Message sent successfully", level: .info)
            } catch {
                guard !Task.isCancelled else { return }

                let errorMsg = "Failed to get response: \(error.localizedDescription)"
                AppLogger.shared.logError(error, context: "sendMessage")
                self.error = errorMsg
                isStreaming = false
                currentStreamingText = ""
                thinkingStatus = "Thinking..."
                streamTask = nil
            }
        }
        // Note: Don't await the task - it runs independently and updates published properties
        // Awaiting would block MainActor and cause a deadlock
    }
    
    private func flushStreamingBuffer() {
        guard !streamingBuffer.isEmpty else { return }
        currentStreamingText += streamingBuffer
        streamingBuffer = ""
        bufferUpdateTask = nil
    }
    
    private func sendMessageParallel(text: String, configuration: LLMConfiguration, replaceAtIndex: Int?) async {
        guard let executor = parallelExecutor else {
            error = "Parallel executor not available"
            return
        }
        
        let userMessage = Message(
            conversationId: conversationId,
            role: .user,
            content: text
        )

        // If replacing at a specific index, insert there; otherwise append
        if let replaceIndex = replaceAtIndex, replaceIndex <= messages.count {
            messages.insert(userMessage, at: replaceIndex)
        } else {
            messages.append(userMessage)
        }
        await conversationRepository.saveMessage(userMessage)

        isStreaming = true
        parallelResponses = [:]
        parallelErrors = [:]
        error = nil
        thinkingStatus = "Sending to \(selectedModels.count) models..."

        let history = messages.dropLast()
        let trimmedHistory = Array(history.suffix(maxHistoryMessages))
        let parallelConfig = ParallelExecutionConfig(
            providers: selectedModels,
            baseConfiguration: configuration
        )
        
        let results = await executor.executeParallel(
            text: text,
            config: parallelConfig,
            conversationHistory: trimmedHistory,
            onChunk: { [weak self] provider, chunk in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.parallelResponses[provider] == nil {
                        self.parallelResponses[provider] = ""
                    }
                    self.parallelResponses[provider]? += chunk
                }
            }
        )
        
        // Save all responses as separate assistant messages
        for (provider, modelResponse) in results {
            if let error = modelResponse.error {
                parallelErrors[provider] = error
                continue
            }
            
            let assistantMessage = Message(
                conversationId: conversationId,
                role: .assistant,
                content: modelResponse.response,
                toolCallId: nil,
                toolName: "\(provider.displayName)"
            )
            
            messages.append(assistantMessage)
            await conversationRepository.saveMessage(assistantMessage)
        }
        
        isStreaming = false
        thinkingStatus = "Thinking..."
    }
}

// Protocol for LLM providers
protocol LLMProviderProtocol: Sendable {
    func sendMessage(_ text: String, configuration: LLMConfiguration) async throws -> String
    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void
    ) async throws
}
