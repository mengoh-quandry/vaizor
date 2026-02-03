import Foundation
import PostgresNIO

// MARK: - Conversation Entity

struct ConversationEntity: Sendable {
    let id: UUID
    var title: String
    var summary: String?
    var folderId: UUID?
    var projectId: UUID?
    var provider: String?
    var model: String?
    var tags: [String]
    var isFavorite: Bool
    var isArchived: Bool
    var messageCount: Int
    var createdAt: Date
    var lastUsedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        summary: String? = nil,
        folderId: UUID? = nil,
        projectId: UUID? = nil,
        provider: String? = nil,
        model: String? = nil,
        tags: [String] = [],
        isFavorite: Bool = false,
        isArchived: Bool = false,
        messageCount: Int = 0,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.folderId = folderId
        self.projectId = projectId
        self.provider = provider
        self.model = model
        self.tags = tags
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.messageCount = messageCount
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    // Convert from domain model
    init(from conversation: Conversation) {
        self.id = conversation.id
        self.title = conversation.title
        self.summary = conversation.summary
        self.folderId = conversation.folderId
        self.projectId = conversation.projectId
        self.provider = conversation.selectedProvider?.rawValue
        self.model = conversation.selectedModel
        self.tags = conversation.tags
        self.isFavorite = conversation.isFavorite
        self.isArchived = conversation.isArchived
        self.messageCount = conversation.messageCount
        self.createdAt = conversation.createdAt
        self.lastUsedAt = conversation.lastUsedAt
    }

    // Convert to domain model
    func toDomain() -> Conversation {
        Conversation(
            id: id,
            title: title,
            summary: summary ?? "",
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            messageCount: messageCount,
            isArchived: isArchived,
            selectedProvider: provider.flatMap { LLMProvider(rawValue: $0) },
            selectedModel: model,
            folderId: folderId,
            projectId: projectId,
            tags: tags,
            isFavorite: isFavorite
        )
    }

    // Parse from PostgreSQL row
    static func from(row: PostgresRow) throws -> ConversationEntity {
        let columns = row.makeRandomAccess()

        let id = try columns["id"].decode(UUID.self, context: .default)
        let title = try columns["title"].decode(String?.self, context: .default) ?? "New Conversation"
        let summary = try columns["summary"].decode(String?.self, context: .default)
        let folderId = try columns["folder_id"].decode(UUID?.self, context: .default)
        let projectId = try columns["project_id"].decode(UUID?.self, context: .default)
        let provider = try columns["provider"].decode(String?.self, context: .default)
        let model = try columns["model"].decode(String?.self, context: .default)
        let tagsArray = try columns["tags"].decode([String]?.self, context: .default)
        let isFavorite = try columns["is_favorite"].decode(Bool?.self, context: .default) ?? false
        let isArchived = try columns["is_archived"].decode(Bool?.self, context: .default) ?? false
        let messageCount = try columns["message_count"].decode(Int?.self, context: .default) ?? 0
        let createdAt = try columns["created_at"].decode(Date?.self, context: .default) ?? Date()
        let lastUsedAt = try columns["last_used_at"].decode(Date?.self, context: .default) ?? Date()

        return ConversationEntity(
            id: id,
            title: title,
            summary: summary,
            folderId: folderId,
            projectId: projectId,
            provider: provider,
            model: model,
            tags: tagsArray ?? [],
            isFavorite: isFavorite,
            isArchived: isArchived,
            messageCount: messageCount,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt
        )
    }
}

// MARK: - Message Entity

