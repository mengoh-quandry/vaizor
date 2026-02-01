import Foundation

/// Parses markdown-style artifact syntax from LLM responses
/// Syntax: :::artifact{identifier="id" type="type" title="Title"}
/// ```
/// content
/// ```
/// :::
struct ArtifactParser {

    /// Parsed artifact from markdown
    struct ParsedArtifact {
        let identifier: String
        let type: ArtifactType
        let title: String
        let content: String
    }

    /// Map LibreChat-style MIME types to Vaizor ArtifactType
    private static let typeMapping: [String: ArtifactType] = [
        "application/vnd.react": .react,
        "text/html": .html,
        "image/svg+xml": .svg,
        "application/vnd.mermaid": .mermaid,
        "text/markdown": .html, // Render markdown as HTML
        "text/md": .html,
        "react": .react,
        "html": .html,
        "svg": .svg,
        "mermaid": .mermaid,
        "canvas": .canvas,
        "three": .three,
        "slides": .presentation,
        "animation": .animation,
        "sketch": .sketch,
        "d3": .d3,
    ]

    /// Parse all artifacts from a markdown string
    /// - Parameter markdown: The markdown string to parse
    /// - Returns: Array of parsed artifacts and the cleaned markdown (with artifacts removed)
    static func parse(_ markdown: String) -> (artifacts: [ParsedArtifact], cleanedText: String) {
        var artifacts: [ParsedArtifact] = []
        var cleanedText = markdown

        // Pattern: :::artifact{identifier="..." type="..." title="..."}
        // ```
        // content
        // ```
        // :::
        let pattern = #":::artifact\{([^}]+)\}\s*```(?:\w+)?\s*([\s\S]*?)```\s*:::"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return ([], markdown)
        }

        let nsString = markdown as NSString
        let matches = regex.matches(in: markdown, options: [], range: NSRange(location: 0, length: nsString.length))

        // Process matches in reverse order to maintain correct positions when removing
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }

            let attributesRange = match.range(at: 1)
            let contentRange = match.range(at: 2)

            let attributesString = nsString.substring(with: attributesRange)
            let content = nsString.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse attributes
            if let parsed = parseAttributes(attributesString, content: content) {
                artifacts.insert(parsed, at: 0) // Insert at beginning since we're processing in reverse
            }

            // Remove the artifact block from cleaned text
            if let range = Range(match.range, in: cleanedText) {
                cleanedText.replaceSubrange(range, with: "")
            }
        }

        // Clean up extra whitespace
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanedText = cleanedText.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)

        return (artifacts, cleanedText)
    }

    /// Parse attribute string like: identifier="id" type="react" title="Title"
    private static func parseAttributes(_ attributes: String, content: String) -> ParsedArtifact? {
        var identifier: String?
        var typeString: String?
        var title: String?

        // Parse key="value" pairs
        let attrPattern = #"(\w+)\s*=\s*"([^"]*)""#
        guard let attrRegex = try? NSRegularExpression(pattern: attrPattern, options: []) else {
            return nil
        }

        let nsAttrs = attributes as NSString
        let attrMatches = attrRegex.matches(in: attributes, options: [], range: NSRange(location: 0, length: nsAttrs.length))

        for attrMatch in attrMatches {
            guard attrMatch.numberOfRanges >= 3 else { continue }
            let key = nsAttrs.substring(with: attrMatch.range(at: 1)).lowercased()
            let value = nsAttrs.substring(with: attrMatch.range(at: 2))

            switch key {
            case "identifier", "id":
                identifier = value
            case "type":
                typeString = value
            case "title":
                title = value
            default:
                break
            }
        }

        // Validate required fields
        guard let id = identifier ?? title?.lowercased().replacingOccurrences(of: " ", with: "-"),
              let typeStr = typeString,
              let artifactType = typeMapping[typeStr.lowercased()],
              let artifactTitle = title ?? identifier else {
            return nil
        }

        return ParsedArtifact(
            identifier: id,
            type: artifactType,
            title: artifactTitle,
            content: content
        )
    }

    /// Check if a string contains any artifact markers
    static func containsArtifacts(_ text: String) -> Bool {
        return text.contains(":::artifact{")
    }

    /// Convert ParsedArtifact to Vaizor Artifact model
    static func toArtifact(_ parsed: ParsedArtifact) -> Artifact {
        return Artifact(
            type: parsed.type,
            title: parsed.title,
            content: parsed.content,
            language: parsed.type.rawValue
        )
    }
}

// MARK: - Integration with ChatViewModel

extension ArtifactParser {
    /// Process an LLM response, extracting any markdown artifacts
    /// Returns the cleaned text and any artifacts found
    static func processResponse(_ response: String) -> (text: String, artifacts: [Artifact]) {
        guard containsArtifacts(response) else {
            return (response, [])
        }

        let (parsedArtifacts, cleanedText) = parse(response)
        let artifacts = parsedArtifacts.map { toArtifact($0) }

        return (cleanedText, artifacts)
    }
}
