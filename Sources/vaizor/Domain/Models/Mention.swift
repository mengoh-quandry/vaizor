import Foundation

/// Types of mentions that can be used in chat input
enum MentionType: String, Codable, CaseIterable {
    case file
    case folder
    case url
    case project

    var prefix: String {
        switch self {
        case .file: return "@file:"
        case .folder: return "@folder:"
        case .url: return "@url:"
        case .project: return "@project:"
        }
    }

    var icon: String {
        switch self {
        case .file: return "doc.fill"
        case .folder: return "folder.fill"
        case .url: return "link"
        case .project: return "folder.badge.gearshape"
        }
    }

    var displayName: String {
        switch self {
        case .file: return "File"
        case .folder: return "Folder"
        case .url: return "URL"
        case .project: return "Project"
        }
    }

    var color: String {
        switch self {
        case .file: return "5a9bd5"      // Blue
        case .folder: return "d4a017"    // Gold
        case .url: return "9c7bea"       // Purple
        case .project: return "00976d"   // Green (accent)
        }
    }
}

/// Represents a mention in the chat input
struct Mention: Identifiable, Equatable {
    let id: UUID
    let type: MentionType
    let value: String           // The path, URL, or project name
    let displayName: String     // Short name shown in the pill
    let resolvedContent: String? // The actual content (populated when resolved)
    let tokenCount: Int?        // Estimated token count of resolved content
    let range: Range<String.Index>? // Range in the input text (transient, not persisted)

    init(
        id: UUID = UUID(),
        type: MentionType,
        value: String,
        displayName: String? = nil,
        resolvedContent: String? = nil,
        tokenCount: Int? = nil,
        range: Range<String.Index>? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.displayName = displayName ?? Self.extractDisplayName(from: value, type: type)
        self.resolvedContent = resolvedContent
        self.tokenCount = tokenCount
        self.range = range
    }

    // Custom Codable implementation to exclude non-codable range property
    enum CodingKeys: String, CodingKey {
        case id, type, value, displayName, resolvedContent, tokenCount
    }
}

extension Mention: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(MentionType.self, forKey: .type)
        value = try container.decode(String.self, forKey: .value)
        displayName = try container.decode(String.self, forKey: .displayName)
        resolvedContent = try container.decodeIfPresent(String.self, forKey: .resolvedContent)
        tokenCount = try container.decodeIfPresent(Int.self, forKey: .tokenCount)
        range = nil // Range is transient and not persisted
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(value, forKey: .value)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(resolvedContent, forKey: .resolvedContent)
        try container.encodeIfPresent(tokenCount, forKey: .tokenCount)
    }

    /// Extracts a short display name from the full value
    static func extractDisplayName(from value: String, type: MentionType) -> String {
        switch type {
        case .file:
            return URL(fileURLWithPath: value).lastPathComponent
        case .folder:
            let url = URL(fileURLWithPath: value)
            return url.lastPathComponent.isEmpty ? value : url.lastPathComponent
        case .url:
            if let url = URL(string: value), let host = url.host {
                return host
            }
            return value.prefix(30).description
        case .project:
            return value
        }
    }

    /// Returns the full mention string as it appears in input
    var fullMentionString: String {
        "\(type.prefix)\(value)"
    }

    static func == (lhs: Mention, rhs: Mention) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents a mentionable item that can be suggested
struct MentionableItem: Identifiable {
    let id: UUID
    let type: MentionType
    let value: String
    let displayName: String
    let subtitle: String?
    let icon: String
    let isRecent: Bool
    let lastAccessed: Date?
    let fileSize: Int64?

    init(
        id: UUID = UUID(),
        type: MentionType,
        value: String,
        displayName: String? = nil,
        subtitle: String? = nil,
        icon: String? = nil,
        isRecent: Bool = false,
        lastAccessed: Date? = nil,
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.displayName = displayName ?? Mention.extractDisplayName(from: value, type: type)
        self.subtitle = subtitle
        self.icon = icon ?? Self.iconForPath(value, type: type)
        self.isRecent = isRecent
        self.lastAccessed = lastAccessed
        self.fileSize = fileSize
    }

