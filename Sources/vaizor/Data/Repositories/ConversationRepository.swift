import Foundation

@MainActor
class ConversationRepository {
    private var messages: [Message] = []
    private let messagesURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let vaizorDir = appSupport.appendingPathComponent("Vaizor")
        try? FileManager.default.createDirectory(at: vaizorDir, withIntermediateDirectories: true)
        messagesURL = vaizorDir.appendingPathComponent("messages.json")

        loadAllMessages()
    }

    private func loadAllMessages() {
        guard FileManager.default.fileExists(atPath: messagesURL.path),
              let data = try? Data(contentsOf: messagesURL),
              let loaded = try? JSONDecoder().decode([Message].self, from: data) else {
            messages = []
            return
        }

        messages = loaded
    }

    private func saveAllMessages() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        try? data.write(to: messagesURL)
    }

    func loadMessages(for conversationId: UUID) async -> [Message] {
        return messages.filter { $0.conversationId == conversationId }
    }

    func saveMessage(_ message: Message) async {
        messages.append(message)
        saveAllMessages()
    }

    func deleteConversation(_ conversationId: UUID) async {
        messages.removeAll { $0.conversationId == conversationId }
        saveAllMessages()
    }
}
