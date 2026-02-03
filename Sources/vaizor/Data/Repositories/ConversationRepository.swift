import Foundation
import PostgresNIO

// MARK: - Conversation Repository
// PostgreSQL-backed repository for conversation and message operations

actor ConversationRepository {
    private let postgres: PostgresManager
    private let pgRepo: PGConversationRepository

    init(postgres: PostgresManager = .shared) {
        self.postgres = postgres
        self.pgRepo = PGConversationRepository(db: postgres)
    }

    func loadMessages(for conversationId: UUID) async -> [Message] {
        let result = await loadMessages(for: conversationId, limit: 100)
        return result.messages
    }

    /// Load messages with keyset pagination
    func loadMessages(
        for conversationId: UUID,
        after: (createdAt: Date, id: UUID)? = nil,
        limit: Int = 100
    ) async -> (messages: [Message], hasMore: Bool, lastCursor: (Date, UUID)?) {
        do {
            let offset: Int
            if let cursor = after {
                // For pagination, we need to calculate offset based on cursor
                // For now, use offset-based pagination with PostgreSQL
                let countSQL = """
                    SELECT COUNT(*) as cnt FROM messages
                    WHERE conversation_id = '\(conversationId.uuidString)'
                    AND (created_at < '\(ISO8601DateFormatter().string(from: cursor.createdAt))'
                         OR (created_at = '\(ISO8601DateFormatter().string(from: cursor.createdAt))' AND id < '\(cursor.id.uuidString)'))
                """
                let countResult = try await postgres.query(countSQL)
                let countRows = try await countResult.collect()
                offset = try countRows.first.flatMap {
                    try $0.makeRandomAccess()["cnt"].decode(Int?.self, context: .default)
                } ?? 0
            } else {
                offset = 0
            }

            // Fetch messages with pagination
            let sql = """
                SELECT * FROM messages
                WHERE conversation_id = '\(conversationId.uuidString)'
                ORDER BY created_at ASC, id ASC
                LIMIT \(limit + 1) OFFSET \(offset)
            """

            let result = try await postgres.query(sql)
            let rows = try await result.collect()

            let hasMore = rows.count > limit
            let limitedRows = hasMore ? Array(rows.prefix(limit)) : rows

            var messages: [Message] = []
            for row in limitedRows {
                var message = try MessageEntity.from(row: row).toDomain()
                let attachments = try await pgRepo.fetchAttachments(messageId: message.id)
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

            let lastCursor: (Date, UUID)? = messages.last.map { ($0.timestamp, $0.id) }

            return (messages, hasMore, lastCursor)
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to load messages for conversation \(conversationId)")
            }
            return ([], false, nil)
        }
    }

    func getLastMessagePreview(for conversationId: UUID, maxLength: Int = 100) async -> String? {
        do {
            let sql = """
                SELECT content FROM messages
                WHERE conversation_id = '\(conversationId.uuidString)'
                ORDER BY created_at DESC, id DESC
                LIMIT 1
            """
            let result = try await postgres.query(sql)
            let rows = try await result.collect()

            if let row = rows.first {
                let content = try row.makeRandomAccess()["content"].decode(String?.self, context: .default) ?? ""
                let preview = content
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                return String(preview.prefix(maxLength))
            }
            return nil
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to get last message preview for conversation \(conversationId)")
            }
            return nil
        }
    }

    func saveMessage(_ message: Message) async {
        do {
            try await pgRepo.saveMessage(message)
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to save message \(message.id)")
            }
        }
    }

    /// Delete a conversation and all associated data
    @discardableResult
    func deleteConversation(_ conversationId: UUID) async -> Bool {
        do {
            try await pgRepo.delete(id: conversationId)
            await MainActor.run {
                AppLogger.shared.log("Deleted conversation \(conversationId) and all associated data", level: .info)
            }
            return true
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete conversation \(conversationId)")
            }
            return false
        }
    }

    func archiveConversation(_ conversationId: UUID, isArchived: Bool) async {
        do {
            if isArchived {
                try await pgRepo.archive(id: conversationId)
            } else {
                // Unarchive - update is_archived to false
                try await postgres.execute(
                    "UPDATE conversations SET is_archived = false WHERE id = '\(conversationId.uuidString)'"
                )
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to archive conversation \(conversationId)")
            }
        }
    }

    func deleteMessage(_ messageId: UUID) async {
        do {
            try await pgRepo.deleteMessage(id: messageId)
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete message \(messageId)")
            }
        }
    }

    func updateMessage(_ message: Message) async {
        do {
            try await pgRepo.saveMessage(message) // Uses ON CONFLICT DO UPDATE
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to update message \(message.id)")
            }
        }
    }

    /// Search messages using PostgreSQL full-text search
    func searchMessages(
        query: String,
        conversationId: UUID? = nil,
        limit: Int = 50
    ) async -> [(message: Message, score: Double)] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        do {
            let escapedQuery = query.replacingOccurrences(of: "'", with: "''")
            var sql = """
                SELECT m.*, ts_rank(m.content_tsv, plainto_tsquery('english', '\(escapedQuery)')) as score
                FROM messages m
                WHERE m.content_tsv @@ plainto_tsquery('english', '\(escapedQuery)')
            """

            if let convId = conversationId {
                sql += " AND m.conversation_id = '\(convId.uuidString)'"
            }

            sql += " ORDER BY score DESC LIMIT \(limit)"

            let result = try await postgres.query(sql)
            let rows = try await result.collect()

            var results: [(message: Message, score: Double)] = []
            for row in rows {
                let columns = row.makeRandomAccess()
                let message = try MessageEntity.from(row: row).toDomain()
                let score = try columns["score"].decode(Double?.self, context: .default) ?? 0.0
                results.append((message, score))
            }

            return results
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to search messages")
            }
            return []
        }
    }
}
