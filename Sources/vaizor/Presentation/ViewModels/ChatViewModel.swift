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

    // Artifact panel state
    @Published var currentArtifact: Artifact? = nil

    // Redaction state - tracks active redaction for response restoration
    @Published var activeRedactionMap: [String: String] = [:]
    @Published var lastRedactedPatterns: [String] = []

    // Security state - tracks injection detection results
    @Published var pendingInjectionWarning: InjectionAnalysisResult? = nil
    @Published var showInjectionWarning: Bool = false

    // AiEDR security state
    @Published var pendingSecurityWarning: ThreatAnalysis? = nil
    @Published var showSecurityWarning: Bool = false
    @Published var lastPromptAnalysis: ThreatAnalysis? = nil
    @Published var lastResponseAnalysis: ThreatAnalysis? = nil

    // Context enhancement state - tracks when context was enhanced for local models
    @Published var contextWasEnhanced: Bool = false
    @Published var contextEnhancementDetails: String? = nil

    // Project context state
    private var projectContext: ProjectContext?
    private var projectId: UUID?

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

    // Observer for context enhancement notifications
    private var contextEnhancedObserver: NSObjectProtocol?

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

        // Listen for context enhancement notifications
        setupContextEnhancementObserver()
    }

    private func setupContextEnhancementObserver() {
        contextEnhancedObserver = NotificationCenter.default.addObserver(
            forName: .contextEnhanced,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let userInfo = notification.userInfo,
               let enhanced = userInfo["enhanced"] as? Bool,
               enhanced {
                Task { @MainActor in
                    self.contextWasEnhanced = true
                    self.contextEnhancementDetails = userInfo["details"] as? String
                }
            }
        }
    }

    nonisolated func cleanup() {
        // Cleanup is called manually before deallocation
        // NotificationCenter automatically removes observers when the observer object is deallocated
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

    /// Set project context for this conversation
    func setProjectContext(_ context: ProjectContext?, projectId: UUID?) {
        self.projectContext = context
        self.projectId = projectId
    }

    /// Build enhanced system prompt with project context
    func buildSystemPromptWithProjectContext(basePrompt: String?) -> String? {
        guard let context = projectContext else {
            return basePrompt
        }

        var components: [String] = []

        // Add base system prompt if provided
        if let base = basePrompt, !base.isEmpty {
            components.append(base)
        }

        // Add project system prompt
        if let projectPrompt = context.systemPrompt, !projectPrompt.isEmpty {
            components.append("\n## Project Context\n\(projectPrompt)")
        }

        // Add custom instructions
        if !context.instructions.isEmpty {
            let instructionsList = context.instructions.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
            components.append("\n## Custom Instructions\n\(instructionsList)")
        }

        // Add active memory entries
        let activeMemories = context.memory.filter { $0.isActive }
        if !activeMemories.isEmpty {
            let memoryList = activeMemories
                .map { "- \($0.key): \($0.value)" }
                .joined(separator: "\n")
            components.append("\n## Project Memory\nRemember the following about this project:\n\(memoryList)")
        }

        // Add file references (not full content, just metadata)
        if !context.files.isEmpty {
            let filesList = context.files
                .map { "- \($0.name) (\($0.type.rawValue))" }
                .joined(separator: "\n")
            components.append("\n## Reference Files\nThe following files are attached to this project:\n\(filesList)")
        }

        if components.isEmpty {
            return basePrompt
        }

        return components.joined(separator: "\n")
    }

    /// Get file contents from project context for injection into conversation
    func getProjectFileContents() -> String? {
        guard let context = projectContext, !context.files.isEmpty else { return nil }

        var contents: [String] = []
        for file in context.files {
            if let content = file.content, !content.isEmpty {
                // Limit file content size to prevent context overflow
                let truncatedContent = content.count > 10000
                    ? String(content.prefix(10000)) + "\n... (truncated)"
                    : content
                contents.append("### File: \(file.name)\n```\n\(truncatedContent)\n```")
            }
        }

        return contents.isEmpty ? nil : contents.joined(separator: "\n\n")
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
        activeRedactionMap = [:]
        lastRedactedPatterns = []
        pendingInjectionWarning = nil
        showInjectionWarning = false
        pendingSecurityWarning = nil
        showSecurityWarning = false
        lastPromptAnalysis = nil
        lastResponseAnalysis = nil
        contextWasEnhanced = false
        contextEnhancementDetails = nil
    }

    /// Confirm sending a message that triggered injection warning
    func confirmSendWithInjectionWarning(_ text: String, configuration: LLMConfiguration, attachments: [MessageAttachment]? = nil) async {
        pendingInjectionWarning = nil
        showInjectionWarning = false
        await sendMessage(text, configuration: configuration, attachments: attachments, bypassInjectionCheck: true)
    }

    /// Cancel sending after injection warning
    func cancelInjectionWarning() {
        pendingInjectionWarning = nil
        showInjectionWarning = false
    }

    /// Confirm sending a message that triggered AiEDR security warning
    func confirmSendWithSecurityWarning(_ text: String, configuration: LLMConfiguration, attachments: [MessageAttachment]? = nil) async {
        pendingSecurityWarning = nil
        showSecurityWarning = false
        await sendMessage(text, configuration: configuration, attachments: attachments, bypassInjectionCheck: true, bypassSecurityCheck: true)
    }

    /// Cancel sending after AiEDR security warning
    func cancelSecurityWarning() {
        pendingSecurityWarning = nil
        showSecurityWarning = false
    }

    func sendMessage(_ text: String, configuration: LLMConfiguration, replaceAtIndex: Int? = nil, attachments: [MessageAttachment]? = nil, mentionReferences: [Mention]? = nil, bypassInjectionCheck: Bool = false, bypassSecurityCheck: Bool = false) async {
        AppLogger.shared.log("Sending message", level: .info)

        // Cancel any existing stream
        stopStreaming()

        // Security: Check for prompt injection attempts (legacy detector)
        let injectionDetector = PromptInjectionDetector.shared
        let injectionResult = injectionDetector.analyze(text)

        if !bypassInjectionCheck && !injectionResult.isClean {
            AppLogger.shared.log("Injection patterns detected: \(injectionResult.detectedPatterns.map { $0.patternName }.joined(separator: ", "))", level: .warning)

            // Block critical attempts
            if injectionDetector.shouldBlock(injectionResult) {
                error = "Message blocked: Potential prompt injection detected. This message contains patterns that could manipulate AI behavior."
                AppLogger.shared.log("Blocked critical injection attempt", level: .error)
                return
            }

            // Warn on high severity - require user confirmation
            if injectionResult.requiresUserConfirmation {
                pendingInjectionWarning = injectionResult
                showInjectionWarning = true
                return
            }
        }

        // AiEDR: Enhanced security analysis with AI intent detection and conversation tracking
        let edrService = AiEDRService.shared
        if edrService.isEnabled && !bypassSecurityCheck {
            // Build conversation context for AI analysis (last 5 messages)
            let conversationContext = messages.suffix(5).map { msg -> String in
                let role = msg.role == .user ? "User" : "Assistant"
                return "[\(role)]: \(msg.content.prefix(500))"
            }

            // Pass conversation ID for threat state tracking across messages
            let promptAnalysis = await edrService.analyzeIncomingPrompt(
                text,
                conversationContext: conversationContext,
                conversationId: conversationId
            )
            lastPromptAnalysis = promptAnalysis

            if !promptAnalysis.isClean {
                AppLogger.shared.log("AiEDR threats detected: \(promptAnalysis.alerts.map { $0.type.rawValue }.joined(separator: ", "))", level: .warning)

                // Block critical threats with high confidence
                if promptAnalysis.requiresBlocking && edrService.autoBlockCritical {
                    error = "Message blocked by AiEDR: Critical security threat detected with high confidence."
                    AppLogger.shared.log("AiEDR blocked critical threat", level: .error)
                    edrService.recordBlockedThreat()

                    // Record blocked attempt to conversation state for escalated scrutiny
                    for alert in promptAnalysis.alerts {
                        edrService.recordAttackAttempt(conversationId: conversationId, alert: alert, wasBlocked: true)
                    }
                    return
                }

                // Prompt user for confirmation on high threats
                if promptAnalysis.requiresUserConfirmation && edrService.promptOnHigh {
                    pendingSecurityWarning = promptAnalysis
                    showSecurityWarning = true
                    return
                }
            }
        }

        // Apply data redaction if enabled
        let redactor = DataRedactor.shared
        let redactionResult = redactor.redact(injectionResult.sanitizedText)
        let textToSend = redactionResult.sanitizedText
        activeRedactionMap = redactionResult.redactionMap
        lastRedactedPatterns = redactionResult.detectedPatterns

        if redactionResult.hasRedactions {
            AppLogger.shared.log("Redacted \(redactionResult.redactionMap.count) sensitive items: \(redactionResult.detectedPatterns.joined(separator: ", "))", level: .info)
        }

        // Convert mention references if provided
        let mentionRefs = mentionReferences?.map { MentionReference(from: $0) }

        // Store original user message (not redacted) for display
        let userMessage = Message(
            conversationId: conversationId,
            role: .user,
            content: text, // Original text for user display
            attachments: attachments,
            mentionReferences: mentionRefs
        )

        // If replacing at a specific index, insert there; otherwise append
        if let replaceIndex = replaceAtIndex, replaceIndex <= messages.count {
            messages.insert(userMessage, at: replaceIndex)
        } else {
            messages.append(userMessage)
        }
        await conversationRepository.saveMessage(userMessage)

        // Handle parallel mode (user message already saved above)
        if isParallelMode && !selectedModels.isEmpty {
            await sendMessageParallel(text: textToSend, configuration: configuration, replaceAtIndex: replaceAtIndex)
            return
        }

        guard let provider = llmProvider else {
            let errorMsg = "No LLM provider configured"
            AppLogger.shared.log(errorMsg, level: .error)
            error = errorMsg
            return
        }

        isStreaming = true
        currentStreamingText = ""
        error = nil
        thinkingStatus = "Analyzing request..."

        // Capture redaction map for use in the streaming task
        let capturedRedactionMap = activeRedactionMap

        streamTask = Task { @MainActor in
            do {
                // Get conversation history (excluding the current message)
                // Also redact the history before sending
                let history = messages.dropLast()
                let trimmedHistory = Array(history.suffix(maxHistoryMessages))

                // Redact conversation history as well
                let redactedHistory = trimmedHistory.map { message -> Message in
                    let historyRedaction = redactor.redact(message.content)
                    return Message(
                        id: message.id,
                        conversationId: message.conversationId,
                        role: message.role,
                        content: historyRedaction.sanitizedText,
                        timestamp: message.timestamp,
                        attachments: message.attachments,
                        toolCallId: message.toolCallId,
                        toolName: message.toolName
                    )
                }

                try await AppLogger.shared.measurePerformanceAsync("sendMessage") {
                    try await provider.streamMessage(
                        textToSend, // Send redacted text to LLM
                        configuration: configuration,
                        conversationHistory: redactedHistory,
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
                        },
                        onArtifactCreated: { [weak self] artifact in
                            // Display artifact in side panel
                            Task { @MainActor [weak self] in
                                self?.currentArtifact = artifact
                            }
                        }
                    )
                }

                // Flush any remaining buffer
                flushStreamingBuffer()

                guard !Task.isCancelled else {
                    currentStreamingText = ""
                    activeRedactionMap = [:]
                    return
                }

                // Restore original values in the response if redaction was applied
                var responseText = currentStreamingText
                if !capturedRedactionMap.isEmpty {
                    responseText = redactor.restore(responseText, using: capturedRedactionMap)
                    AppLogger.shared.log("Restored \(capturedRedactionMap.count) redacted values in response", level: .info)
                }

                // AiEDR: Analyze model response for malicious content
                let edrService = AiEDRService.shared
                if edrService.isEnabled {
                    let responseAnalysis = edrService.analyzeModelResponse(responseText)
                    await MainActor.run {
                        self.lastResponseAnalysis = responseAnalysis
                    }

                    if !responseAnalysis.isClean {
                        AppLogger.shared.log("AiEDR detected issues in response: \(responseAnalysis.alerts.map { $0.type.rawValue }.joined(separator: ", "))", level: .warning)
                    }
                }

                // Parse for markdown artifacts (fallback to tool-based artifacts)
                var finalContent = responseText
                if ArtifactParser.containsArtifacts(responseText) {
                    let (cleanedText, parsedArtifacts) = ArtifactParser.processResponse(responseText)
                    finalContent = cleanedText

                    // Display the first artifact in the side panel
                    if let firstArtifact = parsedArtifacts.first {
                        currentArtifact = firstArtifact
                        // Also show the artifact panel
                        NotificationCenter.default.post(name: .toggleArtifactPanel, object: true)
                        AppLogger.shared.log("Parsed markdown artifact: \(firstArtifact.title)", level: .info)
                    }
                }

                // Save the complete response (with artifacts extracted and values restored)
                let assistantMessage = Message(
                    conversationId: conversationId,
                    role: .assistant,
                    content: finalContent
                )

                // If replacing at a specific index, insert there; otherwise append
                if let replaceIndex = replaceAtIndex, replaceIndex < messages.count {
                    messages.insert(assistantMessage, at: replaceIndex + 1)
                } else {
                    messages.append(assistantMessage)
                }
                await conversationRepository.saveMessage(assistantMessage)

                // Extract memories if in project context
                if let projId = projectId, let userMsg = messages.last(where: { $0.role == .user }) {
                    await extractAndSaveMemories(
                        userMessage: userMsg.content,
                        assistantResponse: finalContent,
                        projectId: projId
                    )
                }

                // Clear replace index and redaction state after use
                targetReplaceIndex = nil
                activeRedactionMap = [:]

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
                activeRedactionMap = [:]
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

    /// Extract potential memories from a conversation exchange and save to project
    private func extractAndSaveMemories(
        userMessage: String,
        assistantResponse: String,
        projectId: UUID
    ) async {
        let extractor = MemoryExtractor.shared

        let memories = await extractor.extractMemories(
            userMessage: userMessage,
            assistantResponse: assistantResponse,
            conversationId: conversationId
        )

        // Filter by confidence and deduplicate
        let filteredMemories = await extractor.filterByConfidence(
            await extractor.deduplicateMemories(memories),
            threshold: 0.7
        )

        guard !filteredMemories.isEmpty else { return }

        // Post notification to add memories to project
        // This is handled by the UI layer to update ProjectManager
        NotificationCenter.default.post(
            name: .memoriesExtracted,
            object: nil,
            userInfo: [
                "projectId": projectId,
                "memories": filteredMemories
            ]
        )

        AppLogger.shared.log(
            "Extracted \(filteredMemories.count) potential memories for project",
            level: .info
        )
    }

    private func sendMessageParallel(text: String, configuration: LLMConfiguration, replaceAtIndex: Int?) async {
        guard let executor = parallelExecutor else {
            error = "Parallel executor not available"
            return
        }

        // Note: text is already redacted when passed to this function
        // activeRedactionMap is already set by the calling function
        // User message was already saved by sendMessage with original (non-redacted) text
        let capturedRedactionMap = activeRedactionMap

        isStreaming = true
        parallelResponses = [:]
        parallelErrors = [:]
        error = nil
        thinkingStatus = "Sending to \(selectedModels.count) models..."

        let redactor = DataRedactor.shared
        let history = messages.dropLast()
        let trimmedHistory = Array(history.suffix(maxHistoryMessages))

        // Redact conversation history for parallel execution
        let redactedHistory = trimmedHistory.map { message -> Message in
            let historyRedaction = redactor.redact(message.content)
            return Message(
                id: message.id,
                conversationId: message.conversationId,
                role: message.role,
                content: historyRedaction.sanitizedText,
                timestamp: message.timestamp,
                attachments: message.attachments,
                toolCallId: message.toolCallId,
                toolName: message.toolName
            )
        }

        let parallelConfig = ParallelExecutionConfig(
            providers: selectedModels,
            baseConfiguration: configuration
        )

        let results = await executor.executeParallel(
            text: text,
            config: parallelConfig,
            conversationHistory: redactedHistory,
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

        // Save all responses as separate assistant messages (with restoration)
        for (provider, modelResponse) in results {
            if let error = modelResponse.error {
                parallelErrors[provider] = error
                continue
            }

            // Restore original values in the response
            var restoredResponse = modelResponse.response
            if !capturedRedactionMap.isEmpty {
                restoredResponse = redactor.restore(restoredResponse, using: capturedRedactionMap)
            }

            let assistantMessage = Message(
                conversationId: conversationId,
                role: .assistant,
                content: restoredResponse,
                toolCallId: nil,
                toolName: "\(provider.displayName)"
            )

            messages.append(assistantMessage)
            await conversationRepository.saveMessage(assistantMessage)
        }

        isStreaming = false
        thinkingStatus = "Thinking..."
        activeRedactionMap = [:]
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
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void,
        onArtifactCreated: (@Sendable (Artifact) -> Void)?
    ) async throws
}

// Default implementation for onArtifactCreated
extension LLMProviderProtocol {
    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void
    ) async throws {
        try await streamMessage(
            text,
            configuration: configuration,
            conversationHistory: conversationHistory,
            onChunk: onChunk,
            onThinkingStatusUpdate: onThinkingStatusUpdate,
            onArtifactCreated: nil
        )
    }
}
