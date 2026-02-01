import Foundation
import GRDB

struct WhiteboardRecord: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var conversationId: String?
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var thumbnail: Data?
    var tags: String?  // JSON encoded array
    var isShared: Bool
    
    static let databaseTableName = "whiteboards"
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let conversationId = Column(CodingKeys.conversationId)
        static let title = Column(CodingKeys.title)
        static let content = Column(CodingKeys.content)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
        static let thumbnail = Column(CodingKeys.thumbnail)
        static let tags = Column(CodingKeys.tags)
        static let isShared = Column(CodingKeys.isShared)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case title
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case thumbnail
        case tags
        case isShared = "is_shared"
    }
    
    init(_ whiteboard: Whiteboard) {
        self.id = whiteboard.id.uuidString
        self.conversationId = whiteboard.conversationId?.uuidString
        self.title = whiteboard.title
        self.content = whiteboard.content
        self.createdAt = whiteboard.createdAt
        self.updatedAt = whiteboard.updatedAt
        self.thumbnail = whiteboard.thumbnail
        self.tags = whiteboard.tags.isEmpty ? nil : (try? JSONEncoder().encode(whiteboard.tags)).flatMap { String(data: $0, encoding: .utf8) }
        self.isShared = whiteboard.isShared
    }
    
    func asModel() -> Whiteboard {
        let tagsArray: [String] = {
            guard let tagsString = self.tags,
                  let data = tagsString.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return decoded
        }()
        
        return Whiteboard(
            id: UUID(uuidString: id) ?? UUID(),
            conversationId: conversationId.flatMap { UUID(uuidString: $0) },
            title: title,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            thumbnail: thumbnail,
            tags: tagsArray,
            isShared: isShared
        )
    }
}

// MARK: - Associations

extension WhiteboardRecord {
    /// Association to conversation
    static let conversation = belongsTo(ConversationRecord.self)
}
