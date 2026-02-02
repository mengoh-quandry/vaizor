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

    private let conversationId: UUID
    private let conversationRepository: ConversationRepository
    private var llmProvider: (any LLMProviderProtocol)?
    private var streamTask: Task<Void, Never>?

    init(conversationId: UUID, conversationRepository: ConversationRepository) {
        self.conversationId = conversationId
        self.conversationRepository = conversationRepository

        Task {
            await loadMessages()
        }
    }

    func loadMessages() async {
        messages = await conversationRepository.loadMessages(for: conversationId)
    }

    func updateProvider(_ provider: any LLMProviderProtocol) {
        self.llmProvider = provider
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        currentStreamingText = ""
        thinkingStatus = "Thinking..."
    }

    func sendMessage(_ text: String, configuration: LLMConfiguration) async {
        // Cancel any existing stream
        stopStreaming()

        guard let provider = llmProvider else {
            error = "No LLM provider configured"
            return
        }

        let userMessage = Message(
            conversationId: conversationId,
            role: .user,
            content: text
        )

        messages.append(userMessage)
        await conversationRepository.saveMessage(userMessage)

        isStreaming = true
        currentStreamingText = ""
        error = nil
        thinkingStatus = "Initializing..."

        // Generate dynamic thinking status in parallel
        let thinkingTask = Task {
            var statusIndex = 0
            let baseStatuses = [
                "Reading your message",
                "Understanding context",
                "Searching knowledge",
                "Processing information",
                "Formulating thoughts",
                "Structuring response",
                "Choosing words carefully",
                "Refining answer"
            ]

            while !Task.isCancelled && isStreaming && currentStreamingText.isEmpty {
                let status = baseStatuses[statusIndex % baseStatuses.count]
                thinkingStatus = "\(status)..."
                statusIndex += 1
                try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s
            }
        }

        streamTask = Task {
            defer {
                thinkingTask.cancel()
            }

            do {
                // Get conversation history (excluding the current message)
                let history = messages.dropLast()

                var wordCount = 0
                var sentenceCount = 0

                try await provider.streamMessage(
                    text,
                    configuration: configuration,
                    conversationHistory: Array(history),
                    onChunk: { [weak self] chunk in
                    guard !Task.isCancelled else { return }

                    Task { @MainActor in
                        self?.currentStreamingText += chunk

                        // Update status dynamically based on progress
                        wordCount += chunk.split(separator: " ").count
                        if chunk.contains(".") || chunk.contains("!") || chunk.contains("?") {
                            sentenceCount += 1
                        }

                        if sentenceCount == 0 {
                            self?.thinkingStatus = "Starting response..."
                        } else if sentenceCount < 3 {
                            self?.thinkingStatus = "Building answer..."
                        } else if sentenceCount < 6 {
                            self?.thinkingStatus = "Elaborating..."
                        } else {
                            self?.thinkingStatus = "Finalizing details..."
                        }
                    }
                },
                    onToolResult: { [weak self] toolResult in
                        guard !Task.isCancelled else { return }

                        Task { @MainActor in
                            guard let self else { return }
                            let toolMessage = Message(
                                conversationId: self.conversationId,
                                role: .tool,
                                content: toolResult
                            )
                            self.messages.append(toolMessage)
                            await self.conversationRepository.saveMessage(toolMessage)
                        }
                    }
                )

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

                messages.append(assistantMessage)
                await conversationRepository.saveMessage(assistantMessage)

                isStreaming = false
                currentStreamingText = ""
                thinkingStatus = "Thinking..."
                streamTask = nil
            } catch {
                guard !Task.isCancelled else { return }

                self.error = "Failed to get response: \(error.localizedDescription)"
                isStreaming = false
                currentStreamingText = ""
                thinkingStatus = "Thinking..."
                streamTask = nil
            }
        }

        await streamTask?.value
    }
}

// Protocol for LLM providers
protocol LLMProviderProtocol {
    func sendMessage(_ text: String, configuration: LLMConfiguration) async throws -> String
    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping (String) -> Void
    ) async throws
    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping (String) -> Void,
        onToolResult: @escaping (String) -> Void
    ) async throws
}

extension LLMProviderProtocol {
    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping (String) -> Void,
        onToolResult: @escaping (String) -> Void
    ) async throws {
        _ = onToolResult
        try await streamMessage(
            text,
            configuration: configuration,
            conversationHistory: conversationHistory,
            onChunk: onChunk
        )
    }
}
