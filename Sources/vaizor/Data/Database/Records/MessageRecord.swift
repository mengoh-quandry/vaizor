import GRDB

struct MessageRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "messages"

    var id: String
    var conversationId: String
    var role: String
    var content: String
    var createdAt: Double
    var toolCallId: String?
    var toolName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role
        case content
        case createdAt = "created_at"
        case toolCallId = "tool_call_id"
        case toolName = "tool_name"
    }
}
