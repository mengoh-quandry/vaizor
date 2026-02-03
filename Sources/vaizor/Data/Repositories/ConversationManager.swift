import Foundation
import SwiftUI
import PostgresNIO

// MARK: - Conversation Manager
// PostgreSQL-backed conversation manager

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
    private let postgres = PostgresManager.shared
    private let pgRepo: PGConversationRepository

    init() {
        self.pgRepo = PGConversationRepository(db: postgres)
        Task {
            await loadConversations()
            await loadFolders()
            await loadTemplates()
        }
    }

    func reloadConversations(includeArchived: Bool = false) async {
        await loadConversations(includeArchived: includeArchived)
    }

    private func loadConversations(includeArchived: Bool = false) async {
        do {
            let loaded = try await pgRepo.fetchAll(includeArchived: includeArchived)

            if loaded.isEmpty && !includeArchived {
                let initial = Conversation()
                try await pgRepo.save(initial)
                conversations = [initial]
                return
            }

            conversations = loaded
        } catch {
            AppLogger.shared.logError(error, context: "Failed to load conversations from PostgreSQL")
        }
    }

    func archiveConversation(_ id: UUID, isArchived: Bool) {
        guard conversations.contains(where: { $0.id == id }) else { return }
        Task {
            do {
                if isArchived {
                    try await pgRepo.archive(id: id)
                }
                await reloadConversations()
            } catch {
                AppLogger.shared.logError(error, context: "Failed to archive conversation")
            }
        }
    }

    func createConversation() -> Conversation {
        return createConversation(title: "New Chat")
    }

    func createConversation(title: String, systemPrompt: String? = nil) -> Conversation {
        let newConversation = Conversation(title: title)

        Task {
            do {
                try await pgRepo.save(newConversation)
                await MainActor.run {
                    conversations.insert(newConversation, at: 0)
                }
            } catch {
                AppLogger.shared.logError(error, context: "Failed to create conversation")
            }
        }

        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            Task { @MainActor in
                AppSettings.shared.systemPromptPrefix = systemPrompt
            }
        }

        return newConversation
    }

    func deleteConversation(_ id: UUID) {
        Task {
            do {
                try await pgRepo.delete(id: id)
                conversations.removeAll { $0.id == id }

                if conversations.isEmpty {
                    let newConversation = Conversation()
                    try await pgRepo.save(newConversation)
                    conversations.append(newConversation)
                }
            } catch {
                AppLogger.shared.logError(error, context: "Failed to delete conversation")
            }
        }
    }

    func updateLastUsed(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].lastUsedAt = Date()
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
            return try await pgRepo.fetchByProject(projectId: projectId)
        } catch {
            AppLogger.shared.logError(error, context: "Failed to load conversations for project \(projectId)")
            return []
        }
    }

    private func updateConversation(_ conversation: Conversation) {
        Task {
            do {
                try await pgRepo.save(conversation)
            } catch {
                AppLogger.shared.logError(error, context: "Failed to update conversation \(conversation.id)")
            }
        }
    }

    // MARK: - Folders

    private func loadFolders() async {
        do {
            let sql = "SELECT * FROM folders ORDER BY name"
            let result = try await postgres.query(sql)
            let rows = try await result.collect()

            folders = try rows.map { row in
                let columns = row.makeRandomAccess()
                return Folder(
                    id: try columns["id"].decode(UUID.self, context: .default),
                    name: try columns["name"].decode(String?.self, context: .default) ?? "",
                    color: try columns["color"].decode(String?.self, context: .default),
                    parentId: try columns["parent_id"].decode(UUID?.self, context: .default),
                    createdAt: try columns["created_at"].decode(Date?.self, context: .default) ?? Date()
                )
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to load folders")
        }
    }

    func createFolder(name: String, color: String?) {
        let folder = Folder(name: name, color: color)
        Task {
            do {
                let colorValue = color.map { "'\($0)'" } ?? "NULL"
                let sql = """
                    INSERT INTO folders (id, name, color, created_at)
                    VALUES (
                        '\(folder.id.uuidString)',
                        '\(name.replacingOccurrences(of: "'", with: "''"))',
                        \(colorValue),
                        NOW()
                    )
                """
                try await postgres.execute(sql)
                await loadFolders()
            } catch {
                AppLogger.shared.logError(error, context: "Failed to create folder")
            }
        }
    }

    func deleteFolder(_ id: UUID) {
        Task {
            do {
                try await postgres.execute("DELETE FROM folders WHERE id = '\(id.uuidString)'")
                await loadFolders()
            } catch {
                AppLogger.shared.logError(error, context: "Failed to delete folder")
            }
        }
    }

    // MARK: - Templates

    private func loadTemplates() async {
        do {
            let sql = "SELECT * FROM conversation_templates ORDER BY name"
            let result = try await postgres.query(sql)
            let rows = try await result.collect()

            templates = try rows.map { row in
                let columns = row.makeRandomAccess()
                return ConversationTemplate(
                    id: try columns["id"].decode(UUID.self, context: .default),
                    name: try columns["name"].decode(String?.self, context: .default) ?? "",
                    prompt: try columns["prompt"].decode(String?.self, context: .default) ?? "",
                    systemPrompt: try columns["system_prompt"].decode(String?.self, context: .default)
                )
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to load templates")
        }
    }

    func createTemplate(name: String, prompt: String, systemPrompt: String?) {
        let template = ConversationTemplate(name: name, prompt: prompt, systemPrompt: systemPrompt)
        Task {
            do {
                let systemPromptValue = systemPrompt.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"
                let sql = """
                    INSERT INTO conversation_templates (id, name, prompt, system_prompt, created_at)
                    VALUES (
                        '\(template.id.uuidString)',
                        '\(name.replacingOccurrences(of: "'", with: "''"))',
                        '\(prompt.replacingOccurrences(of: "'", with: "''"))',
                        \(systemPromptValue),
                        NOW()
                    )
                """
                try await postgres.execute(sql)
                await loadTemplates()
            } catch {
                AppLogger.shared.logError(error, context: "Failed to create template")
            }
        }
    }

    func deleteTemplate(_ id: UUID) {
        Task {
            do {
                try await postgres.execute("DELETE FROM conversation_templates WHERE id = '\(id.uuidString)'")
                await loadTemplates()
            } catch {
                AppLogger.shared.logError(error, context: "Failed to delete template")
            }
        }
    }

    // MARK: - Search

    func searchConversations(query: String) async -> [Conversation] {
        do {
            return try await pgRepo.search(query: query)
        } catch {
            AppLogger.shared.logError(error, context: "Failed to search conversations")
            return []
        }
    }

    // MARK: - Title Generation

    func generateTitleAndSummary(
        for conversationId: UUID,
        firstMessage: String,
        firstResponse: String,
        provider: any LLMProviderProtocol
    ) async {
        let titlePrompt = "Based on this conversation, generate a concise 3-5 word title that captures the main topic. Only return the title, nothing else. No quotes, no punctuation at the end.\n\nUser: \(firstMessage)\nAssistant: \(firstResponse)"

        var title = generateFallbackTitle(from: firstMessage)
        do {
            let titleAccumulator = TextAccumulator()
            try await provider.streamMessage(
                titlePrompt,
                configuration: LLMConfiguration(
                    provider: .ollama,
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

            if cleaned.count >= 3 && cleaned.count <= 60 && !cleaned.lowercased().contains("title") {
                title = cleaned
            }
        } catch {
            AppLogger.shared.log("Error generating title, using fallback: \(error)", level: .warning)
        }

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

    private func generateFallbackTitle(from message: String) -> String {
        let cleaned = message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        let words = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        if words.isEmpty {
            return "New Chat"
        }

        let titleWords = Array(words.prefix(5))
        var title = titleWords.joined(separator: " ")

        if title.count > 40 {
            title = String(title.prefix(37)) + "..."
        }

        return title.prefix(1).uppercased() + title.dropFirst()
    }
}
