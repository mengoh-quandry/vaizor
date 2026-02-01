import XCTest
import Foundation

// MARK: - Model Definitions for Testing
// These mirror the production models to allow isolated testing

enum TestMessageRole: String, Codable {
    case user
    case assistant
    case system
    case tool
}

enum TestLLMProvider: String, Codable, CaseIterable {
    case anthropic
    case openai
    case gemini
    case ollama
    case custom

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic Claude"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .ollama: return "Ollama"
        case .custom: return "Custom Provider"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .anthropic: return "Claude"
        case .openai: return "GPT"
        case .gemini: return "Gemini"
        case .ollama: return "Ollama"
        case .custom: return "Custom"
        }
    }

    var defaultModels: [String] {
        switch self {
        case .anthropic:
            return ["claude-3-5-sonnet-20241022", "claude-3-opus-20240229"]
        case .openai:
            return ["gpt-4-turbo-preview", "gpt-3.5-turbo"]
        case .gemini:
            return ["gemini-pro", "gemini-pro-vision"]
        case .ollama:
            return ["llama2", "mistral"]
        case .custom:
            return []
        }
    }
}

struct TestConversation: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var summary: String
    let createdAt: Date
    var lastUsedAt: Date
    var messageCount: Int
    var isArchived: Bool
    var selectedProvider: TestLLMProvider?
    var selectedModel: String?
    var folderId: UUID?
    var projectId: UUID?
    var tags: [String]
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        summary: String = "",
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        messageCount: Int = 0,
        isArchived: Bool = false,
        selectedProvider: TestLLMProvider? = nil,
        selectedModel: String? = nil,
        folderId: UUID? = nil,
        projectId: UUID? = nil,
        tags: [String] = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.messageCount = messageCount
        self.isArchived = isArchived
        self.selectedProvider = selectedProvider
        self.selectedModel = selectedModel
        self.folderId = folderId
        self.projectId = projectId
        self.tags = tags
        self.isFavorite = isFavorite
    }
}

// MARK: - Conversation Tests

