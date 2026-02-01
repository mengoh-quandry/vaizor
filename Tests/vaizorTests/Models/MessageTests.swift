import XCTest
@testable import vaizor

// MARK: - Message Tests

final class MessageTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let conversationId = UUID()
        let message = Message(
            conversationId: conversationId,
            role: .user,
            content: "Hello, world!"
        )

        XCTAssertNotNil(message.id)
        XCTAssertEqual(message.conversationId, conversationId)
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello, world!")
        XCTAssertNil(message.attachments)
        XCTAssertNil(message.toolCallId)
        XCTAssertNil(message.toolName)
        XCTAssertNil(message.mentionReferences)
    }

    func testCustomInitialization() {
        let id = UUID()
        let conversationId = UUID()
        let timestamp = Date(timeIntervalSince1970: 1000000)
        let attachment = MessageAttachment(
            id: UUID(),
            data: Data("test".utf8),
            mimeType: "text/plain",
            filename: "test.txt"
        )
        let mentionRef = MentionReference(
            type: .file,
            value: "/path/to/file.txt",
            displayName: "file.txt",
            tokenCount: 100
        )

        let message = Message(
            id: id,
            conversationId: conversationId,
            role: .assistant,
            content: "Test response",
            timestamp: timestamp,
            attachments: [attachment],
            toolCallId: "call_123",
            toolName: "get_weather",
            mentionReferences: [mentionRef]
        )

        XCTAssertEqual(message.id, id)
        XCTAssertEqual(message.conversationId, conversationId)
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "Test response")
        XCTAssertEqual(message.timestamp, timestamp)
        XCTAssertEqual(message.attachments?.count, 1)
        XCTAssertEqual(message.toolCallId, "call_123")
        XCTAssertEqual(message.toolName, "get_weather")
        XCTAssertEqual(message.mentionReferences?.count, 1)
    }

    func testAllMessageRoles() {
        let conversationId = UUID()

        let userMessage = Message(conversationId: conversationId, role: .user, content: "User")
        let assistantMessage = Message(conversationId: conversationId, role: .assistant, content: "Assistant")
        let systemMessage = Message(conversationId: conversationId, role: .system, content: "System")
        let toolMessage = Message(conversationId: conversationId, role: .tool, content: "Tool")

        XCTAssertEqual(userMessage.role, .user)
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(systemMessage.role, .system)
        XCTAssertEqual(toolMessage.role, .tool)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let conversationId = UUID()
        let original = Message(
            conversationId: conversationId,
            role: .assistant,
            content: "Test content",
            toolCallId: "call_456",
            toolName: "calculate"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.conversationId, original.conversationId)
        XCTAssertEqual(decoded.role, original.role)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.toolCallId, original.toolCallId)
        XCTAssertEqual(decoded.toolName, original.toolName)
    }

    func testEncodeDecodeWithAttachments() throws {
        let attachment = MessageAttachment(
            id: UUID(),
            data: Data("attachment content".utf8),
            mimeType: "image/png",
            filename: "image.png"
        )

        let original = Message(
            conversationId: UUID(),
            role: .user,
            content: "See attached",
            attachments: [attachment]
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decoded.attachments?.count, 1)
        XCTAssertEqual(decoded.attachments?.first?.mimeType, "image/png")
        XCTAssertEqual(decoded.attachments?.first?.filename, "image.png")
        XCTAssertEqual(decoded.attachments?.first?.data, attachment.data)
    }

    func testEncodeDecodeWithMentions() throws {
        let mentionRef = MentionReference(
            id: UUID(),
            type: .url,
            value: "https://example.com",
            displayName: "example.com",
            tokenCount: 50
        )

        let original = Message(
            conversationId: UUID(),
            role: .user,
            content: "Check this: @url:https://example.com",
            mentionReferences: [mentionRef]
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decoded.mentionReferences?.count, 1)
        XCTAssertEqual(decoded.mentionReferences?.first?.type, .url)
        XCTAssertEqual(decoded.mentionReferences?.first?.value, "https://example.com")
        XCTAssertEqual(decoded.mentionReferences?.first?.tokenCount, 50)
    }

    func testEncodeDecodeWithNilOptionals() throws {
        let original = Message(
            conversationId: UUID(),
            role: .user,
            content: "Simple message",
            attachments: nil,
            toolCallId: nil,
            toolName: nil,
            mentionReferences: nil
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertNil(decoded.attachments)
        XCTAssertNil(decoded.toolCallId)
        XCTAssertNil(decoded.toolName)
        XCTAssertNil(decoded.mentionReferences)
    }

    // MARK: - MessageAttachment Tests

    func testMessageAttachmentImageDetection() {
        let imageAttachment = MessageAttachment(
            id: UUID(),
            data: Data(),
            mimeType: "image/jpeg",
            filename: "photo.jpg"
        )

        let textAttachment = MessageAttachment(
            id: UUID(),
            data: Data(),
            mimeType: "text/plain",
            filename: "doc.txt"
        )

        let nilMimeAttachment = MessageAttachment(
            id: UUID(),
            data: Data(),
            mimeType: nil,
            filename: "unknown"
        )

        XCTAssertTrue(imageAttachment.isImage)
        XCTAssertFalse(textAttachment.isImage)
        XCTAssertFalse(nilMimeAttachment.isImage)
    }

    func testMessageAttachmentVariousImageTypes() {
        let types = ["image/jpeg", "image/png", "image/gif", "image/webp", "image/svg+xml"]

        for type in types {
            let attachment = MessageAttachment(id: UUID(), data: Data(), mimeType: type, filename: "file")
            XCTAssertTrue(attachment.isImage, "\(type) should be detected as image")
        }
    }

    // MARK: - MentionReference Tests

    func testMentionReferenceFromMention() {
        let mention = Mention(
            type: .file,
            value: "/path/to/test.swift",
            displayName: "test.swift",
            resolvedContent: "file content",
            tokenCount: 42
        )

        let reference = MentionReference(from: mention)

        XCTAssertEqual(reference.type, .file)
        XCTAssertEqual(reference.value, "/path/to/test.swift")
        XCTAssertEqual(reference.displayName, "test.swift")
        XCTAssertEqual(reference.tokenCount, 42)
    }

    func testMentionReferenceDirectInitialization() {
        let id = UUID()
        let reference = MentionReference(
            id: id,
            type: .project,
            value: "MyProject",
            displayName: "My Project",
            tokenCount: 1000
        )

        XCTAssertEqual(reference.id, id)
        XCTAssertEqual(reference.type, .project)
        XCTAssertEqual(reference.value, "MyProject")
        XCTAssertEqual(reference.displayName, "My Project")
        XCTAssertEqual(reference.tokenCount, 1000)
    }

    func testMentionReferenceCodable() throws {
        let original = MentionReference(
            type: .folder,
            value: "/Users/test/Documents",
            displayName: "Documents",
            tokenCount: nil
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(MentionReference.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value, original.value)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertNil(decoded.tokenCount)
    }

    func testMentionReferenceEquality() {
        let id = UUID()
        let ref1 = MentionReference(id: id, type: .file, value: "path", displayName: "name")
        let ref2 = MentionReference(id: id, type: .file, value: "path", displayName: "name")
        let ref3 = MentionReference(id: UUID(), type: .file, value: "path", displayName: "name")

        XCTAssertEqual(ref1, ref2)
        XCTAssertNotEqual(ref1, ref3)
    }

    // MARK: - Edge Cases

    func testEmptyContent() {
        let message = Message(conversationId: UUID(), role: .user, content: "")
        XCTAssertEqual(message.content, "")
    }

    func testVeryLongContent() {
        let longContent = String(repeating: "Lorem ipsum ", count: 10000)
        let message = Message(conversationId: UUID(), role: .assistant, content: longContent)

        XCTAssertEqual(message.content.count, longContent.count)
    }

    func testUnicodeContent() {
        let unicodeContent = "Hello World Test Unicode: alpha beta gamma"

        let message = Message(conversationId: UUID(), role: .user, content: unicodeContent)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let data = try encoder.encode(message)
            let decoded = try decoder.decode(Message.self, from: data)
            XCTAssertEqual(decoded.content, unicodeContent)
        } catch {
            XCTFail("Failed to encode/decode unicode content: \(error)")
        }
    }

    func testSpecialCharactersInContent() throws {
        let specialContent = "Test with \"quotes\", 'apostrophes', \\backslashes\\, \nnewlines\tand\ttabs"

        let message = Message(conversationId: UUID(), role: .assistant, content: specialContent)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(message)
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decoded.content, specialContent)
    }

    func testMultipleAttachments() throws {
        let attachments = [
            MessageAttachment(id: UUID(), data: Data("file1".utf8), mimeType: "text/plain", filename: "file1.txt"),
            MessageAttachment(id: UUID(), data: Data("file2".utf8), mimeType: "image/png", filename: "file2.png"),
            MessageAttachment(id: UUID(), data: Data("file3".utf8), mimeType: "application/json", filename: "file3.json")
        ]

        let message = Message(
            conversationId: UUID(),
            role: .user,
            content: "Multiple files",
            attachments: attachments
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(message)
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decoded.attachments?.count, 3)
        XCTAssertEqual(decoded.attachments?[0].filename, "file1.txt")
        XCTAssertEqual(decoded.attachments?[1].filename, "file2.png")
        XCTAssertEqual(decoded.attachments?[2].filename, "file3.json")
    }

    func testEmptyAttachmentsArray() throws {
        let message = Message(
            conversationId: UUID(),
            role: .user,
            content: "No attachments",
            attachments: []
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(message)
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertNotNil(decoded.attachments)
        XCTAssertTrue(decoded.attachments?.isEmpty ?? false)
    }

    func testBinaryDataInAttachment() throws {
        var binaryData = Data()
        for i in 0..<256 {
            binaryData.append(UInt8(i))
        }

        let attachment = MessageAttachment(
            id: UUID(),
            data: binaryData,
            mimeType: "application/octet-stream",
            filename: "binary.bin"
        )

        let message = Message(
            conversationId: UUID(),
            role: .assistant,
            content: "Binary data attached",
            attachments: [attachment]
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(message)
        let decoded = try decoder.decode(Message.self, from: data)

        XCTAssertEqual(decoded.attachments?.first?.data, binaryData)
    }
}

// MARK: - MessageRole Tests

final class MessageRoleTests: XCTestCase {

    func testAllCases() {
        let allRoles: [MessageRole] = [.user, .assistant, .system, .tool]
        XCTAssertEqual(allRoles.count, 4)
    }

    func testRawValues() {
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(MessageRole.system.rawValue, "system")
        XCTAssertEqual(MessageRole.tool.rawValue, "tool")
    }

    func testCodable() throws {
        let allRoles: [MessageRole] = [.user, .assistant, .system, .tool]
        for role in allRoles {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(role)
            let decoded = try decoder.decode(MessageRole.self, from: data)

            XCTAssertEqual(decoded, role)
        }
    }

    func testInitFromRawValue() {
        XCTAssertEqual(MessageRole(rawValue: "user"), .user)
        XCTAssertEqual(MessageRole(rawValue: "assistant"), .assistant)
        XCTAssertNil(MessageRole(rawValue: "invalid"))
        XCTAssertNil(MessageRole(rawValue: ""))
    }
}
