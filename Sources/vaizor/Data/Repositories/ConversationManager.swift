import Foundation
import SwiftUI
import GRDB

private actor TextAccumulator {
    private var value = ""

    func append(_ chunk: String) {
        value += chunk
    }

    func current() -> String {
        value
    }
}

@MainActor
class ConversationManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var folders: [Folder] = []
    @Published var templates: [ConversationTemplate] = []

    let conversationRepository = ConversationRepository()
    private let folderRepository = FolderRepository()
    private let templateRepository = TemplateRepository()
    private let dbQueue = DatabaseManager.shared.dbQueue

    init() {
        Task {
            await loadConversations()
            await loadFolders()
            await loadTemplates()
        }
    }

    func reloadConversations(includeArchived: Bool = false) async {
        await loadConversations(includeArchived: includeArchived)
    }

    private func loadConversations(includeArchived: Bool = false, folderId: UUID? = nil) async {
        do {
            let loaded = try await dbQueue.read { db in
                var query = ConversationRecord.order(Column("last_used_at").desc)
                if !includeArchived {
                    query = query.filter(Column("is_archived") == false)
                }
                if let folderId = folderId {
                    query = query.filter(Column("folder_id") == folderId.uuidString)
                }
                return try query.fetchAll(db).map { $0.asModel() }
            }

            if loaded.isEmpty && !includeArchived && folderId == nil {
                let initial = Conversation()
                try await dbQueue.write { db in
                    try ConversationRecord(initial).insert(db)
                }
                conversations = [initial]
                return
            }

            conversations = loaded
        } catch {
            AppLogger.shared.logError(error, context: "Failed to load conversations")
        }
    }
    
    func archiveConversation(_ id: UUID, isArchived: Bool) {
        guard conversations.contains(where: { $0.id == id }) else { return }
        Task {
            await conversationRepository.archiveConversation(id, isArchived: isArchived)
            await reloadConversations()
        }
    }

    func createConversation() -> Conversation {
        return createConversation(title: "New Chat")
    }

    func createConversation(title: String, systemPrompt: String? = nil) -> Conversation {
        let newConversation = Conversation(title: title)

        // Write to database FIRST, then update in-memory state only on success
        do {
            try dbQueue.write { db in
                try ConversationRecord(newConversation).insert(db)
            }
            // Only update in-memory state after successful database write
            conversations.insert(newConversation, at: 0)
        } catch {
            AppLogger.shared.logError(error, context: "Failed to create conversation")
            // Return the conversation anyway so caller has something to work with,
            // but it won't be persisted. The error is logged.
        }

        // If a system prompt is provided, set it in AppSettings
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            Task { @MainActor in
                AppSettings.shared.systemPromptPrefix = systemPrompt
            }
        }

        return newConversation
    }

    func deleteConversation(_ id: UUID) {
        // Delete from database FIRST, then update in-memory state only on success
        Task {
            let success = await conversationRepository.deleteConversation(id)
            if success {
                // Only update in-memory state after successful database delete
                conversations.removeAll { $0.id == id }

                // Ensure at least one conversation exists
                if conversations.isEmpty {
                    let newConversation = Conversation()
                    do {
                        try await dbQueue.write { db in
                            try ConversationRecord(newConversation).insert(db)
                        }
                        // Only add to in-memory after successful write
                        conversations.append(newConversation)
                    } catch {
                        AppLogger.shared.logError(error, context: "Failed to create fallback conversation")
                    }
                }
            }
        }
    }

    func updateLastUsed(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].lastUsedAt = Date()

        // Re-sort by last used
        conversations.sort { $0.lastUsedAt > $1.lastUsedAt }
        updateConversation(conversations[index])
    }

    func updateTitle(_ id: UUID, title: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].title = title
        updateConversation(conversations[index])
    }

    func updateSummary(_ id: UUID, summary: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].summary = summary
        updateConversation(conversations[index])
    }

    func incrementMessageCount(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].messageCount += 1
        updateConversation(conversations[index])
    }
    
    func updateModelSettings(_ id: UUID, provider: LLMProvider?, model: String?) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].selectedProvider = provider
        conversations[index].selectedModel = model
        updateConversation(conversations[index])
    }
    
    func updateFolder(_ id: UUID, folderId: UUID?) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].folderId = folderId
        updateConversation(conversations[index])
    }
    
    func addTag(_ id: UUID, tag: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        if !conversations[index].tags.contains(tag) {
            conversations[index].tags.append(tag)
            updateConversation(conversations[index])
        }
    }
    
    func removeTag(_ id: UUID, tag: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].tags.removeAll { $0 == tag }
        updateConversation(conversations[index])
    }
    
    func toggleFavorite(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].isFavorite.toggle()
        updateConversation(conversations[index])
    }

    func updateProjectId(_ id: UUID, projectId: UUID?) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].projectId = projectId
        updateConversation(conversations[index])
    }

    func getConversationsForProject(_ projectId: UUID) -> [Conversation] {
        return conversations.filter { $0.projectId == projectId }
    }

    func loadConversationsForProject(_ projectId: UUID) async -> [Conversation] {
        do {
            return try await dbQueue.read { db in
                try ConversationRecord
                    .filter(Column("project_id") == projectId.uuidString)
                    .order(Column("last_used_at").desc)
                    .fetchAll(db)
                    .map { $0.asModel() }
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to load conversations for project \(projectId)")
            return []
        }
    }

    private func updateConversation(_ conversation: Conversation) {
        do {
            try dbQueue.write { db in
                try ConversationRecord(conversation).update(db)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to update conversation \(conversation.id)")
        }
    }

    private func loadFolders() async {
        let loaded = await folderRepository.loadFolders()
        folders = loaded
    }

    func createFolder(name: String, color: String?) {
        let folder = Folder(name: name, color: color)
        Task {
            let success = await folderRepository.saveFolder(folder)
            if success {
                // Only update in-memory state after successful database write
                folders.append(folder)
            }
            await loadFolders()
        }
    }

    func deleteFolder(_ id: UUID) {
        Task {
            let success = await folderRepository.deleteFolder(id)
            if success {
                // Only update in-memory state after successful database delete
                folders.removeAll { $0.id == id }
            }
            await loadFolders()
        }
    }

    private func loadTemplates() async {
        let loaded = await templateRepository.loadTemplates()
        templates = loaded
    }

    func createTemplate(name: String, prompt: String, systemPrompt: String?) {
        let template = ConversationTemplate(name: name, prompt: prompt, systemPrompt: systemPrompt)
        Task {
            let success = await templateRepository.saveTemplate(template)
            if success {
                // Only update in-memory state after successful database write
                templates.append(template)
            }
            await loadTemplates()
        }
    }

    func deleteTemplate(_ id: UUID) {
        Task {
            let success = await templateRepository.deleteTemplate(id)
            if success {
                // Only update in-memory state after successful database delete
                templates.removeAll { $0.id == id }
            }
            await loadTemplates()
        }
    }

    func generateTitleAndSummary(
        for conversationId: UUID,
        firstMessage: String,
        firstResponse: String,
        provider: any LLMProviderProtocol
    ) async {
        // Generate title using the provided provider
        let titlePrompt = "Based on this conversation, generate a concise 3-5 word title that captures the main topic. Only return the title, nothing else. No quotes, no punctuation at the end.\n\nUser: \(firstMessage)\nAssistant: \(firstResponse)"

        var title = generateFallbackTitle(from: firstMessage)
        do {
            let titleAccumulator = TextAccumulator()
            try await provider.streamMessage(
                titlePrompt,
                configuration: LLMConfiguration(
                    provider: .ollama, // Will be overridden by provider
                    model: "",
                    temperature: 0.3,
                    maxTokens: 30
                ),
                conversationHistory: [],
                onChunk: { chunk in
                    Task {
                        await titleAccumulator.append(chunk)
                    }
                },
                onThinkingStatusUpdate: { _ in }
            )

            let titleText = await titleAccumulator.current()
            let cleaned = titleText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                .replacingOccurrences(of: "\n", with: " ")

            // Only use generated title if it's reasonable
            if cleaned.count >= 3 && cleaned.count <= 60 && !cleaned.lowercased().contains("title") {
                title = cleaned
            }
        } catch {
            AppLogger.shared.log("Error generating title, using fallback: \(error)", level: .warning)
        }

        // Generate summary
        let summaryPrompt = "Summarize the following conversation in exactly 1 short sentence. Be concise and capture the key point. Only output the summary, nothing else.\n\nUser: \(firstMessage)\nAssistant: \(firstResponse)"

        var summary = ""
        do {
            let summaryAccumulator = TextAccumulator()
            try await provider.streamMessage(
                summaryPrompt,
                configuration: LLMConfiguration(
                    provider: .ollama,
                    model: "",
                    temperature: 0.3,
                    maxTokens: 80
                ),
                conversationHistory: [],
                onChunk: { chunk in
                    Task {
                        await summaryAccumulator.append(chunk)
                    }
                },
                onThinkingStatusUpdate: { _ in }
            )

            let summaryText = await summaryAccumulator.current()
            summary = summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            AppLogger.shared.log("Error generating summary: \(error)", level: .warning)
        }

        updateTitle(conversationId, title: title)
        updateSummary(conversationId, summary: summary)
    }

    /// Generate a fallback title from the first message if LLM fails
    private func generateFallbackTitle(from message: String) -> String {
        let cleaned = message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        // Extract first meaningful words
        let words = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        if words.isEmpty {
            return "New Chat"
        }

        // Take first 5 words max
        let titleWords = Array(words.prefix(5))
        var title = titleWords.joined(separator: " ")

        // Truncate if too long
        if title.count > 40 {
            title = String(title.prefix(37)) + "..."
        }

        // Capitalize first letter
        return title.prefix(1).uppercased() + title.dropFirst()
    }
}
