import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case tool
}

struct MessageAttachment: Identifiable, Codable {
    let id: UUID
    let data: Data
    let mimeType: String?
    let filename: String?

    var isImage: Bool {
        guard let mimeType = mimeType else { return false }
        return mimeType.hasPrefix("image/")
    }
}

struct Message: Identifiable, Codable {
    let id: UUID
    let conversationId: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let attachments: [MessageAttachment]?
    let toolCallId: String? // For tool messages: the ID of the tool call
    let toolName: String? // For tool messages: the name of the tool that was called
    let mentionReferences: [MentionReference]? // Files/URLs referenced via @-mentions

    init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        attachments: [MessageAttachment]? = nil,
        toolCallId: String? = nil,
        toolName: String? = nil,
        mentionReferences: [MentionReference]? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.attachments = attachments
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.mentionReferences = mentionReferences
    }
}

/// A lightweight reference to a mention for storage with messages
struct MentionReference: Identifiable, Codable, Equatable {
    let id: UUID
    let type: MentionType
    let value: String
    let displayName: String
    let tokenCount: Int?

    init(from mention: Mention) {
        self.id = mention.id
        self.type = mention.type
        self.value = mention.value
        self.displayName = mention.displayName
        self.tokenCount = mention.tokenCount
    }

    init(id: UUID = UUID(), type: MentionType, value: String, displayName: String, tokenCount: Int? = nil) {
        self.id = id
        self.type = type
        self.value = value
        self.displayName = displayName
        self.tokenCount = tokenCount
    }
}
