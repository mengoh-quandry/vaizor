import Foundation

struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var summary: String
    let createdAt: Date
    var lastUsedAt: Date
    var messageCount: Int
    var isArchived: Bool
    var selectedProvider: LLMProvider?
    var selectedModel: String?
    var folderId: UUID?
    var tags: [String]
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        summary: String = "",
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        messageCount: Int = 0,
        isArchived: Bool = false,
        selectedProvider: LLMProvider? = nil,
        selectedModel: String? = nil,
        folderId: UUID? = nil,
        tags: [String] = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.messageCount = messageCount
        self.isArchived = isArchived
        self.selectedProvider = selectedProvider
        self.selectedModel = selectedModel
        self.folderId = folderId
        self.tags = tags
        self.isFavorite = isFavorite
    }
}
