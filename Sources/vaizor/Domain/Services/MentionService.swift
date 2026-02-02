import Foundation
import AppKit

/// Service for handling @-mentions in chat input
@MainActor
class MentionService: ObservableObject {
    static let shared = MentionService()

    /// Recently accessed files for quick suggestions
    @Published var recentFiles: [MentionableItem] = []

    /// Currently active project paths
    @Published var projectPaths: [String] = []

    /// Maximum file size to read (in bytes) - 1MB default
    let maxFileSize: Int64 = 1_048_576

    /// Maximum folder depth to scan
    let maxFolderDepth: Int = 3

    /// Estimated tokens per character (rough estimate)
    private let tokensPerChar: Double = 0.25

    private init() {
        loadRecentFiles()
    }

    // MARK: - Mention Detection

    /// Detects mentions in the input text
    func detectMentions(in text: String) -> [Mention] {
        var mentions: [Mention] = []

        // Pattern to match @type:value mentions
        let pattern = #"@(file|folder|url|project):([^\s]+)"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let typeRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text),
                  let fullRange = Range(match.range, in: text) else {
                continue
            }

            let typeString = String(text[typeRange])
            let value = String(text[valueRange])

            guard let type = MentionType(rawValue: typeString) else { continue }

            let mention = Mention(
                type: type,
                value: value,
                range: fullRange
            )
            mentions.append(mention)
        }