struct MessageEntity: Sendable {
    let id: UUID
    let conversationId: UUID
    let role: String
    var content: String
    var toolCallId: String?
    var toolName: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: String,
        content: String,
        toolCallId: String? = nil,
        toolName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.createdAt = createdAt
    }

    init(from message: Message) {
        self.id = message.id
        self.conversationId = message.conversationId
        self.role = message.role.rawValue
        self.content = message.content
        self.toolCallId = message.toolCallId
        self.toolName = message.toolName
        self.createdAt = message.timestamp
    }

    func toDomain() -> Message {
        Message(
            id: id,
            conversationId: conversationId,
            role: MessageRole(rawValue: role) ?? .user,
            content: content,
            timestamp: createdAt,
            attachments: nil, // Loaded separately
            toolCallId: toolCallId,
            toolName: toolName
        )
    }

    static func from(row: PostgresRow) throws -> MessageEntity {
        let columns = row.makeRandomAccess()

        let id = try columns["id"].decode(UUID.self, context: .default)
        let conversationId = try columns["conversation_id"].decode(UUID.self, context: .default)

        return MessageEntity(
            id: id,
            conversationId: conversationId,
            role: try columns["role"].decode(String?.self, context: .default) ?? "user",
            content: try columns["content"].decode(String?.self, context: .default) ?? "",
            toolCallId: try columns["tool_call_id"].decode(String?.self, context: .default),
            toolName: try columns["tool_name"].decode(String?.self, context: .default),
            createdAt: try columns["created_at"].decode(Date?.self, context: .default) ?? Date()
        )
    }
}

// MARK: - Attachment Entity

struct AttachmentEntity: Sendable {
    let id: UUID
    let messageId: UUID
    var filename: String?
    var mimeType: String?
    var byteCount: Int
    var data: Data
    let createdAt: Date

    init(
        id: UUID = UUID(),
        messageId: UUID,
        filename: String? = nil,
        mimeType: String? = nil,
        byteCount: Int,
        data: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.messageId = messageId
        self.filename = filename
        self.mimeType = mimeType
        self.byteCount = byteCount
        self.data = data
        self.createdAt = createdAt
    }

    init(from attachment: MessageAttachment, messageId: UUID) {
        self.id = attachment.id
        self.messageId = messageId
        self.filename = attachment.filename
        self.mimeType = attachment.mimeType
        self.byteCount = attachment.data.count
        self.data = attachment.data
        self.createdAt = Date()
    }

    func toDomain() -> MessageAttachment {
        MessageAttachment(
            id: id,
            data: data,
            mimeType: mimeType,
            filename: filename
        )
    }

    static func from(row: PostgresRow) throws -> AttachmentEntity {
        let columns = row.makeRandomAccess()

        let id = try columns["id"].decode(UUID.self, context: .default)
        let messageId = try columns["message_id"].decode(UUID.self, context: .default)
        let dataBytes = try columns["data"].decode([UInt8]?.self, context: .default) ?? []

        return AttachmentEntity(
            id: id,
            messageId: messageId,
            filename: try columns["filename"].decode(String?.self, context: .default),
            mimeType: try columns["mime_type"].decode(String?.self, context: .default),
            byteCount: try columns["byte_count"].decode(Int?.self, context: .default) ?? 0,
            data: Data(dataBytes),
            createdAt: try columns["created_at"].decode(Date?.self, context: .default) ?? Date()
        )
    }
}

// MARK: - Tool Run Entity

struct ToolRunEntity: Sendable {
    let id: UUID
    let conversationId: UUID
    var messageId: UUID?
    var toolName: String
    var serverId: String?
    var serverName: String?
    var inputJson: String?
    var outputJson: String?
    var isError: Bool
    var durationMs: Int?
    let createdAt: Date

    static func from(row: PostgresRow) throws -> ToolRunEntity {
        let columns = row.makeRandomAccess()

        let id = try columns["id"].decode(UUID.self, context: .default)
        let conversationId = try columns["conversation_id"].decode(UUID.self, context: .default)

        return ToolRunEntity(
            id: id,
            conversationId: conversationId,
            messageId: try columns["message_id"].decode(UUID?.self, context: .default),
            toolName: try columns["tool_name"].decode(String?.self, context: .default) ?? "",
            serverId: try columns["server_id"].decode(String?.self, context: .default),
            serverName: try columns["server_name"].decode(String?.self, context: .default),
            inputJson: try columns["input_json"].decode(String?.self, context: .default),
            outputJson: try columns["output_json"].decode(String?.self, context: .default),
            isError: try columns["is_error"].decode(Bool?.self, context: .default) ?? false,
            durationMs: try columns["duration_ms"].decode(Int?.self, context: .default),
            createdAt: try columns["created_at"].decode(Date?.self, context: .default) ?? Date()
        )
    }
}
