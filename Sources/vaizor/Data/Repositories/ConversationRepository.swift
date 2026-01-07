import Foundation
import GRDB

actor ConversationRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func loadMessages(for conversationId: UUID) async -> [Message] {
        // Load initial chunk (most recent messages)
        let result = await loadMessages(for: conversationId, limit: 100)
        return result.messages
    }
    
    /// Load messages with keyset pagination
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - after: Optional cursor (created_at timestamp, message id) for pagination
    ///   - limit: Maximum number of messages to load (default: 100)
    /// - Returns: Tuple of (messages, hasMore, lastCursor)
    func loadMessages(
        for conversationId: UUID,
        after: (createdAt: Date, id: UUID)? = nil,
        limit: Int = 100
    ) async -> (messages: [Message], hasMore: Bool, lastCursor: (Date, UUID)?) {
        let conversationIdString = conversationId.uuidString
        do {
            return try await dbQueue.read { db in
                let records: [MessageRecord]
                let hasMore: Bool
                
                if let cursor = after {
                    // Keyset pagination: load messages before cursor (older messages)
                    let cursorTimestamp = cursor.createdAt.timeIntervalSince1970
                    let cursorId = cursor.id.uuidString
                    let sql = """
                        SELECT * FROM messages 
                        WHERE conversation_id = ? 
                        AND (created_at < ? OR (created_at = ? AND id < ?))
                        ORDER BY created_at DESC, id DESC
                        LIMIT ?
                        """
                    let allRecords = try MessageRecord.fetchAll(
                        db,
                        sql: sql,
                        arguments: [conversationIdString, cursorTimestamp, cursorTimestamp, cursorId, limit + 1]
                    )
                    hasMore = allRecords.count > limit
                    records = Array(allRecords.prefix(limit))
                } else {
                    // Initial load: get most recent messages
                    let allRecords = try MessageRecord
                        .filter(Column("conversation_id") == conversationIdString)
                        .order(Column("created_at").desc, Column("id").desc)
                        .limit(limit + 1)
                        .fetchAll(db)
                    hasMore = allRecords.count > limit
                    records = Array(allRecords.prefix(limit))
                }
                
                // Reverse to get chronological order (oldest first)
                let reversedRecords = records.reversed()
                
                let messageIds = reversedRecords.map { $0.id }
                let attachments: [AttachmentRecord]
                if messageIds.isEmpty {
                    attachments = []
                } else {
                    let placeholders = Array(repeating: "?", count: messageIds.count).joined(separator: ",")
                    let sql = "SELECT * FROM attachments WHERE message_id IN (\(placeholders))"
                    attachments = try AttachmentRecord.fetchAll(db, sql: sql, arguments: StatementArguments(messageIds))
                }
                
                let attachmentMap = Dictionary(grouping: attachments, by: { $0.messageId })
                
                let messages = reversedRecords.map { record in
                    let recordAttachments = attachmentMap[record.id] ?? []
                    return record.asModel(attachments: recordAttachments)
                }
                
                // Create cursor from last message (oldest in this batch)
                let lastCursor: (Date, UUID)? = messages.last.map { message in
                    (message.timestamp, message.id)
                }
                
                return (messages, hasMore, lastCursor)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to load messages for conversation \(conversationIdString)")
            }
            return ([], false, nil)
        }
    }

    func saveMessage(_ message: Message) async {
        do {
            try await dbQueue.write { db in
                try MessageRecord(message).insert(db)
                try ConversationRepository.saveAttachments(message: message, in: db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to save message \(message.id)")
            }
        }
    }

    func deleteConversation(_ conversationId: UUID) async {
        do {
            try await dbQueue.write { db in
                // Delete conversation - cascade deletes will automatically remove:
                // - All messages (via foreign key cascade)
                // - All attachments (via foreign key cascade from messages)
                // - All tool runs (via foreign key cascade)
                // - All rendered markdown (via foreign key cascade from messages)
                // - FTS5 entries (via trigger)
                _ = try ConversationRecord
                    .filter(Column("id") == conversationId.uuidString)
                    .deleteAll(db)
            }
            await MainActor.run {
                AppLogger.shared.log("Deleted conversation \(conversationId) and all associated data", level: .info)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete conversation \(conversationId)")
            }
        }
    }
    
    func archiveConversation(_ conversationId: UUID, isArchived: Bool) async {
        do {
            try await dbQueue.write { db in
                if var record = try ConversationRecord.fetchOne(db, key: conversationId.uuidString) {
                    record.isArchived = isArchived
                    try record.update(db)
                }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to archive conversation \(conversationId)")
            }
        }
    }

    func deleteMessage(_ messageId: UUID) async {
        do {
            try await dbQueue.write { db in
                _ = try MessageRecord
                    .filter(Column("id") == messageId.uuidString)
                    .deleteAll(db)
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to delete message \(messageId)")
            }
        }
    }

    private static func saveAttachments(message: Message, in db: Database) throws {
        guard let attachments = message.attachments else { return }
        for attachment in attachments {
            try AttachmentRecord(attachment, messageId: message.id).insert(db)
        }
    }
    
    /// Search messages using FTS5
    /// - Parameters:
    ///   - query: Search query string
    ///   - conversationId: Optional conversation ID to scope search
    ///   - limit: Maximum number of results (default: 50)
    /// - Returns: Array of matching messages with relevance scores
    func searchMessages(
        query: String,
        conversationId: UUID? = nil,
        limit: Int = 50
    ) async -> [(message: Message, score: Double)] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let conversationIdString = conversationId?.uuidString
        do {
            return try await dbQueue.read { db in
                // Build FTS5 query - escape special characters
                let escapedQuery = query
                    .replacingOccurrences(of: "\"", with: "\"\"")
                    .replacingOccurrences(of: "'", with: "''")
                
                var sql = """
                    SELECT m.*, bm25(messages_fts) as score
                    FROM messages_fts
                    JOIN messages m ON messages_fts.rowid = m.rowid
                    WHERE messages_fts MATCH ?
                """
                
                var arguments: [DatabaseValueConvertible] = [escapedQuery]
                
                if let convId = conversationIdString {
                    sql += " AND m.conversation_id = ?"
                    arguments.append(convId)
                }
                
                sql += " ORDER BY score LIMIT ?"
                arguments.append(limit)
                
                // Fetch rows with scores
                let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
                
                // Extract message IDs and scores
                var messageIds: [String] = []
                var scoreMap: [String: Double] = [:]
                
                for row in rows {
                    if let messageId = row["id"] as? String {
                        messageIds.append(messageId)
                        if let score = row["score"] as? Double {
                            scoreMap[messageId] = score
                        }
                    }
                }
                
                // Load message records
                let records: [MessageRecord]
                if messageIds.isEmpty {
                    records = []
                } else {
                    let placeholders = Array(repeating: "?", count: messageIds.count).joined(separator: ",")
                    let recordSQL = "SELECT * FROM messages WHERE id IN (\(placeholders))"
                    records = try MessageRecord.fetchAll(db, sql: recordSQL, arguments: StatementArguments(messageIds))
                }
                
                // Get attachments for matching messages
                let attachments: [AttachmentRecord]
                if messageIds.isEmpty {
                    attachments = []
                } else {
                    let placeholders = Array(repeating: "?", count: messageIds.count).joined(separator: ",")
                    let attachmentSQL = "SELECT * FROM attachments WHERE message_id IN (\(placeholders))"
                    attachments = try AttachmentRecord.fetchAll(db, sql: attachmentSQL, arguments: StatementArguments(messageIds))
                }
                
                let attachmentMap = Dictionary(grouping: attachments, by: { $0.messageId })
                
                // Preserve order from search results
                return messageIds.compactMap { messageId in
                    guard let record = records.first(where: { $0.id == messageId }) else { return nil }
                    let recordAttachments = attachmentMap[record.id] ?? []
                    let message = record.asModel(attachments: recordAttachments)
                    let score = scoreMap[messageId] ?? 0.0
                    return (message, score)
                }
            }
        } catch {
            await MainActor.run {
                AppLogger.shared.logError(error, context: "Failed to search messages")
            }
            return []
        }
    }
}