final class ConversationTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let conversation = TestConversation()

        XCTAssertEqual(conversation.title, "New Chat")
        XCTAssertEqual(conversation.summary, "")
        XCTAssertEqual(conversation.messageCount, 0)
        XCTAssertFalse(conversation.isArchived)
        XCTAssertNil(conversation.selectedProvider)
        XCTAssertNil(conversation.selectedModel)
        XCTAssertNil(conversation.folderId)
        XCTAssertNil(conversation.projectId)
        XCTAssertTrue(conversation.tags.isEmpty)
        XCTAssertFalse(conversation.isFavorite)
    }

    func testCustomInitialization() {
        let id = UUID()
        let folderId = UUID()
        let projectId = UUID()
        let createdAt = Date(timeIntervalSince1970: 1000000)
        let lastUsedAt = Date(timeIntervalSince1970: 2000000)

        let conversation = TestConversation(
            id: id,
            title: "Test Conversation",
            summary: "A test summary",
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            messageCount: 42,
            isArchived: true,
            selectedProvider: .anthropic,
            selectedModel: "claude-3-5-sonnet-20241022",
            folderId: folderId,
            projectId: projectId,
            tags: ["work", "important"],
            isFavorite: true
        )

        XCTAssertEqual(conversation.id, id)
        XCTAssertEqual(conversation.title, "Test Conversation")
        XCTAssertEqual(conversation.summary, "A test summary")
        XCTAssertEqual(conversation.createdAt, createdAt)
        XCTAssertEqual(conversation.lastUsedAt, lastUsedAt)
        XCTAssertEqual(conversation.messageCount, 42)
        XCTAssertTrue(conversation.isArchived)
        XCTAssertEqual(conversation.selectedProvider, .anthropic)
        XCTAssertEqual(conversation.selectedModel, "claude-3-5-sonnet-20241022")
        XCTAssertEqual(conversation.folderId, folderId)
        XCTAssertEqual(conversation.projectId, projectId)
        XCTAssertEqual(conversation.tags, ["work", "important"])
        XCTAssertTrue(conversation.isFavorite)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = TestConversation(
            title: "Encode Test",
            summary: "Testing serialization",
            messageCount: 10,
            selectedProvider: .openai,
            selectedModel: "gpt-4-turbo-preview",
            tags: ["test", "serialization"]
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TestConversation.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.summary, original.summary)
        XCTAssertEqual(decoded.messageCount, original.messageCount)
        XCTAssertEqual(decoded.selectedProvider, original.selectedProvider)
        XCTAssertEqual(decoded.selectedModel, original.selectedModel)
        XCTAssertEqual(decoded.tags, original.tags)
    }

    func testEncodeDecodeWithNilOptionals() throws {
        let original = TestConversation(
            title: "Nil Optionals Test",
            selectedProvider: nil,
            selectedModel: nil,
            folderId: nil,
            projectId: nil
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TestConversation.self, from: data)

        XCTAssertNil(decoded.selectedProvider)
        XCTAssertNil(decoded.selectedModel)
        XCTAssertNil(decoded.folderId)
        XCTAssertNil(decoded.projectId)
    }

    func testEncodeDecodeWithEmptyTags() throws {
        let original = TestConversation(tags: [])

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TestConversation.self, from: data)

        XCTAssertTrue(decoded.tags.isEmpty)
    }

    func testEncodeDecodePreservesUUID() throws {
        let specificId = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        let original = TestConversation(id: specificId, title: "UUID Test")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TestConversation.self, from: data)

        XCTAssertEqual(decoded.id, specificId)
    }

    // MARK: - Edge Cases

    func testEmptyTitle() {
        let conversation = TestConversation(title: "")
        XCTAssertEqual(conversation.title, "")
    }

    func testVeryLongTitle() {
        let longTitle = String(repeating: "a", count: 10000)
        let conversation = TestConversation(title: longTitle)
        XCTAssertEqual(conversation.title, longTitle)
    }

    func testUnicodeContent() {
        let conversation = TestConversation(
            title: "Test with emoji",
            summary: "Contains various unicode: Hello World",
            tags: ["emoji-test", "unicode"]
        )

        XCTAssertEqual(conversation.title, "Test with emoji")
        XCTAssertTrue(conversation.summary.contains("Hello"))
    }

    func testSpecialCharactersInTags() throws {
        let conversation = TestConversation(
            tags: ["tag/with/slashes", "tag with spaces", "tag-with-dashes", "tag_with_underscores"]
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(conversation)
        let decoded = try decoder.decode(TestConversation.self, from: data)

        XCTAssertEqual(decoded.tags.count, 4)
        XCTAssertTrue(decoded.tags.contains("tag/with/slashes"))
        XCTAssertTrue(decoded.tags.contains("tag with spaces"))
    }

    func testNegativeMessageCount() {
        // While semantically incorrect, the model should handle negative values
        let conversation = TestConversation(messageCount: -5)
        XCTAssertEqual(conversation.messageCount, -5)
    }

    func testDatePrecision() throws {
        let preciseDate = Date(timeIntervalSince1970: 1234567890.123456)
        let conversation = TestConversation(createdAt: preciseDate, lastUsedAt: preciseDate)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(conversation)
        let decoded = try decoder.decode(TestConversation.self, from: data)

        // Check dates are equal within a small epsilon
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, preciseDate.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - Mutability Tests

    func testMutableProperties() {
        var conversation = TestConversation()

        conversation.title = "Updated Title"
        conversation.summary = "Updated Summary"
        conversation.lastUsedAt = Date()
        conversation.messageCount = 100
        conversation.isArchived = true
        conversation.isFavorite = true
        conversation.tags = ["new", "tags"]

        XCTAssertEqual(conversation.title, "Updated Title")
        XCTAssertEqual(conversation.summary, "Updated Summary")
        XCTAssertEqual(conversation.messageCount, 100)
        XCTAssertTrue(conversation.isArchived)
        XCTAssertTrue(conversation.isFavorite)
        XCTAssertEqual(conversation.tags, ["new", "tags"])
    }

    // MARK: - Equatable Tests

    func testEquality() {
        let id = UUID()
        let date = Date()

        let conv1 = TestConversation(
            id: id,
            title: "Test",
            createdAt: date,
            lastUsedAt: date
        )

        let conv2 = TestConversation(
            id: id,
            title: "Test",
            createdAt: date,
            lastUsedAt: date
        )

        XCTAssertEqual(conv1, conv2)
    }

    func testInequalityDifferentId() {
        let conv1 = TestConversation(title: "Test")
        let conv2 = TestConversation(title: "Test")

        XCTAssertNotEqual(conv1, conv2) // Different UUIDs
    }
}

// MARK: - LLMProvider Tests

final class LLMProviderTests: XCTestCase {

    func testAllCases() {
        let allProviders = TestLLMProvider.allCases
        XCTAssertEqual(allProviders.count, 5)
        XCTAssertTrue(allProviders.contains(.anthropic))
        XCTAssertTrue(allProviders.contains(.openai))
        XCTAssertTrue(allProviders.contains(.gemini))
        XCTAssertTrue(allProviders.contains(.ollama))
        XCTAssertTrue(allProviders.contains(.custom))
    }

    func testDisplayNames() {
        XCTAssertEqual(TestLLMProvider.anthropic.displayName, "Anthropic Claude")
        XCTAssertEqual(TestLLMProvider.openai.displayName, "OpenAI")
        XCTAssertEqual(TestLLMProvider.gemini.displayName, "Google Gemini")
        XCTAssertEqual(TestLLMProvider.ollama.displayName, "Ollama")
        XCTAssertEqual(TestLLMProvider.custom.displayName, "Custom Provider")
    }

    func testShortDisplayNames() {
        XCTAssertEqual(TestLLMProvider.anthropic.shortDisplayName, "Claude")
        XCTAssertEqual(TestLLMProvider.openai.shortDisplayName, "GPT")
        XCTAssertEqual(TestLLMProvider.gemini.shortDisplayName, "Gemini")
        XCTAssertEqual(TestLLMProvider.ollama.shortDisplayName, "Ollama")
        XCTAssertEqual(TestLLMProvider.custom.shortDisplayName, "Custom")
    }

    func testDefaultModels() {
        XCTAssertFalse(TestLLMProvider.anthropic.defaultModels.isEmpty)
        XCTAssertTrue(TestLLMProvider.anthropic.defaultModels.contains("claude-3-5-sonnet-20241022"))

        XCTAssertFalse(TestLLMProvider.openai.defaultModels.isEmpty)
        XCTAssertTrue(TestLLMProvider.openai.defaultModels.contains("gpt-4-turbo-preview"))

        XCTAssertFalse(TestLLMProvider.gemini.defaultModels.isEmpty)
        XCTAssertFalse(TestLLMProvider.ollama.defaultModels.isEmpty)

        XCTAssertTrue(TestLLMProvider.custom.defaultModels.isEmpty)
    }

    func testRawValues() {
        XCTAssertEqual(TestLLMProvider.anthropic.rawValue, "anthropic")
        XCTAssertEqual(TestLLMProvider.openai.rawValue, "openai")
        XCTAssertEqual(TestLLMProvider.gemini.rawValue, "gemini")
        XCTAssertEqual(TestLLMProvider.ollama.rawValue, "ollama")
        XCTAssertEqual(TestLLMProvider.custom.rawValue, "custom")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(TestLLMProvider(rawValue: "anthropic"), .anthropic)
        XCTAssertEqual(TestLLMProvider(rawValue: "openai"), .openai)
        XCTAssertNil(TestLLMProvider(rawValue: "invalid"))
        XCTAssertNil(TestLLMProvider(rawValue: ""))
    }

    func testCodable() throws {
        for provider in TestLLMProvider.allCases {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(provider)
            let decoded = try decoder.decode(TestLLMProvider.self, from: data)

            XCTAssertEqual(decoded, provider)
        }
    }
}
