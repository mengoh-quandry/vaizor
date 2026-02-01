import Foundation

// MARK: - Project Model

struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    var conversations: [UUID]  // Linked conversation IDs
    var context: ProjectContext
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var iconName: String?  // SF Symbol name for project icon
    var color: String?     // Hex color code

    init(
        id: UUID = UUID(),
        name: String,
        conversations: [UUID] = [],
        context: ProjectContext = ProjectContext(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        iconName: String? = "folder.fill",
        color: String? = "00976d"
    ) {
        self.id = id
        self.name = name
        self.conversations = conversations
        self.context = context
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.iconName = iconName
        self.color = color
    }
}

// MARK: - Project Context

struct ProjectContext: Codable {
    var systemPrompt: String?
    var files: [ProjectFile]           // Attached reference files
    var instructions: [String]         // Custom instructions
    var mcpServers: [UUID]             // Project-specific MCP servers
    var memory: [MemoryEntry]          // Persistent memory entries
    var preferredProvider: String?     // Preferred LLM provider for this project
    var preferredModel: String?        // Preferred model for this project

    init(
        systemPrompt: String? = nil,
        files: [ProjectFile] = [],
        instructions: [String] = [],
        mcpServers: [UUID] = [],
        memory: [MemoryEntry] = [],
        preferredProvider: String? = nil,
        preferredModel: String? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.files = files
        self.instructions = instructions
        self.mcpServers = mcpServers
        self.memory = memory
        self.preferredProvider = preferredProvider
        self.preferredModel = preferredModel
    }
}

// MARK: - Project File

struct ProjectFile: Identifiable, Codable {
    let id: UUID
    var name: String
    var path: String?        // For file references on disk
    var content: String?     // For embedded content
    var type: FileType
    var addedAt: Date
    var sizeBytes: Int?

    init(
        id: UUID = UUID(),
        name: String,
        path: String? = nil,
        content: String? = nil,
        type: FileType = .text,
        addedAt: Date = Date(),
        sizeBytes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.content = content
        self.type = type
        self.addedAt = addedAt
        self.sizeBytes = sizeBytes
    }

    enum FileType: String, Codable, CaseIterable {
        case text = "text"
        case code = "code"
        case markdown = "markdown"
        case json = "json"
        case pdf = "pdf"
        case image = "image"
        case data = "data"

        var iconName: String {
            switch self {
            case .text: return "doc.text"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .markdown: return "text.badge.checkmark"
            case .json: return "curlybraces"
            case .pdf: return "doc.richtext"
            case .image: return "photo"
            case .data: return "doc"
            }
        }

        static func from(filename: String) -> FileType {
            let ext = (filename as NSString).pathExtension.lowercased()
            switch ext {
            case "txt": return .text
            case "md", "markdown": return .markdown
            case "json": return .json
            case "pdf": return .pdf
            case "png", "jpg", "jpeg", "gif", "webp", "heic": return .image
            case "swift", "py", "js", "ts", "go", "rs", "java", "kt", "rb", "cpp", "c", "h", "cs", "php", "html", "css", "sql":
                return .code
            default: return .data
            }
        }
    }
}

// MARK: - Memory Entry

struct MemoryEntry: Identifiable, Codable {
    let id: UUID
    var key: String
    var value: String
    var createdAt: Date
    var source: MemorySource
    var conversationId: UUID?  // Optional link to originating conversation
    var confidence: Double?    // For auto-extracted memories (0.0-1.0)
    var isActive: Bool         // Whether this memory is currently used

    init(
        id: UUID = UUID(),
        key: String,
        value: String,
        createdAt: Date = Date(),
        source: MemorySource = .user,
        conversationId: UUID? = nil,
        confidence: Double? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.createdAt = createdAt
        self.source = source
        self.conversationId = conversationId
        self.confidence = confidence
        self.isActive = isActive
    }
}

enum MemorySource: String, Codable, CaseIterable {
    case user = "user"           // Manually added by user
    case conversation = "conversation"  // Extracted from conversation
    case auto = "auto"           // Auto-detected by system

    var displayName: String {
        switch self {
        case .user: return "Manual"
        case .conversation: return "From Chat"
        case .auto: return "Auto-detected"
        }
    }

    var iconName: String {
        switch self {
        case .user: return "person.fill"
        case .conversation: return "bubble.left.and.bubble.right.fill"
        case .auto: return "sparkles"
        }
    }
}
