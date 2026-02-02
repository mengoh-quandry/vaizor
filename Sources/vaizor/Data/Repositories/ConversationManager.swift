import Foundation
import SwiftUI

@MainActor
class ConversationManager: ObservableObject {
    @Published var conversations: [Conversation] = []

    let conversationRepository = ConversationRepository()
    private let configURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let vaizorDir = appSupport.appendingPathComponent("Vaizor")
        try? FileManager.default.createDirectory(at: vaizorDir, withIntermediateDirectories: true)
        configURL = vaizorDir.appendingPathComponent("conversations.json")

        loadConversations()
    }

    private func loadConversations() {
        guard FileManager.default.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL),
              let loaded = try? JSONDecoder().decode([Conversation].self, from: data) else {
            // Create initial conversation if none exist
            let initial = Conversation()
            conversations = [initial]
            saveConversations()
            return
        }

        conversations = loaded.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    private func saveConversations() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: configURL)
    }

    func createConversation() -> Conversation {
        let newConversation = Conversation()
        conversations.insert(newConversation, at: 0)
        saveConversations()
        return newConversation
    }

    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        Task {
            await conversationRepository.deleteConversation(id)
        }
        saveConversations()

        // Ensure at least one conversation exists
        if conversations.isEmpty {
            let newConversation = Conversation()
            conversations.append(newConversation)
            saveConversations()
        }
    }

    func updateLastUsed(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].lastUsedAt = Date()

        // Re-sort by last used
        conversations.sort { $0.lastUsedAt > $1.lastUsedAt }
        saveConversations()
    }

    func updateTitle(_ id: UUID, title: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].title = title
        saveConversations()
    }

    func updateSummary(_ id: UUID, summary: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].summary = summary
        saveConversations()
    }

    func incrementMessageCount(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].messageCount += 1
        saveConversations()
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

            var titleText = ""
            try await provider.streamMessage(
                titlePrompt,
                configuration: config,
                conversationHistory: []
            ) { chunk in
                titleText += chunk
            }

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

            var summaryText = ""
            try await provider.streamMessage(
                summaryPrompt,
                configuration: config,
                conversationHistory: []
            ) { chunk in
                summaryText += chunk
            }

            summary = summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Error generating summary: \(error)")
        }

        updateTitle(conversationId, title: title)
        updateSummary(conversationId, summary: summary)
    }
}
