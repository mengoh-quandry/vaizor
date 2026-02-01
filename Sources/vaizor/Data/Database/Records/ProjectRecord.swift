import Foundation
import GRDB

struct ProjectRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "projects"

    var id: String
    var name: String
    var conversations: String?     // JSON array of UUID strings
    var context: String?           // JSON-encoded ProjectContext
    var createdAt: Double
    var updatedAt: Double
    var isArchived: Bool
    var iconName: String?
    var color: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case conversations
        case context
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isArchived = "is_archived"
        case iconName = "icon_name"
        case color
    }
}

extension ProjectRecord {
    init(_ project: Project) {
        id = project.id.uuidString
        name = project.name

        // Encode conversations array as JSON
        if project.conversations.isEmpty {
            conversations = nil
        } else if let data = try? JSONEncoder().encode(project.conversations.map { $0.uuidString }) {
            conversations = String(data: data, encoding: .utf8)
        } else {
            conversations = nil
        }

        // Encode context as JSON
        if let data = try? JSONEncoder().encode(project.context) {
            context = String(data: data, encoding: .utf8)
        } else {
            context = nil
        }

        createdAt = project.createdAt.timeIntervalSince1970
        updatedAt = project.updatedAt.timeIntervalSince1970
        isArchived = project.isArchived
        iconName = project.iconName
        color = project.color
    }

    func asModel() -> Project {
        // Decode conversations array
        var decodedConversations: [UUID] = []
        if let conversationsData = conversations?.data(using: .utf8),
           let conversationStrings = try? JSONDecoder().decode([String].self, from: conversationsData) {
            decodedConversations = conversationStrings.compactMap { UUID(uuidString: $0) }
        }

        // Decode context
        var decodedContext = ProjectContext()
        if let contextData = context?.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(ProjectContext.self, from: contextData) {
            decodedContext = decoded
        }

        return Project(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            conversations: decodedConversations,
            context: decodedContext,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            isArchived: isArchived,
            iconName: iconName,
            color: color
        )
    }
}
