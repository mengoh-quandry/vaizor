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
        let newConversation = Conversation()
        conversations.insert(newConversation, at: 0)
        do {
            try dbQueue.write { db in
                try ConversationRecord(newConversation).insert(db)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to create conversation")
        }
        return newConversation
    }

    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        Task {
            await conversationRepository.deleteConversation(id)
        }

        // Ensure at least one conversation exists
        if conversations.isEmpty {
            let newConversation = Conversation()
            conversations.append(newConversation)
            do {
                try dbQueue.write { db in
                    try ConversationRecord(newConversation).insert(db)
                }
            } catch {
                AppLogger.shared.logError(error, context: "Failed to create fallback conversation")
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
        folders.append(folder)
        Task {
            await folderRepository.saveFolder(folder)
            await loadFolders()
        }
    }

    func deleteFolder(_ id: UUID) {
        folders.removeAll { $0.id == id }
        Task {
            await folderRepository.deleteFolder(id)
            await loadFolders()
        }
    }

    private func loadTemplates() async {
        let loaded = await templateRepository.loadTemplates()
        templates = loaded
    }

    func createTemplate(name: String, prompt: String, systemPrompt: String?) {
        let template = ConversationTemplate(name: name, prompt: prompt, systemPrompt: systemPrompt)
        templates.append(template)
        Task {
            await templateRepository.saveTemplate(template)
            await loadTemplates()
        }
    }

    func deleteTemplate(_ id: UUID) {
        templates.removeAll { $0.id == id }
        Task {
            await templateRepository.deleteTemplate(id)
            await loadTemplates()
        }
    }

    func generateTitleAndSummary(
        for conversationId: UUID,
        firstMessage: String,
        firstResponse: String,
        provider: any LLMProviderProtocol
    ) async {
        // Generate title
        let titlePrompt = "Based on this conversation, generate a concise 3-5 word title that captures the main topic. Only return the title, nothing else.\n\nUser: \(firstMessage)\nAssistant: \(firstResponse)"

        var title = "New Chat"
        do {
            let config = LLMConfiguration(
                provider: .ollama,
                model: "llama4:latest",
                temperature: 0.7,
                maxTokens: 50
            )

            let titleAccumulator = TextAccumulator()
            try await provider.streamMessage(
                titlePrompt,
                configuration: config,
                conversationHistory: [],
                onChunk: { chunk in
                    Task {
                        await titleAccumulator.append(chunk)
                    }
                },
                onThinkingStatusUpdate: { _ in }
            )

            let titleText = await titleAccumulator.current()
            title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Error generating title: \(error)")
        }

        // Generate summary
        let summaryPrompt = "Summarize the following conversation in exactly 2 short sentences. Be concise and capture the key points. Only output the summary, nothing else.\n\nUser: \(firstMessage)\nAssistant: \(firstResponse)"

        var summary = ""
        do {
            let config = LLMConfiguration(
                provider: .ollama,
                model: "llama4:latest",
                temperature: 0.7,
                maxTokens: 100
            )

            let summaryAccumulator = TextAccumulator()
            try await provider.streamMessage(
                summaryPrompt,
                configuration: config,
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
            print("Error generating summary: \(error)")
        }

        updateTitle(conversationId, title: title)
        updateSummary(conversationId, summary: summary)
    }
}
