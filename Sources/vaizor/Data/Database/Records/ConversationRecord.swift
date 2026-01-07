import GRDB

struct ConversationRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "conversations"

    var id: String
    var title: String
    var summary: String
    var createdAt: Double
    var lastUsedAt: Double
    var messageCount: Int
    var isArchived: Bool
    var selectedProvider: String?
    var selectedModel: String?
    var folderId: String?
    var tags: String? // JSON array
    var isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case createdAt = "created_at"
        case lastUsedAt = "last_used_at"
        case messageCount = "message_count"
        case isArchived = "is_archived"
        case selectedProvider = "selected_provider"
        case selectedModel = "selected_model"
        case folderId = "folder_id"
        case tags
        case isFavorite = "is_favorite"
    }
}