        return mentions
    }

    /// Checks if text contains an incomplete mention being typed
    func detectIncompleteMention(in text: String, cursorPosition: Int) -> (type: MentionType?, searchText: String)? {
        let index = text.index(text.startIndex, offsetBy: min(cursorPosition, text.count))
        let beforeCursor = String(text[..<index])

        // Look for @ at the end or @type: pattern
        let patterns: [(String, MentionType?)] = [
            (#"@file:([^\s]*)$"#, .file),
            (#"@folder:([^\s]*)$"#, .folder),
            (#"@url:([^\s]*)$"#, .url),
            (#"@project:([^\s]*)$"#, .project),
            (#"@([^\s:]*)$"#, nil)  // Just @ with partial text
        ]

        for (pattern, type) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: beforeCursor, options: [], range: NSRange(beforeCursor.startIndex..., in: beforeCursor)) {

                if match.numberOfRanges >= 2,
                   let searchRange = Range(match.range(at: 1), in: beforeCursor) {
                    return (type, String(beforeCursor[searchRange]))
                }
                return (type, "")
            }
        }

        return nil
    }

    // MARK: - Suggestion Generation

    /// Generates suggestions based on the current mention type and search text
    func generateSuggestions(type: MentionType?, searchText: String) async -> [MentionableItem] {
        var items: [MentionableItem] = []

        // If no specific type, show all types as options
        if type == nil {
            items = MentionType.allCases.filter { mentionType in
                searchText.isEmpty || mentionType.rawValue.lowercased().contains(searchText.lowercased())
            }.map { mentionType in
                MentionableItem(
                    type: mentionType,
                    value: mentionType.prefix,
                    displayName: mentionType.displayName,
                    subtitle: "Add \(mentionType.displayName.lowercased()) context",
                    icon: mentionType.icon
                )
            }

            // Also add recent files if search is empty or matches
            if searchText.isEmpty {
                let recent = recentFiles.prefix(5).map { item in
                    MentionableItem(
                        id: item.id,
                        type: item.type,
                        value: item.value,
                        displayName: item.displayName,
                        subtitle: item.subtitle,
                        icon: item.icon,
                        isRecent: true,
                        lastAccessed: item.lastAccessed
                    )
                }
                items.append(contentsOf: recent)
            }

            return items
        }

        // Generate suggestions based on type
        switch type {
        case .file:
            items = await searchFiles(query: searchText)
        case .folder:
            items = await searchFolders(query: searchText)
        case .url:
            items = generateURLSuggestions(query: searchText)
        case .project:
            items = searchProjects(query: searchText)
        case .none:
            break
        }

        return items
    }

    /// Searches for files matching the query
    private func searchFiles(query: String) async -> [MentionableItem] {
        var results: [MentionableItem] = []

        // Start with recent files that match
        let matchingRecent = recentFiles.filter { item in
            item.type == .file && (query.isEmpty ||
                item.displayName.lowercased().contains(query.lowercased()) ||
                item.value.lowercased().contains(query.lowercased()))
        }
        results.append(contentsOf: matchingRecent.prefix(3))

        // If query looks like a path, try to complete it
        if query.hasPrefix("/") || query.hasPrefix("~") || query.contains("/") {
            let expandedPath = (query as NSString).expandingTildeInPath
            let directoryPath: String
            let filePrefix: String

            if FileManager.default.fileExists(atPath: expandedPath) {
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)

                if isDirectory.boolValue {
                    directoryPath = expandedPath
                    filePrefix = ""
                } else {
                    directoryPath = (expandedPath as NSString).deletingLastPathComponent
                    filePrefix = (expandedPath as NSString).lastPathComponent
                }
            } else {
                directoryPath = (expandedPath as NSString).deletingLastPathComponent
                filePrefix = (expandedPath as NSString).lastPathComponent
            }

            if let contents = try? FileManager.default.contentsOfDirectory(atPath: directoryPath) {
                let filtered = contents.filter { name in
                    !name.hasPrefix(".") && (filePrefix.isEmpty || name.lowercased().hasPrefix(filePrefix.lowercased()))
                }

                for name in filtered.prefix(10) {
                    let fullPath = (directoryPath as NSString).appendingPathComponent(name)
                    var isDirectory: ObjCBool = false
                    FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory)

                    if !isDirectory.boolValue {
                        let attributes = try? FileManager.default.attributesOfItem(atPath: fullPath)
                        let size = attributes?[.size] as? Int64

                        results.append(MentionableItem(
                            type: .file,
                            value: fullPath,
                            displayName: name,
                            subtitle: directoryPath,
                            fileSize: size
                        ))
                    }
                }
            }
        }

        // Also search in current working directory
        if let currentDir = FileManager.default.currentDirectoryPath as String?,
           !query.hasPrefix("/") && !query.hasPrefix("~") {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: currentDir) {
                let filtered = contents.filter { name in
                    !name.hasPrefix(".") && (query.isEmpty || name.lowercased().contains(query.lowercased()))
                }

                for name in filtered.prefix(5) {
                    let fullPath = (currentDir as NSString).appendingPathComponent(name)
                    var isDirectory: ObjCBool = false
                    FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory)

                    if !isDirectory.boolValue && !results.contains(where: { $0.value == fullPath }) {
                        let attributes = try? FileManager.default.attributesOfItem(atPath: fullPath)
                        let size = attributes?[.size] as? Int64

                        results.append(MentionableItem(
                            type: .file,
                            value: fullPath,
                            displayName: name,
                            subtitle: "Current directory",
                            fileSize: size
                        ))
                    }
                }
            }
        }

        return results
    }

    /// Searches for folders matching the query
    private func searchFolders(query: String) async -> [MentionableItem] {
        var results: [MentionableItem] = []

        // If query looks like a path, try to complete it
        let expandedPath = (query as NSString).expandingTildeInPath
        let directoryPath: String
        let folderPrefix: String

        if query.isEmpty {
            directoryPath = FileManager.default.currentDirectoryPath
            folderPrefix = ""
        } else if FileManager.default.fileExists(atPath: expandedPath) {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                directoryPath = expandedPath
                folderPrefix = ""
            } else {
                directoryPath = (expandedPath as NSString).deletingLastPathComponent
                folderPrefix = (expandedPath as NSString).lastPathComponent
            }
        } else {
            directoryPath = (expandedPath as NSString).deletingLastPathComponent
            folderPrefix = (expandedPath as NSString).lastPathComponent
        }

        if let contents = try? FileManager.default.contentsOfDirectory(atPath: directoryPath) {
            let filtered = contents.filter { name in
                !name.hasPrefix(".") && (folderPrefix.isEmpty || name.lowercased().hasPrefix(folderPrefix.lowercased()))
            }

            for name in filtered.prefix(15) {
                let fullPath = (directoryPath as NSString).appendingPathComponent(name)
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory)

                if isDirectory.boolValue {
                    // Count items in folder
                    let itemCount = (try? FileManager.default.contentsOfDirectory(atPath: fullPath).count) ?? 0

                    results.append(MentionableItem(
                        type: .folder,
                        value: fullPath,
                        displayName: name,
                        subtitle: "\(itemCount) items"
                    ))
                }
            }
        }

        return results
    }

    /// Generates URL suggestions
    private func generateURLSuggestions(query: String) -> [MentionableItem] {
        var results: [MentionableItem] = []

        // If it looks like a URL, suggest it directly
        if query.hasPrefix("http://") || query.hasPrefix("https://") {
            results.append(MentionableItem(
                type: .url,
                value: query,
                displayName: URL(string: query)?.host ?? query,
                subtitle: "Fetch URL content"
            ))
        } else if !query.isEmpty {
            // Suggest adding https://
            results.append(MentionableItem(
                type: .url,
                value: "https://\(query)",
                displayName: query,
                subtitle: "https://\(query)"
            ))
        }

        // Add common URL patterns
        let commonDomains = [
            ("github.com", "GitHub repository"),
            ("stackoverflow.com", "Stack Overflow"),
            ("developer.apple.com", "Apple Developer"),
            ("docs.swift.org", "Swift Documentation")
        ]

        for (domain, description) in commonDomains {
            if query.isEmpty || domain.contains(query.lowercased()) {
                results.append(MentionableItem(
                    type: .url,
                    value: "https://\(domain)/",
                    displayName: domain,
                    subtitle: description
                ))
            }
        }

        return results
    }

    /// Searches for projects
    private func searchProjects(query: String) -> [MentionableItem] {
        var results: [MentionableItem] = []

        // Add registered project paths
        for path in projectPaths {
            let name = URL(fileURLWithPath: path).lastPathComponent
            if query.isEmpty || name.lowercased().contains(query.lowercased()) {
                results.append(MentionableItem(
                    type: .project,
                    value: path,
                    displayName: name,
                    subtitle: path
                ))
            }
        }

        // Also look for common project indicators in current directory
        let currentDir = FileManager.default.currentDirectoryPath
        let projectIndicators = ["Package.swift", "project.pbxproj", "package.json", "Cargo.toml", "go.mod", "requirements.txt"]

        for indicator in projectIndicators {
            let indicatorPath = (currentDir as NSString).appendingPathComponent(indicator)
            if FileManager.default.fileExists(atPath: indicatorPath) {
                let projectName = URL(fileURLWithPath: currentDir).lastPathComponent
                if query.isEmpty || projectName.lowercased().contains(query.lowercased()) {
                    if !results.contains(where: { $0.value == currentDir }) {
                        results.append(MentionableItem(
                            type: .project,
                            value: currentDir,
                            displayName: projectName,
                            subtitle: "Current project (\(indicator))"
                        ))
                    }
                }
                break
            }
        }

        return results
    }

    // MARK: - Mention Resolution

    /// Resolves all mentions in the context and returns the resolved content
    func resolveMentions(_ mentions: [Mention]) async -> MentionContext {
        var resolvedMentions: [Mention] = []
        var totalTokens = 0
        var warnings: [String] = []

        for mention in mentions {
            let resolved = await resolveMention(mention)

            if let error = resolved.error {
                warnings.append("Failed to resolve \(mention.type.displayName) '\(mention.displayName)': \(error)")
                continue
            }

            let mentionWithContent = Mention(
                id: mention.id,
                type: mention.type,
                value: mention.value,
                displayName: mention.displayName,
                resolvedContent: resolved.content,
                tokenCount: resolved.tokenCount,
                range: mention.range
            )

            resolvedMentions.append(mentionWithContent)
            totalTokens += resolved.tokenCount
        }

        // Warn if context is very large
        if totalTokens > 10000 {
            warnings.append("Warning: Context is very large (~\(totalTokens) tokens). This may impact response quality and cost.")
        }

        return MentionContext(
            mentions: resolvedMentions,
            totalTokens: totalTokens,
            warnings: warnings
        )
    }

    /// Resolves a single mention to its content
    func resolveMention(_ mention: Mention) async -> ResolvedMention {
        switch mention.type {
        case .file:
            return await resolveFileMention(mention)
        case .folder:
            return await resolveFolderMention(mention)
        case .url:
            return await resolveURLMention(mention)
        case .project:
            return await resolveProjectMention(mention)
        }
    }

    private func resolveFileMention(_ mention: Mention) async -> ResolvedMention {
        let expandedPath = (mention.value as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return ResolvedMention(
                mention: mention,
                content: "",
                tokenCount: 0,
                error: "File not found"
            )
        }

        // Check file size
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: expandedPath),
              let size = attributes[.size] as? Int64 else {
            return ResolvedMention(
                mention: mention,
                content: "",
                tokenCount: 0,
                error: "Cannot read file attributes"
            )
        }

        if size > maxFileSize {
            return ResolvedMention(
                mention: mention,
                content: "",
                tokenCount: 0,
                error: "File too large (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))). Maximum: \(ByteCountFormatter.string(fromByteCount: maxFileSize, countStyle: .file))"
            )
        }

        // Read file content
        guard let content = try? String(contentsOfFile: expandedPath, encoding: .utf8) else {
            // Try reading as data and describe
            if let data = try? Data(contentsOf: URL(fileURLWithPath: expandedPath)) {
                return ResolvedMention(
                    mention: mention,
                    content: "[Binary file: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))]",
                    tokenCount: 10,
                    error: nil
                )
            }
            return ResolvedMention(
                mention: mention,
                content: "",
                tokenCount: 0,
                error: "Cannot read file content"
            )
        }

        let tokenCount = estimateTokenCount(content)

        // Add to recent files
        addToRecentFiles(path: expandedPath, type: .file)

        return ResolvedMention(
            mention: mention,
            content: content,
            tokenCount: tokenCount,
            error: nil
        )
    }

    private func resolveFolderMention(_ mention: Mention) async -> ResolvedMention {
        let expandedPath = (mention.value as NSString).expandingTildeInPath

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return ResolvedMention(
                mention: mention,
                content: "",
                tokenCount: 0,
                error: "Folder not found"
            )
        }

        // List folder contents with structure
        var content = "Folder structure:\n"
        content += listFolderContents(path: expandedPath, depth: 0, maxDepth: maxFolderDepth)

        // Optionally include content of key files
        let keyFiles = ["README.md", "Package.swift", "package.json", "Cargo.toml", "go.mod", "main.swift", "index.js", "index.ts"]
        var includedFiles: [String] = []

        for keyFile in keyFiles {
            let keyFilePath = (expandedPath as NSString).appendingPathComponent(keyFile)
            if FileManager.default.fileExists(atPath: keyFilePath) {
                if let fileContent = try? String(contentsOfFile: keyFilePath, encoding: .utf8) {
                    content += "\n\n--- \(keyFile) ---\n\(fileContent)"
                    includedFiles.append(keyFile)
                }
            }
        }

        if !includedFiles.isEmpty {
            content = "Key files included: \(includedFiles.joined(separator: ", "))\n\n" + content
        }

        let tokenCount = estimateTokenCount(content)

        return ResolvedMention(
            mention: mention,
            content: content,
            tokenCount: tokenCount,
            error: nil
        )
    }

    private func listFolderContents(path: String, depth: Int, maxDepth: Int) -> String {
        guard depth <= maxDepth else { return "" }

        let indent = String(repeating: "  ", count: depth)
        var result = ""

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return result
        }

        let sortedContents = contents.sorted()

        for item in sortedContents {
            if item.hasPrefix(".") { continue } // Skip hidden files

            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                result += "\(indent)\(item)/\n"
                result += listFolderContents(path: itemPath, depth: depth + 1, maxDepth: maxDepth)
            } else {
                result += "\(indent)\(item)\n"
            }
        }

        return result
    }

    private func resolveURLMention(_ mention: Mention) async -> ResolvedMention {
        guard let url = URL(string: mention.value) else {
            return ResolvedMention(
                mention: mention,
                content: "",
                tokenCount: 0,
                error: "Invalid URL"
            )
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                return ResolvedMention(
                    mention: mention,
                    content: "",
                    tokenCount: 0,
                    error: "HTTP error: \(statusCode)"
                )
            }

            // Try to extract text content
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""

            if contentType.contains("text/html") {
                // Basic HTML to text conversion
                if let html = String(data: data, encoding: .utf8) {
                    let text = stripHTML(html)
                    let tokenCount = estimateTokenCount(text)
                    return ResolvedMention(
                        mention: mention,
                        content: text,
                        tokenCount: tokenCount,
                        error: nil
                    )
                }
            } else if contentType.contains("text/") || contentType.contains("json") {
                if let text = String(data: data, encoding: .utf8) {
                    let tokenCount = estimateTokenCount(text)
                    return ResolvedMention(
                        mention: mention,
                        content: text,
                        tokenCount: tokenCount,
                        error: nil
                    )
                }
            }

            return ResolvedMention(
                mention: mention,
                content: "[Binary content: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))]",
                tokenCount: 10,
                error: nil
            )
        } catch {
            return ResolvedMention(
                mention: mention,
                content: "",
                tokenCount: 0,
                error: error.localizedDescription
            )
        }
    }

    private func resolveProjectMention(_ mention: Mention) async -> ResolvedMention {
        let expandedPath = (mention.value as NSString).expandingTildeInPath

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return ResolvedMention(
                mention: mention,
                content: "",
                tokenCount: 0,
                error: "Project folder not found"
            )
        }

        var content = "Project: \(URL(fileURLWithPath: expandedPath).lastPathComponent)\n"
        content += "Path: \(expandedPath)\n\n"

        // List folder structure
        content += "Project structure:\n"
        content += listFolderContents(path: expandedPath, depth: 0, maxDepth: 2)

        // Include key project files
        let projectFiles = [
            "README.md",
            "Package.swift",
            "package.json",
            "Cargo.toml",
            "go.mod",
            "pyproject.toml",
            "requirements.txt",
            ".gitignore"
        ]

        for file in projectFiles {
            let filePath = (expandedPath as NSString).appendingPathComponent(file)
            if let fileContent = try? String(contentsOfFile: filePath, encoding: .utf8) {
                content += "\n--- \(file) ---\n\(fileContent)\n"
            }
        }

        let tokenCount = estimateTokenCount(content)

        return ResolvedMention(
            mention: mention,
            content: content,
            tokenCount: tokenCount,
            error: nil
        )
    }

    // MARK: - Helpers

    private func estimateTokenCount(_ text: String) -> Int {
        return Int(Double(text.count) * tokensPerChar)
    }

    private func stripHTML(_ html: String) -> String {
        // Simple HTML stripping - removes tags and decodes entities
        var text = html

        // Remove script and style content
        text = text.replacingOccurrences(of: #"<script[^>]*>[\s\S]*?</script>"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<style[^>]*>[\s\S]*?</style>"#, with: "", options: .regularExpression)

        // Remove tags
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)

        // Decode common entities
        let entities = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'")
        ]

        for (entity, char) in entities {
            text = text.replacingOccurrences(of: entity, with: char)
        }

        // Collapse whitespace
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Recent Files Management

    private func loadRecentFiles() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "MentionService.recentFiles"),
           let items = try? JSONDecoder().decode([RecentFileEntry].self, from: data) {
            recentFiles = items.compactMap { entry in
                // Verify file still exists
                guard FileManager.default.fileExists(atPath: entry.path) else { return nil }
                return MentionableItem(
                    type: entry.type,
                    value: entry.path,
                    displayName: entry.displayName,
                    subtitle: entry.path,
                    isRecent: true,
                    lastAccessed: entry.lastAccessed
                )
            }
        }
    }

    private func saveRecentFiles() {
        let entries = recentFiles.prefix(20).map { item in
            RecentFileEntry(
                path: item.value,
                type: item.type,
                displayName: item.displayName,
                lastAccessed: item.lastAccessed ?? Date()
            )
        }

        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "MentionService.recentFiles")
        }
    }

    func addToRecentFiles(path: String, type: MentionType) {
        // Remove existing entry if present
        recentFiles.removeAll { $0.value == path }

        // Add at the beginning
        let item = MentionableItem(
            type: type,
            value: path,
            isRecent: true,
            lastAccessed: Date()
        )
        recentFiles.insert(item, at: 0)

        // Keep only recent 20
        if recentFiles.count > 20 {
            recentFiles = Array(recentFiles.prefix(20))
        }

        saveRecentFiles()
    }

    /// Registers a project path for suggestions
    func registerProject(path: String) {
        if !projectPaths.contains(path) {
            projectPaths.append(path)
        }
    }
}

// MARK: - Helper Types

private struct RecentFileEntry: Codable {
    let path: String
    let type: MentionType
    let displayName: String
    let lastAccessed: Date
}