    /// Returns an appropriate icon based on file extension
    static func iconForPath(_ path: String, type: MentionType) -> String {
        guard type == .file else { return type.icon }

        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "swift":
            return "swift"
        case "py":
            return "circle.hexagonpath.fill"
        case "js", "ts", "jsx", "tsx":
            return "curlybraces"
        case "html", "htm":
            return "chevron.left.forwardslash.chevron.right"
        case "css", "scss", "sass":
            return "paintbrush.fill"
        case "json":
            return "curlybraces.square.fill"
        case "md", "markdown":
            return "doc.richtext.fill"
        case "txt":
            return "doc.text.fill"
        case "pdf":
            return "doc.fill"
        case "png", "jpg", "jpeg", "gif", "svg", "webp":
            return "photo.fill"
        case "yaml", "yml":
            return "list.bullet.rectangle"
        case "xml":
            return "chevron.left.forwardslash.chevron.right"
        case "sh", "bash", "zsh":
            return "terminal.fill"
        case "rs":
            return "gearshape.2.fill"
        case "go":
            return "forward.fill"
        case "java", "kt", "kotlin":
            return "cup.and.saucer.fill"
        case "rb":
            return "diamond.fill"
        case "php":
            return "p.circle.fill"
        case "c", "h":
            return "c.circle.fill"
        case "cpp", "hpp", "cc":
            return "plus.circle.fill"
        case "cs":
            return "number.circle.fill"
        default:
            return "doc.fill"
        }
    }

    /// Returns a color based on file extension
    static func colorForPath(_ path: String, type: MentionType) -> String {
        guard type == .file else { return type.color }

        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "swift":
            return "f05138" // Swift orange
        case "py":
            return "3776ab" // Python blue
        case "js":
            return "f7df1e" // JS yellow
        case "ts", "tsx":
            return "3178c6" // TS blue
        case "html", "htm":
            return "e34f26" // HTML orange
        case "css", "scss":
            return "264de4" // CSS blue
        case "json":
            return "d4a017" // Gold
        case "md", "markdown":
            return "5a9bd5" // Markdown blue
        case "rs":
            return "dea584" // Rust orange
        case "go":
            return "00add8" // Go cyan
        default:
            return "5a9bd5" // Default blue
        }
    }
}

/// Result of resolving a mention to its content
struct ResolvedMention {
    let mention: Mention
    let content: String
    let tokenCount: Int
    let error: String?

    var isSuccess: Bool {
        error == nil
    }
}

extension Mention {
    /// Create a Mention from a MentionReference (for edit/regenerate scenarios)
    init(from reference: MentionReference) {
        self.id = reference.id
        self.type = reference.type
        self.value = reference.value
        self.displayName = reference.displayName
        self.resolvedContent = nil  // Content needs to be re-resolved if needed
        self.tokenCount = reference.tokenCount
        self.range = nil
    }
}

/// Context that will be injected into the message
struct MentionContext: Codable {
    let mentions: [Mention]
    let totalTokens: Int
    let warnings: [String]

    /// Generates the context string to inject into the message
    func generateContextString() -> String {
        var parts: [String] = []

        for mention in mentions {
            guard let content = mention.resolvedContent else { continue }

            let header: String
            switch mention.type {
            case .file:
                header = "--- File: \(mention.value) ---"
            case .folder:
                header = "--- Folder Contents: \(mention.value) ---"
            case .url:
                header = "--- URL Content: \(mention.value) ---"
            case .project:
                header = "--- Project Context: \(mention.value) ---"
            }

            parts.append("""
            \(header)
            \(content)
            --- End ---
            """)
        }

        if parts.isEmpty {
            return ""
        }

        return """
        [Referenced Context]
        \(parts.joined(separator: "\n\n"))
        [End of Context]

        """
    }
}
