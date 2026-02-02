import Foundation

extension ConversationRecord {
    init(_ conversation: Conversation) {
        id = conversation.id.uuidString
        title = conversation.title
        summary = conversation.summary
        createdAt = conversation.createdAt.timeIntervalSince1970
        lastUsedAt = conversation.lastUsedAt.timeIntervalSince1970
        messageCount = conversation.messageCount
        isArchived = conversation.isArchived
        selectedProvider = conversation.selectedProvider?.rawValue
        selectedModel = conversation.selectedModel
        folderId = conversation.folderId?.uuidString
        projectId = conversation.projectId?.uuidString
        if conversation.tags.isEmpty {
            tags = nil
        } else if let data = try? JSONEncoder().encode(conversation.tags) {
            tags = String(data: data, encoding: .utf8)
        } else {
            tags = nil
        }
        isFavorite = conversation.isFavorite
    }

    func asModel() -> Conversation {
        var decodedTags: [String] = []
        if let tagsData = tags?.data(using: .utf8),
           let tagsArray = try? JSONDecoder().decode([String].self, from: tagsData) {
            decodedTags = tagsArray
        }

        return Conversation(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            summary: summary,
            createdAt: Date(timeIntervalSince1970: createdAt),
            lastUsedAt: Date(timeIntervalSince1970: lastUsedAt),
            messageCount: messageCount,
            isArchived: isArchived,
            selectedProvider: selectedProvider.flatMap { LLMProvider(rawValue: $0) },
            selectedModel: selectedModel,
            folderId: folderId.flatMap { UUID(uuidString: $0) },
            projectId: projectId.flatMap { UUID(uuidString: $0) },
            tags: decodedTags,
            isFavorite: isFavorite
        )
    }
}

extension MessageRecord {
    init(_ message: Message) {
        id = message.id.uuidString
        conversationId = message.conversationId.uuidString
        role = message.role.rawValue
        content = message.content
        createdAt = message.timestamp.timeIntervalSince1970
        toolCallId = message.toolCallId
        toolName = message.toolName
    }

    func asModel(attachments: [AttachmentRecord]) -> Message {
        let messageAttachments = attachments.map { $0.asModel() }
        let role = MessageRole(rawValue: role) ?? .assistant
        return Message(
            id: UUID(uuidString: id) ?? UUID(),
            conversationId: UUID(uuidString: conversationId) ?? UUID(),
            role: role,
            content: content,
            timestamp: Date(timeIntervalSince1970: createdAt),
            attachments: messageAttachments.isEmpty ? nil : messageAttachments,
            toolCallId: toolCallId,
            toolName: toolName
        )
    }
}

extension AttachmentRecord {
    init(_ attachment: MessageAttachment, messageId: UUID) {
        id = attachment.id.uuidString
        self.messageId = messageId.uuidString
        mimeType = attachment.mimeType
        filename = attachment.filename
        data = attachment.data
        isImage = attachment.isImage
        byteCount = attachment.data.count
    }

    func asModel() -> MessageAttachment {
        MessageAttachment(
            id: UUID(uuidString: id) ?? UUID(),
            data: data,
            mimeType: mimeType,
            filename: filename
        )
    }
}
