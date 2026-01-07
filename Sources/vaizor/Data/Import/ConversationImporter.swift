import Foundation
import GRDB
import ZIPFoundation
import CryptoKit

final class ConversationImporter {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func importConversation(from archiveURL: URL, allowDuplicate: Bool = false) async throws -> UUID {
        let importHash = try computeImportHash(for: archiveURL)
        let existingConversationId = try existingImportConversationId(for: importHash)
        if existingConversationId != nil && !allowDuplicate {
            throw NSError(
                domain: "ConversationImporter",
                code: 409,
                userInfo: [NSLocalizedDescriptionKey: "This archive was already imported."]
            )
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let archive = try Archive(url: archiveURL, accessMode: .read)

        let conversationURL = tempDir.appendingPathComponent("conversation.json")
        let messagesURL = tempDir.appendingPathComponent("messages.json")

        guard let conversationEntry = archive["conversation.json"] else {
            throw NSError(domain: "ConversationImporter", code: 404, userInfo: [NSLocalizedDescriptionKey: "conversation.json not found in archive"])
        }
        guard let messagesEntry = archive["messages.json"] else {
            throw NSError(domain: "ConversationImporter", code: 404, userInfo: [NSLocalizedDescriptionKey: "messages.json not found in archive"])
        }

        _ = try archive.extract(conversationEntry, to: conversationURL)
        _ = try archive.extract(messagesEntry, to: messagesURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let importedConversation = try decoder.decode(Conversation.self, from: Data(contentsOf: conversationURL))
        let importedMessages = try decoder.decode([Message].self, from: Data(contentsOf: messagesURL))

        let newConversationId = UUID()
        var conversation = importedConversation
        conversation = Conversation(
            id: newConversationId,
            title: conversation.title,
            summary: conversation.summary,
            createdAt: conversation.createdAt,
            lastUsedAt: Date(),
            messageCount: importedMessages.count
        )

        let remappedMessages: [Message] = importedMessages.map { message in
            let newMessageId = UUID()
            let attachments = message.attachments?.map { attachment in
                MessageAttachment(
                    id: UUID(),
                    data: attachment.data,
                    mimeType: attachment.mimeType,
                    filename: attachment.filename
                )
            }
            return Message(
                id: newMessageId,
                conversationId: newConversationId,
                role: message.role,
                content: message.content,
                timestamp: message.timestamp,
                attachments: attachments,
                toolCallId: message.toolCallId,
                toolName: message.toolName
            )
        }

        let conversationRecord = ConversationRecord(conversation)
        let messagesToInsert = remappedMessages
        let importHashValue = importHash

        try await dbQueue.write { db in
            if let existingConversationId, allowDuplicate {
                _ = try ConversationRecord
                    .filter(Column("id") == existingConversationId)
                    .deleteAll(db)
                try db.execute(
                    sql: "DELETE FROM imports WHERE hash = ?",
                    arguments: [importHashValue]
                )
            }

            try conversationRecord.insert(db)
            for message in messagesToInsert {
                try MessageRecord(message).insert(db)
                if let attachments = message.attachments {
                    for attachment in attachments {
                        try AttachmentRecord(attachment, messageId: message.id).insert(db)
                    }
                }
            }
            try db.execute(
                sql: "INSERT INTO imports (hash, conversation_id, imported_at) VALUES (?, ?, ?)",
                arguments: [importHashValue, newConversationId.uuidString, Date().timeIntervalSince1970]
            )
        }

        return newConversationId
    }

    private func computeImportHash(for url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty {
                break
            }
            hasher.update(data: data)
        }

        let hash = hasher.finalize()
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func existingImportConversationId(for hash: String) throws -> String? {
        try dbQueue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: "SELECT conversation_id FROM imports WHERE hash = ? LIMIT 1",
                arguments: [hash]
            )
            return row?["conversation_id"]
        }
    }
}
