import Foundation

struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var summary: String
    let createdAt: Date
    var lastUsedAt: Date
    var messageCount: Int

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        summary: String = "",
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        messageCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.messageCount = messageCount
    }
}
