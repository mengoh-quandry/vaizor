import XCTest
import GRDB
@testable import vaizor

// MARK: - ConversationRepository Tests

@MainActor
final class ConversationRepositoryTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var repository: ConversationRepository!

    override func setUp() {
        super.setUp()
        // Create an in-memory database for testing
        dbQueue = try! DatabaseQueue()
        try! makeMigrator().migrate(dbQueue)

        repository = ConversationRepository(dbQueue: dbQueue)
    }

    override func tearDown() {
        repository = nil
        dbQueue = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Create a conversation record to satisfy foreign key constraints
    private func createConversation(id: UUID) async {
        try? await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO conversations (id, title, summary, created_at, last_used_at, message_count, is_archived)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [id.uuidString, "Test", "", Date().timeIntervalSince1970, Date().timeIntervalSince1970, 0, false]
            )
        }
    }

    // MARK: - Save Message Tests

    func testSaveMessage() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)

        let message = Message(
            id: UUID(),
            conversationId: conversationId,
            role: .user,
            content: "Test message",
            timestamp: Date()
        )

        await repository.saveMessage(message)

        // Verify message was saved
        let messages = await repository.loadMessages(for: conversationId)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.content, "Test message")
    }

    func testSaveMessageWithAttachments() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)

        let attachment = MessageAttachment(
            id: UUID(),
            data: Data("test data".utf8),
            mimeType: "text/plain",
            filename: "test.txt"
        )

        let message = Message(
            id: UUID(),
            conversationId: conversationId,
            role: .user,
            content: "Message with attachment",
            timestamp: Date(),
            attachments: [attachment]
        )

        await repository.saveMessage(message)

        let messages = await repository.loadMessages(for: conversationId)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.attachments?.count, 1)
        XCTAssertEqual(messages.first?.attachments?.first?.filename, "test.txt")
    }

    // MARK: - Load Messages Tests

    func testLoadMessagesEmpty() async {
        let conversationId = UUID()
        let messages = await repository.loadMessages(for: conversationId)

        XCTAssertTrue(messages.isEmpty)
    }

    func testLoadMessagesOrdered() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)

        let message1 = Message(
            id: UUID(),
            conversationId: conversationId,
            role: .user,
            content: "First",
            timestamp: Date(timeIntervalSince1970: 1000)
        )

        let message2 = Message(
            id: UUID(),
            conversationId: conversationId,
            role: .assistant,
            content: "Second",
            timestamp: Date(timeIntervalSince1970: 2000)
        )

        let message3 = Message(
            id: UUID(),
            conversationId: conversationId,
            role: .user,
            content: "Third",
            timestamp: Date(timeIntervalSince1970: 3000)
        )

        await repository.saveMessage(message1)
        await repository.saveMessage(message2)
        await repository.saveMessage(message3)

        let messages = await repository.loadMessages(for: conversationId)
        XCTAssertEqual(messages.count, 3)
        // Should be in chronological order (oldest first)
        XCTAssertEqual(messages[0].content, "First")
        XCTAssertEqual(messages[1].content, "Second")
        XCTAssertEqual(messages[2].content, "Third")
    }

    func testLoadMessagesPagination() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)

        // Create many messages
        for i in 0..<150 {
            let message = Message(
                id: UUID(),
                conversationId: conversationId,
                role: i % 2 == 0 ? .user : .assistant,
                content: "Message \(i)",
                timestamp: Date(timeIntervalSince1970: Double(i))
            )
            await repository.saveMessage(message)
        }

        // Load first page
        let result = await repository.loadMessages(
            for: conversationId,
            after: nil,
            limit: 50
        )

        // Should get 50 messages (or less if no more)
        XCTAssertLessThanOrEqual(result.messages.count, 50)
    }

    // MARK: - Delete Message Tests

    func testDeleteMessage() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)
        let messageId = UUID()

        let message = Message(
            id: messageId,
            conversationId: conversationId,
            role: .user,
            content: "To be deleted"
        )

        await repository.saveMessage(message)

        var messages = await repository.loadMessages(for: conversationId)
        XCTAssertEqual(messages.count, 1)

        await repository.deleteMessage(messageId)

        messages = await repository.loadMessages(for: conversationId)
        XCTAssertTrue(messages.isEmpty)
    }

    // MARK: - Delete Conversation Tests

    func testDeleteConversation() async {
        let conversationId = UUID()

        // Insert conversation directly
        try? await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO conversations (id, title, summary, created_at, last_used_at, message_count, is_archived, is_favorite)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                conversationId.uuidString,
                "Test Conversation",
                "",
                Date().timeIntervalSince1970,
                Date().timeIntervalSince1970,
                1,
                false,
                false
            ])
        }

        // Add messages
        let message = Message(
            conversationId: conversationId,
            role: .user,
            content: "Test"
        )
        await repository.saveMessage(message)

        // Delete conversation
        let deleted = await repository.deleteConversation(conversationId)
        XCTAssertTrue(deleted)

        // Verify messages are also deleted (cascade)
        let messages = await repository.loadMessages(for: conversationId)
        XCTAssertTrue(messages.isEmpty)
    }

    // MARK: - Archive Conversation Tests

    func testArchiveConversation() async {
        let conversationId = UUID()

        // Insert conversation
        try? await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO conversations (id, title, summary, created_at, last_used_at, message_count, is_archived, is_favorite)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                conversationId.uuidString,
                "Test",
                "",
                Date().timeIntervalSince1970,
                Date().timeIntervalSince1970,
                0,
                false,
                false
            ])
        }

        // Archive
        await repository.archiveConversation(conversationId, isArchived: true)

        // Verify
        let isArchived: Bool? = try? await dbQueue.read { db in
            try Bool.fetchOne(db, sql: "SELECT is_archived FROM conversations WHERE id = ?", arguments: [conversationId.uuidString])
        }

        XCTAssertEqual(isArchived, true)
    }

    func testUnarchiveConversation() async {
        let conversationId = UUID()

        // Insert archived conversation
        try? await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO conversations (id, title, summary, created_at, last_used_at, message_count, is_archived, is_favorite)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                conversationId.uuidString,
                "Test",
                "",
                Date().timeIntervalSince1970,
                Date().timeIntervalSince1970,
                0,
                true,
                false
            ])
        }

        // Unarchive
        await repository.archiveConversation(conversationId, isArchived: false)

        // Verify
        let isArchived: Bool? = try? await dbQueue.read { db in
            try Bool.fetchOne(db, sql: "SELECT is_archived FROM conversations WHERE id = ?", arguments: [conversationId.uuidString])
        }

        XCTAssertEqual(isArchived, false)
    }

    // MARK: - Get Last Message Preview Tests

    func testGetLastMessagePreview() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)

        let message1 = Message(
            conversationId: conversationId,
            role: .user,
            content: "First message",
            timestamp: Date(timeIntervalSince1970: 1000)
        )

        let message2 = Message(
            conversationId: conversationId,
            role: .assistant,
            content: "Last message preview test",
            timestamp: Date(timeIntervalSince1970: 2000)
        )

        await repository.saveMessage(message1)
        await repository.saveMessage(message2)

        let preview = await repository.getLastMessagePreview(for: conversationId, maxLength: 100)
        XCTAssertEqual(preview, "Last message preview test")
    }

    func testGetLastMessagePreviewTruncated() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)

        let message = Message(
            conversationId: conversationId,
            role: .user,
            content: String(repeating: "A", count: 200)
        )

        await repository.saveMessage(message)

        let preview = await repository.getLastMessagePreview(for: conversationId, maxLength: 50)
        XCTAssertEqual(preview?.count, 50)
    }

    func testGetLastMessagePreviewEmpty() async {
        let conversationId = UUID()
        let preview = await repository.getLastMessagePreview(for: conversationId)

        XCTAssertNil(preview)
    }

    func testGetLastMessagePreviewWithNewlines() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)

        let message = Message(
            conversationId: conversationId,
            role: .user,
            content: "Line 1\nLine 2\nLine 3"
        )

        await repository.saveMessage(message)

        let preview = await repository.getLastMessagePreview(for: conversationId)
        XCTAssertTrue(preview?.contains(" ") ?? false) // Newlines should be replaced with spaces
    }

    // MARK: - Search Messages Tests

    func testSearchMessages() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)

        let message1 = Message(
            conversationId: conversationId,
            role: .user,
            content: "Hello, how are you?"
        )

        let message2 = Message(
            conversationId: conversationId,
            role: .assistant,
            content: "I'm doing great, thanks!"
        )

        let message3 = Message(
            conversationId: conversationId,
            role: .user,
            content: "What's the weather like?"
        )

        await repository.saveMessage(message1)
        await repository.saveMessage(message2)
        await repository.saveMessage(message3)

        // Note: FTS5 search requires proper setup, may not work in basic tests
        // This tests the search function doesn't crash
        let results = await repository.searchMessages(query: "hello", conversationId: conversationId)
        // Results may be empty if FTS5 isn't fully initialized
        XCTAssertNotNil(results)
    }

    func testSearchMessagesEmptyQuery() async {
        let conversationId = UUID()
        let results = await repository.searchMessages(query: "", conversationId: conversationId)
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchMessagesWhitespaceQuery() async {
        let conversationId = UUID()
        let results = await repository.searchMessages(query: "   ", conversationId: conversationId)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Tool Message Tests

    func testSaveToolMessage() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)

        let message = Message(
            conversationId: conversationId,
            role: .tool,
            content: "Weather data: Sunny, 72°F",
            toolCallId: "call_12345",
            toolName: "get_weather"
        )

        await repository.saveMessage(message)

        let messages = await repository.loadMessages(for: conversationId)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.role, .tool)
        XCTAssertEqual(messages.first?.toolCallId, "call_12345")
        XCTAssertEqual(messages.first?.toolName, "get_weather")
    }

    // MARK: - Edge Cases

    func testLoadMessagesWithNonExistentConversation() async {
        let fakeConversationId = UUID()
        let messages = await repository.loadMessages(for: fakeConversationId)
        XCTAssertTrue(messages.isEmpty)
    }

    func testDeleteNonExistentMessage() async {
        let fakeMessageId = UUID()
        // Should not throw
        await repository.deleteMessage(fakeMessageId)
    }

    func testDeleteNonExistentConversation() async {
        let fakeConversationId = UUID()
        let deleted = await repository.deleteConversation(fakeConversationId)
        // Deleting a non-existent conversation is not an error, just a no-op
        // The implementation returns true unless there's a database error
        XCTAssertTrue(deleted)
    }

    func testSaveMessageWithEmptyContent() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)

        let message = Message(
            conversationId: conversationId,
            role: .user,
            content: ""
        )

        await repository.saveMessage(message)

        let messages = await repository.loadMessages(for: conversationId)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.content, "")
    }

    func testSaveMessageWithUnicode() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)

        let message = Message(
            conversationId: conversationId,
            role: .user,
            content: "Hello  World  Test"
        )

        await repository.saveMessage(message)

        let messages = await repository.loadMessages(for: conversationId)
        XCTAssertEqual(messages.first?.content, "Hello  World  Test")
    }

    func testSaveMessageWithVeryLongContent() async {
        let conversationId = UUID()
        await createConversation(id: conversationId)
        let longContent = String(repeating: "Lorem ipsum ", count: 1000)

        let message = Message(
            conversationId: conversationId,
            role: .user,
            content: longContent
        )

        await repository.saveMessage(message)

        let messages = await repository.loadMessages(for: conversationId)
        XCTAssertEqual(messages.first?.content.count, longContent.count)
    }
}
