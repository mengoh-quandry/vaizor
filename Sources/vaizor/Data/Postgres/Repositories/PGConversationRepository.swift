import Foundation
import PostgresNIO

// MARK: - PostgreSQL Conversation Repository

actor PGConversationRepository {
    private let db: PostgresManager

    init(db: PostgresManager = .shared) {
        self.db = db
    }

    // MARK: - Conversations

    func fetchAll(includeArchived: Bool = false) async throws -> [Conversation] {
        let sql = includeArchived
            ? "SELECT * FROM conversations ORDER BY last_used_at DESC"
            : "SELECT * FROM conversations WHERE is_archived = false ORDER BY last_used_at DESC"

        let result = try await db.query(sql)
        let rows = try await result.collect()
        return try rows.map { try ConversationEntity.from(row: $0).toDomain() }
    }

    func fetch(id: UUID) async throws -> Conversation? {
        let sql = "SELECT * FROM conversations WHERE id = $1"
        let result = try await db.query(sql, [id.postgresData])
        let rows = try await result.collect()
        return try rows.first.map { try ConversationEntity.from(row: $0).toDomain() }
    }

    func fetchByProject(projectId: UUID) async throws -> [Conversation] {
        let sql = "SELECT * FROM conversations WHERE project_id = $1 ORDER BY last_used_at DESC"
        let result = try await db.query(sql, [projectId.postgresData])
        let rows = try await result.collect()
        return try rows.map { try ConversationEntity.from(row: $0).toDomain() }
    }

    func fetchByFolder(folderId: UUID) async throws -> [Conversation] {
        let sql = "SELECT * FROM conversations WHERE folder_id = $1 ORDER BY last_used_at DESC"
        let result = try await db.query(sql, [folderId.postgresData])
        let rows = try await result.collect()
        return try rows.map { try ConversationEntity.from(row: $0).toDomain() }
    }

    func search(query: String, limit: Int = 50) async throws -> [Conversation] {
        let sql = """
            SELECT DISTINCT c.* FROM conversations c
            JOIN messages m ON m.conversation_id = c.id
            WHERE m.content_tsv @@ plainto_tsquery('english', $1)
            ORDER BY c.last_used_at DESC
            LIMIT $2
        """
        let result = try await db.query(sql, [query.postgresData, limit.postgresData])
        let rows = try await result.collect()
        return try rows.map { try ConversationEntity.from(row: $0).toDomain() }
    }

    func save(_ conversation: Conversation) async throws {
        let entity = ConversationEntity(from: conversation)
        let tagsArray = entity.tags.isEmpty ? "NULL" : "ARRAY[\(entity.tags.map { "'\($0)'" }.joined(separator: ","))]::TEXT[]"

        // Build SQL with optional handling inline
        let folderIdValue = entity.folderId.map { "'\($0.uuidString)'" } ?? "NULL"
        let projectIdValue = entity.projectId.map { "'\($0.uuidString)'" } ?? "NULL"
        let providerValue = entity.provider.map { "'\($0)'" } ?? "NULL"
        let modelValue = entity.model.map { "'\($0)'" } ?? "NULL"
        let summaryValue = entity.summary.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"

        let sql = """
            INSERT INTO conversations (id, title, summary, folder_id, project_id, provider, model, tags, is_favorite, is_archived, message_count, created_at, last_used_at)
            VALUES (
                '\(entity.id.uuidString)',
                '\(entity.title.replacingOccurrences(of: "'", with: "''"))',
                \(summaryValue),
                \(folderIdValue)::UUID,
                \(projectIdValue)::UUID,
                \(providerValue),
                \(modelValue),
                \(tagsArray),
                \(entity.isFavorite),
                \(entity.isArchived),
                \(entity.messageCount),
                '\(ISO8601DateFormatter().string(from: entity.createdAt))',
                '\(ISO8601DateFormatter().string(from: entity.lastUsedAt))'
            )
            ON CONFLICT (id) DO UPDATE SET
                title = EXCLUDED.title,
                summary = EXCLUDED.summary,
                folder_id = EXCLUDED.folder_id,
                project_id = EXCLUDED.project_id,
                provider = EXCLUDED.provider,
                model = EXCLUDED.model,
                tags = EXCLUDED.tags,
                is_favorite = EXCLUDED.is_favorite,
                is_archived = EXCLUDED.is_archived,
                message_count = EXCLUDED.message_count,
                last_used_at = EXCLUDED.last_used_at
        """

        try await db.execute(sql)
    }

    func delete(id: UUID) async throws {
        try await db.execute("DELETE FROM conversations WHERE id = $1", [id.postgresData])
    }

    func archive(id: UUID) async throws {
        try await db.execute(
            "UPDATE conversations SET is_archived = true WHERE id = $1",
            [id.postgresData]
        )
    }

    func updateMessageCount(conversationId: UUID) async throws {
        let sql = """
            UPDATE conversations
            SET message_count = (SELECT COUNT(*) FROM messages WHERE conversation_id = $1),
                last_used_at = NOW()
            WHERE id = $1
        """
        try await db.execute(sql, [conversationId.postgresData])
    }

    // MARK: - Messages

    func fetchMessages(conversationId: UUID, limit: Int = 100, offset: Int = 0) async throws -> [Message] {
        let sql = """
            SELECT * FROM messages
            WHERE conversation_id = $1
            ORDER BY created_at ASC
            LIMIT $2 OFFSET $3
        """
        let result = try await db.query(sql, [
            conversationId.postgresData,
            limit.postgresData,
            offset.postgresData
        ])
        let rows = try await result.collect()

        var messages: [Message] = []

        for row in rows {
            var message = try MessageEntity.from(row: row).toDomain()
            // Load attachments for each message and create new message with them
            let attachments = try await fetchAttachments(messageId: message.id)
            if !attachments.isEmpty {
                message = Message(
                    id: message.id,
                    conversationId: message.conversationId,
                    role: message.role,
                    content: message.content,
                    timestamp: message.timestamp,
                    attachments: attachments,
                    toolCallId: message.toolCallId,
                    toolName: message.toolName
                )
            }
            messages.append(message)
        }

        return messages
    }

    func saveMessage(_ message: Message) async throws {
        let entity = MessageEntity(from: message)
        let toolCallIdValue = entity.toolCallId.map { "'\($0)'" } ?? "NULL"
        let toolNameValue = entity.toolName.map { "'\($0)'" } ?? "NULL"

        let sql = """
            INSERT INTO messages (id, conversation_id, role, content, tool_call_id, tool_name, created_at)
            VALUES (
                '\(entity.id.uuidString)',
                '\(entity.conversationId.uuidString)',
                '\(entity.role)',
                '\(entity.content.replacingOccurrences(of: "'", with: "''"))',
                \(toolCallIdValue),
                \(toolNameValue),
                '\(ISO8601DateFormatter().string(from: entity.createdAt))'
            )
            ON CONFLICT (id) DO UPDATE SET
                content = EXCLUDED.content,
                tool_call_id = EXCLUDED.tool_call_id,
                tool_name = EXCLUDED.tool_name
        """

        try await db.execute(sql)

        // Save attachments
        if let attachments = message.attachments {
            for attachment in attachments {
                try await saveAttachment(attachment, messageId: message.id)
            }
        }

        // Update conversation message count
        try await updateMessageCount(conversationId: message.conversationId)
    }

    func deleteMessage(id: UUID) async throws {
        // Get conversation ID first for count update
        let result = try await db.query(
            "SELECT conversation_id FROM messages WHERE id = $1",
            [id.postgresData]
        )
        let rows = try await result.collect()
        let conversationId: UUID? = try rows.first.flatMap {
            try $0.makeRandomAccess()["conversation_id"].decode(UUID?.self, context: .default)
        }

        try await db.execute("DELETE FROM messages WHERE id = $1", [id.postgresData])

        if let convId = conversationId {
            try await updateMessageCount(conversationId: convId)
        }
    }

    // MARK: - Attachments

    func fetchAttachments(messageId: UUID) async throws -> [MessageAttachment] {
        let sql = "SELECT * FROM attachments WHERE message_id = $1"
        let result = try await db.query(sql, [messageId.postgresData])
        let rows = try await result.collect()
        return try rows.map { try AttachmentEntity.from(row: $0).toDomain() }
    }

    func saveAttachment(_ attachment: MessageAttachment, messageId: UUID) async throws {
        let entity = AttachmentEntity(from: attachment, messageId: messageId)
        let filenameValue = entity.filename.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"
        let mimeTypeValue = entity.mimeType.map { "'\($0)'" } ?? "NULL"
        let isImage = attachment.isImage

        // Encode data as hex for PostgreSQL bytea
        let dataHex = entity.data.map { String(format: "%02x", $0) }.joined()

        let sql = """
            INSERT INTO attachments (id, message_id, filename, mime_type, byte_count, is_image, data, created_at)
            VALUES (
                '\(entity.id.uuidString)',
                '\(entity.messageId.uuidString)',
                \(filenameValue),
                \(mimeTypeValue),
                \(entity.byteCount),
                \(isImage),
                '\\x\(dataHex)'::bytea,
                '\(ISO8601DateFormatter().string(from: entity.createdAt))'
            )
            ON CONFLICT (id) DO NOTHING
        """

        try await db.execute(sql)
    }

    // MARK: - Tool Runs

    func saveToolRun(
        conversationId: UUID,
        messageId: UUID?,
        toolName: String,
        serverId: String?,
        serverName: String?,
        inputJson: String?,
        outputJson: String?,
        isError: Bool,
        durationMs: Int?
    ) async throws {
        let messageIdValue = messageId.map { "'\($0.uuidString)'" } ?? "NULL"
        let serverIdValue = serverId.map { "'\($0)'" } ?? "NULL"
        let serverNameValue = serverName.map { "'\($0)'" } ?? "NULL"
        let inputJsonValue = inputJson.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"
        let outputJsonValue = outputJson.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL"
        let durationMsValue = durationMs.map { "\($0)" } ?? "NULL"

        let sql = """
            INSERT INTO tool_runs (id, conversation_id, message_id, tool_name, server_id, server_name, input_json, output_json, is_error, duration_ms, created_at)
            VALUES (
                '\(UUID().uuidString)',
                '\(conversationId.uuidString)',
                \(messageIdValue)::UUID,
                '\(toolName)',
                \(serverIdValue),
                \(serverNameValue),
                \(inputJsonValue),
                \(outputJsonValue),
                \(isError),
                \(durationMsValue),
                NOW()
            )
        """

        try await db.execute(sql)
    }

    func fetchToolRuns(conversationId: UUID) async throws -> [ToolRunEntity] {
        let sql = "SELECT * FROM tool_runs WHERE conversation_id = $1 ORDER BY created_at DESC"
        let result = try await db.query(sql, [conversationId.postgresData])
        let rows = try await result.collect()
        return try rows.map { try ToolRunEntity.from(row: $0) }
    }
}
