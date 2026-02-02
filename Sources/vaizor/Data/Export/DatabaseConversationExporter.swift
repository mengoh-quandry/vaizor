import Foundation
import GRDB
import ZIPFoundation

final class DatabaseConversationExporter {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func exportConversation(id: UUID, to destinationURL: URL) async throws {
        let payload = try await dbQueue.read { db -> (Conversation, [Message]) in
            guard let conversationRecord = try ConversationRecord
                .filter(Column("id") == id.uuidString)
                .fetchOne(db) else {
                throw NSError(domain: "ConversationExporter", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conversation not found"])
            }

            let messageRecords = try MessageRecord
                .filter(Column("conversation_id") == id.uuidString)
                .order(Column("created_at"))
                .fetchAll(db)

            let messageIds = messageRecords.map { $0.id }
            let attachments: [AttachmentRecord]
            if messageIds.isEmpty {
                attachments = []
            } else {
                let placeholders = Array(repeating: "?", count: messageIds.count).joined(separator: ",")
                let sql = "SELECT * FROM attachments WHERE message_id IN (\(placeholders))"
                attachments = try AttachmentRecord.fetchAll(db, sql: sql, arguments: StatementArguments(messageIds))
            }
            let attachmentMap = Dictionary(grouping: attachments, by: { $0.messageId })

            let messages = messageRecords.map { record in
                let recordAttachments = attachmentMap[record.id] ?? []
                return record.asModel(attachments: recordAttachments)
            }

            return (conversationRecord.asModel(), messages)
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let conversationURL = tempDir.appendingPathComponent("conversation.json")
        let messagesURL = tempDir.appendingPathComponent("messages.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        try encoder.encode(payload.0).write(to: conversationURL)
        try encoder.encode(payload.1).write(to: messagesURL)

        let archive = try Archive(url: destinationURL, accessMode: .create)

        try archive.addEntry(with: "conversation.json", fileURL: conversationURL)
        try archive.addEntry(with: "messages.json", fileURL: messagesURL)
    }
}
