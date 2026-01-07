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

    init(
        id: UUID = UUID(),
        conversationId: UUID,
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        attachments: [MessageAttachment]? = nil,
        toolCallId: String? = nil,
        toolName: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.attachments = attachments
        self.toolCallId = toolCallId
        self.toolName = toolName
    }
}
