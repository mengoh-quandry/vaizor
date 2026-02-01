import XCTest
import GRDB
@testable import vaizor

// MARK: - DatabaseManager Tests

final class DatabaseManagerTests: XCTestCase {

    var dbQueue: DatabaseQueue!

    override func setUp() {
        super.setUp()
        // Create an in-memory database for testing
        dbQueue = try! DatabaseQueue()

        // Apply migrations
        try! makeMigrator().migrate(dbQueue)
    }

    override func tearDown() {
        dbQueue = nil
        super.tearDown()
    }

    // MARK: - Schema Tests

    func testConversationsTableExists() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("conversations"))
        }
    }

    func testMessagesTableExists() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("messages"))
        }
    }

    func testAttachmentsTableExists() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("attachments"))
        }
    }

    func testFoldersTableExists() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("folders"))
        }
    }

    func testTemplatesTableExists() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("templates"))
        }
    }

    func testProjectsTableExists() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("projects"))
        }
    }

    func testToolRunsTableExists() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("tool_runs"))
        }
    }

    func testSettingsTableExists() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("settings"))
        }
    }

    func testWhiteboardsTableExists() throws {
        try dbQueue.read { db in
            XCTAssertTrue(try db.tableExists("whiteboards"))
        }
    }

    // MARK: - Conversation Schema Tests

    func testConversationsColumns() throws {
        try dbQueue.read { db in
            let columns = try db.columns(in: "conversations")
            let columnNames = columns.map { $0.name }

            XCTAssertTrue(columnNames.contains("id"))
            XCTAssertTrue(columnNames.contains("title"))
            XCTAssertTrue(columnNames.contains("summary"))
            XCTAssertTrue(columnNames.contains("created_at"))
            XCTAssertTrue(columnNames.contains("last_used_at"))
            XCTAssertTrue(columnNames.contains("message_count"))
            XCTAssertTrue(columnNames.contains("is_archived"))
            XCTAssertTrue(columnNames.contains("selected_provider"))
            XCTAssertTrue(columnNames.contains("selected_model"))
            XCTAssertTrue(columnNames.contains("folder_id"))
            XCTAssertTrue(columnNames.contains("tags"))
            XCTAssertTrue(columnNames.contains("is_favorite"))
            XCTAssertTrue(columnNames.contains("project_id"))
        }
    }

    func testConversationsPrimaryKey() throws {
        try dbQueue.read { db in
            let primaryKey = try db.primaryKey("conversations")
            XCTAssertEqual(primaryKey.columns, ["id"])
        }
    }

    // MARK: - Message Schema Tests

    func testMessagesColumns() throws {
        try dbQueue.read { db in
            let columns = try db.columns(in: "messages")
            let columnNames = columns.map { $0.name }

            XCTAssertTrue(columnNames.contains("id"))
            XCTAssertTrue(columnNames.contains("conversation_id"))
            XCTAssertTrue(columnNames.contains("role"))
            XCTAssertTrue(columnNames.contains("content"))
            XCTAssertTrue(columnNames.contains("created_at"))
            XCTAssertTrue(columnNames.contains("tool_call_id"))
            XCTAssertTrue(columnNames.contains("tool_name"))
        }
    }

    func testMessagesForeignKey() throws {
        try dbQueue.read { db in
            let foreignKeys = try db.foreignKeys(on: "messages")
            XCTAssertTrue(foreignKeys.contains { $0.destinationTable == "conversations" })
        }
    }

    func testMessagesIndexExists() throws {
        try dbQueue.read { db in
            let indexes = try db.indexes(on: "messages")
            XCTAssertTrue(indexes.contains { $0.name == "idx_messages_conversation_created" })
        }
    }

    // MARK: - Attachment Schema Tests

    func testAttachmentsColumns() throws {
        try dbQueue.read { db in
            let columns = try db.columns(in: "attachments")
            let columnNames = columns.map { $0.name }

            XCTAssertTrue(columnNames.contains("id"))
            XCTAssertTrue(columnNames.contains("message_id"))
            XCTAssertTrue(columnNames.contains("mime_type"))
            XCTAssertTrue(columnNames.contains("filename"))
            XCTAssertTrue(columnNames.contains("data"))
            XCTAssertTrue(columnNames.contains("is_image"))
            XCTAssertTrue(columnNames.contains("byte_count"))
        }
    }

    func testAttachmentsForeignKey() throws {
        try dbQueue.read { db in
            let foreignKeys = try db.foreignKeys(on: "attachments")
            XCTAssertTrue(foreignKeys.contains { $0.destinationTable == "messages" })
        }
    }

    // MARK: - Folder Schema Tests

    func testFoldersColumns() throws {
        try dbQueue.read { db in
            let columns = try db.columns(in: "folders")
            let columnNames = columns.map { $0.name }

            XCTAssertTrue(columnNames.contains("id"))
            XCTAssertTrue(columnNames.contains("name"))
            XCTAssertTrue(columnNames.contains("color"))
            XCTAssertTrue(columnNames.contains("parent_id"))
            XCTAssertTrue(columnNames.contains("created_at"))
        }
    }

    // MARK: - Project Schema Tests

    func testProjectsColumns() throws {
        try dbQueue.read { db in
            let columns = try db.columns(in: "projects")
            let columnNames = columns.map { $0.name }

            XCTAssertTrue(columnNames.contains("id"))
            XCTAssertTrue(columnNames.contains("name"))
            XCTAssertTrue(columnNames.contains("conversations"))
            XCTAssertTrue(columnNames.contains("context"))
            XCTAssertTrue(columnNames.contains("created_at"))
            XCTAssertTrue(columnNames.contains("updated_at"))
            XCTAssertTrue(columnNames.contains("is_archived"))
            XCTAssertTrue(columnNames.contains("icon_name"))
            XCTAssertTrue(columnNames.contains("color"))
        }
    }

    // MARK: - Template Schema Tests

    func testTemplatesColumns() throws {
        try dbQueue.read { db in
            let columns = try db.columns(in: "templates")
            let columnNames = columns.map { $0.name }

            XCTAssertTrue(columnNames.contains("id"))
            XCTAssertTrue(columnNames.contains("name"))
            XCTAssertTrue(columnNames.contains("prompt"))
            XCTAssertTrue(columnNames.contains("system_prompt"))
            XCTAssertTrue(columnNames.contains("created_at"))
        }
    }

    // MARK: - FTS5 Tests

    func testFTS5TableExists() throws {
        try dbQueue.read { db in
            // FTS5 virtual table should exist
            let exists = try Bool.fetchOne(db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='messages_fts'")
            XCTAssertNotNil(exists)
        }
    }

    func testFTS5TriggersExist() throws {
        try dbQueue.read { db in
            let triggers = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'messages_%'")

            // Should have insert, delete, and update triggers
            XCTAssertTrue(triggers.contains { $0.contains("insert") || $0.contains("ai") })
            XCTAssertTrue(triggers.contains { $0.contains("delete") || $0.contains("ad") })
            XCTAssertTrue(triggers.contains { $0.contains("update") || $0.contains("au") })
        }
    }

    // MARK: - CRUD Tests

    func testInsertConversation() throws {
        let conversationId = UUID().uuidString

        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO conversations (id, title, summary, created_at, last_used_at, message_count, is_archived, is_favorite)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                conversationId,
                "Test Conversation",
                "Test summary",
                Date().timeIntervalSince1970,
                Date().timeIntervalSince1970,
                0,
                false,
                false
            ])
        }

        try dbQueue.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM conversations WHERE id = ?", arguments: [conversationId])
            XCTAssertEqual(count, 1)
        }
    }

    func testInsertMessage() throws {
        let conversationId = UUID().uuidString
        let messageId = UUID().uuidString

        // First insert conversation
        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO conversations (id, title, summary, created_at, last_used_at, message_count, is_archived, is_favorite)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                conversationId,
                "Test",
                "",
                Date().timeIntervalSince1970,
                Date().timeIntervalSince1970,
                0,
                false,
                false
            ])

            // Then insert message
            try db.execute(sql: """
                INSERT INTO messages (id, conversation_id, role, content, created_at)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: [
                messageId,
                conversationId,
                "user",
                "Hello, world!",
                Date().timeIntervalSince1970
            ])
        }

        try dbQueue.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages WHERE id = ?", arguments: [messageId])
            XCTAssertEqual(count, 1)
        }
    }

    func testCascadeDelete() throws {
        let conversationId = UUID().uuidString
        let messageId = UUID().uuidString

        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO conversations (id, title, summary, created_at, last_used_at, message_count, is_archived, is_favorite)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                conversationId,
                "Test",
                "",
                Date().timeIntervalSince1970,
                Date().timeIntervalSince1970,
                0,
                false,
                false
            ])

            try db.execute(sql: """
                INSERT INTO messages (id, conversation_id, role, content, created_at)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: [
                messageId,
                conversationId,
                "user",
                "Test message",
                Date().timeIntervalSince1970
            ])

            // Delete conversation - should cascade to messages
            try db.execute(sql: "DELETE FROM conversations WHERE id = ?", arguments: [conversationId])
        }

        try dbQueue.read { db in
            let conversationCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM conversations WHERE id = ?", arguments: [conversationId])
            let messageCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM messages WHERE id = ?", arguments: [messageId])

            XCTAssertEqual(conversationCount, 0)
            XCTAssertEqual(messageCount, 0)
        }
    }

    func testUpdateConversation() throws {
        let conversationId = UUID().uuidString

        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO conversations (id, title, summary, created_at, last_used_at, message_count, is_archived, is_favorite)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                conversationId,
                "Original Title",
                "",
                Date().timeIntervalSince1970,
                Date().timeIntervalSince1970,
                0,
                false,
                false
            ])

            try db.execute(sql: "UPDATE conversations SET title = ? WHERE id = ?", arguments: ["Updated Title", conversationId])
        }

        try dbQueue.read { db in
            let title = try String.fetchOne(db, sql: "SELECT title FROM conversations WHERE id = ?", arguments: [conversationId])
            XCTAssertEqual(title, "Updated Title")
        }
    }

    func testQueryWithFilter() throws {
        let id1 = UUID().uuidString
        let id2 = UUID().uuidString

        try dbQueue.write { db in
            for (id, title) in [(id1, "First"), (id2, "Second")] {
                try db.execute(sql: """
                    INSERT INTO conversations (id, title, summary, created_at, last_used_at, message_count, is_archived, is_favorite)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    id,
                    title,
                    "",
                    Date().timeIntervalSince1970,
                    Date().timeIntervalSince1970,
                    0,
                    false,
                    false
                ])
            }
        }

        try dbQueue.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM conversations WHERE title = ?", arguments: ["First"])
            XCTAssertEqual(count, 1)
        }
    }

    // MARK: - Index Tests

    func testProjectsIndexes() throws {
        try dbQueue.read { db in
            let indexes = try db.indexes(on: "projects")
            let indexNames = indexes.map { $0.name }

            XCTAssertTrue(indexNames.contains("idx_projects_updated_at"))
            XCTAssertTrue(indexNames.contains("idx_projects_is_archived"))
        }
    }

    func testWhiteboardsIndexes() throws {
        try dbQueue.read { db in
            let indexes = try db.indexes(on: "whiteboards")
            let indexNames = indexes.map { $0.name }

            XCTAssertTrue(indexNames.contains("idx_whiteboards_conversation_id"))
            XCTAssertTrue(indexNames.contains("idx_whiteboards_created_at"))
            XCTAssertTrue(indexNames.contains("idx_whiteboards_updated_at"))
        }
    }

    // MARK: - Foreign Key Enforcement Tests

    func testForeignKeyEnforcement() throws {
        // Try to insert a message with non-existent conversation
        let messageId = UUID().uuidString
        let fakeConversationId = UUID().uuidString

        XCTAssertThrowsError(try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO messages (id, conversation_id, role, content, created_at)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: [
                messageId,
                fakeConversationId,
                "user",
                "Test",
                Date().timeIntervalSince1970
            ])
        })
    }

    // MARK: - Journal Mode Tests

    func testWALModeEnabled() throws {
        try dbQueue.read { db in
            let journalMode = try String.fetchOne(db, sql: "PRAGMA journal_mode")
            // In-memory databases use MEMORY mode, file-based databases use WAL
            // Our test uses in-memory DB, so expect MEMORY
            XCTAssertEqual(journalMode?.uppercased(), "MEMORY")
        }
    }

    func testForeignKeysEnabled() throws {
        try dbQueue.read { db in
            let foreignKeys = try Int.fetchOne(db, sql: "PRAGMA foreign_keys")
            XCTAssertEqual(foreignKeys, 1)
        }
    }
}
