import Foundation
import GRDB

final class DatabaseManager: @unchecked Sendable {
    static let shared = DatabaseManager()

    let dbQueue: DatabaseQueue

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let vaizorDir = appSupport.appendingPathComponent("Vaizor")
        try? FileManager.default.createDirectory(at: vaizorDir, withIntermediateDirectories: true)
        let dbURL = vaizorDir.appendingPathComponent("vaizor.sqlite")

        DatabaseManager.handleEmptyDatabaseFile(at: dbURL, in: vaizorDir)

        var queue: DatabaseQueue
        do {
            queue = try DatabaseManager.openDatabase(at: dbURL)
        } catch {
            Task { @MainActor in
                AppLogger.shared.log("Database initialization failed: \(error.localizedDescription)", level: .error)
            }

            if FileManager.default.fileExists(atPath: dbURL.path) {
                let timestamp = DatabaseManager.timestampedSuffix()
                let backupURL = vaizorDir.appendingPathComponent("vaizor.sqlite.broken-\(timestamp)")
                try? FileManager.default.moveItem(at: dbURL, to: backupURL)
            }

            do {
                queue = try DatabaseManager.openDatabase(at: dbURL)
            } catch {
                Task { @MainActor in
                    AppLogger.shared.log("Database recovery failed, falling back to in-memory DB: \(error.localizedDescription)", level: .error)
                }
                do {
                    queue = try DatabaseManager.openInMemoryDatabase()
                } catch {
                    Task { @MainActor in
                        AppLogger.shared.log("In-memory DB fallback failed: \(error.localizedDescription)", level: .error)
                    }
                    queue = DatabaseManager.openEmergencyDatabase()
                }
            }
        }

        dbQueue = queue

        do {
            try importLegacyJSONIfNeeded(in: vaizorDir)
        } catch {
            Task { @MainActor in
                AppLogger.shared.log("Legacy JSON import failed: \(error.localizedDescription)", level: .warning)
            }
        }
    }

    private static func handleEmptyDatabaseFile(at dbURL: URL, in directory: URL) {
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return }
        let attributes = try? FileManager.default.attributesOfItem(atPath: dbURL.path)
        if let size = attributes?[.size] as? NSNumber, size.intValue == 0 {
            let timestamp = DatabaseManager.timestampedSuffix()
            let backupURL = directory.appendingPathComponent("vaizor.sqlite.empty-\(timestamp)")
            try? FileManager.default.moveItem(at: dbURL, to: backupURL)
        }
    }

    private static func configure(_ dbQueue: DatabaseQueue, useWAL: Bool) throws {
        try dbQueue.write { db in
            if useWAL {
                try db.execute(sql: "PRAGMA journal_mode = WAL;")
            } else {
                try db.execute(sql: "PRAGMA journal_mode = MEMORY;")
            }
            try db.execute(sql: "PRAGMA foreign_keys = ON;")
        }
    }

    private static func openDatabase(at url: URL) throws -> DatabaseQueue {
        let queue = try DatabaseQueue(path: url.path)
        try configure(queue, useWAL: true)
        try makeMigrator().migrate(queue)
        return queue
    }

    private static func openInMemoryDatabase() throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        try configure(queue, useWAL: false)
        try makeMigrator().migrate(queue)
        return queue
    }

    private static func openEmergencyDatabase() -> DatabaseQueue {
        let tempPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("vaizor-emergency.sqlite")
        let fallbackPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("vaizor-emergency-\(UUID().uuidString).sqlite")
        let candidates: [() -> DatabaseQueue?] = [
            { try? DatabaseQueue() },
            { try? DatabaseQueue(path: tempPath) },
            { try? DatabaseQueue(path: fallbackPath) }
        ]

        for makeQueue in candidates {
            if let queue = makeQueue() {
                try? configure(queue, useWAL: false)
                try? makeMigrator().migrate(queue)
                return queue
            }
        }

        fatalError("Unable to open emergency database.")
    }

    private static func timestampedSuffix() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func importLegacyJSONIfNeeded(in directory: URL) throws {
        let conversationURL = directory.appendingPathComponent("conversations.json")
        let messagesURL = directory.appendingPathComponent("messages.json")

        guard FileManager.default.fileExists(atPath: conversationURL.path)
                || FileManager.default.fileExists(atPath: messagesURL.path) else {
            return
        }

        let shouldImport = try dbQueue.read { db in
            let existing = try String.fetchOne(
                db,
                sql: "SELECT value FROM settings WHERE key = ?",
                arguments: ["legacy_json_imported"]
            )
            return existing == nil
        }

        guard shouldImport else { return }

        let decoder = JSONDecoder()
        let conversations: [Conversation]
        if FileManager.default.fileExists(atPath: conversationURL.path),
           let data = try? Data(contentsOf: conversationURL),
           let loaded = try? decoder.decode([Conversation].self, from: data) {
            conversations = loaded
        } else {
            conversations = []
        }

        let messages: [Message]
        if FileManager.default.fileExists(atPath: messagesURL.path),
           let data = try? Data(contentsOf: messagesURL),
           let loaded = try? decoder.decode([Message].self, from: data) {
            messages = loaded
        } else {
            messages = []
        }

        guard !conversations.isEmpty || !messages.isEmpty else { return }

        let messageCounts = Dictionary(grouping: messages, by: { $0.conversationId })
            .mapValues { $0.count }
        let messageConversationIds = Set(messages.map { $0.conversationId })
        let conversationIds = Set(conversations.map { $0.id })

        try dbQueue.write { db in
            if conversations.isEmpty {
                for id in messageConversationIds {
                    let conversation = Conversation(
                        id: id,
                        title: "Imported Chat",
                        summary: "",
                        createdAt: Date(),
                        lastUsedAt: Date(),
                        messageCount: messageCounts[id] ?? 0
                    )
                    try ConversationRecord(conversation).insert(db, onConflict: .ignore)
                }
            } else {
                for conversation in conversations {
                    var record = ConversationRecord(conversation)
                    record.messageCount = messageCounts[conversation.id] ?? conversation.messageCount
                    try record.insert(db, onConflict: .ignore)
                }

                let missingIds = messageConversationIds.subtracting(conversationIds)
                for id in missingIds {
                    let conversation = Conversation(
                        id: id,
                        title: "Imported Chat",
                        summary: "",
                        createdAt: Date(),
                        lastUsedAt: Date(),
                        messageCount: messageCounts[id] ?? 0
                    )
                    try ConversationRecord(conversation).insert(db, onConflict: .ignore)
                }
            }

            for message in messages {
                try MessageRecord(message).insert(db, onConflict: .ignore)
                if let attachments = message.attachments {
                    for attachment in attachments {
                        try AttachmentRecord(attachment, messageId: message.id).insert(db, onConflict: .ignore)
                    }
                }
            }

            for id in messageConversationIds {
                let idString = id.uuidString
                let count = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM messages WHERE conversation_id = ?",
                    arguments: [idString]
                ) ?? 0
                if var record = try ConversationRecord.fetchOne(db, key: idString) {
                    record.messageCount = count
                    try record.update(db)
                }
            }

            try db.execute(
                sql: "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
                arguments: ["legacy_json_imported", "true"]
            )
        }

        Task { @MainActor in
            AppLogger.shared.log("Imported legacy JSON conversations/messages into SQLite", level: .info)
        }
    }
}
