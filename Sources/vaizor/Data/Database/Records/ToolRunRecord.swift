import Foundation
import GRDB

/// Database record for tool execution history
struct ToolRunRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tool_runs"

    var id: String
    var conversationId: String
    var messageId: String?
    var toolName: String
    var toolServerId: String?
    var toolServerName: String?
    var inputJson: String?
    var outputJson: String?
    var isError: Bool
    var createdAt: Double

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case messageId = "message_id"
        case toolName = "tool_name"
        case toolServerId = "tool_server_id"
        case toolServerName = "tool_server_name"
        case inputJson = "input_json"
        case outputJson = "output_json"
        case isError = "is_error"
        case createdAt = "created_at"
    }
}

// MARK: - Model Conversion

extension ToolRunRecord {
    /// Create a record from a tool run model
    init(_ toolRun: ToolRun) {
        id = toolRun.id.uuidString
        conversationId = toolRun.conversationId.uuidString
        messageId = toolRun.messageId?.uuidString
        toolName = toolRun.toolName
        toolServerId = toolRun.toolServerId
        toolServerName = toolRun.toolServerName
        inputJson = toolRun.inputJson
        outputJson = toolRun.outputJson
        isError = toolRun.isError
        createdAt = toolRun.createdAt.timeIntervalSince1970
    }

    /// Convert record to domain model
    func asModel() -> ToolRun {
        ToolRun(
            id: UUID(uuidString: id) ?? UUID(),
            conversationId: UUID(uuidString: conversationId) ?? UUID(),
            messageId: messageId.flatMap { UUID(uuidString: $0) },
            toolName: toolName,
            toolServerId: toolServerId,
            toolServerName: toolServerName,
            inputJson: inputJson,
            outputJson: outputJson,
            isError: isError,
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }
}

// MARK: - Tool Run Domain Model

/// Domain model for tool execution history
struct ToolRun: Identifiable, Sendable {
    let id: UUID
    let conversationId: UUID
    let messageId: UUID?
    let toolName: String
    let toolServerId: String?
    let toolServerName: String?
    let inputJson: String?
    let outputJson: String?
    let isError: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        conversationId: UUID,
        messageId: UUID? = nil,
        toolName: String,
        toolServerId: String? = nil,
        toolServerName: String? = nil,
        inputJson: String? = nil,
        outputJson: String? = nil,
        isError: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.conversationId = conversationId
        self.messageId = messageId
        self.toolName = toolName
        self.toolServerId = toolServerId
        self.toolServerName = toolServerName
        self.inputJson = inputJson
        self.outputJson = outputJson
        self.isError = isError
        self.createdAt = createdAt
    }

    /// Create from tool execution context
    static func fromExecution(
        conversationId: UUID,
        messageId: UUID? = nil,
        toolName: String,
        serverId: String? = nil,
        serverName: String? = nil,
        arguments: [String: Any],
        result: MCPToolResult
    ) -> ToolRun {
        var inputJson: String? = nil
        if let data = try? JSONSerialization.data(withJSONObject: arguments) {
            inputJson = String(data: data, encoding: .utf8)
        }

        let outputText = result.content.compactMap { $0.text }.joined(separator: "\n")

        return ToolRun(
            conversationId: conversationId,
            messageId: messageId,
            toolName: toolName,
            toolServerId: serverId,
            toolServerName: serverName,
            inputJson: inputJson,
            outputJson: outputText,
            isError: result.isError
        )
    }
}
