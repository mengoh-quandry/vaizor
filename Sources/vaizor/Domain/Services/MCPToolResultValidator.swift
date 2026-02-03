import Foundation

/// Validates MCP tool results for correctness, safety, and compliance with schemas
@MainActor
class MCPToolResultValidator {
    static let shared = MCPToolResultValidator()

    /// Configuration for validation behavior
    struct ValidationConfig {
        var maxResultSizeBytes: Int = 1_000_000 // 1MB default
        var maxTextLength: Int = 500_000 // 500K characters
        var enforceContentTypes: Bool = true
        var warnOnLargeResults: Bool = true
        var truncateOversizedResults: Bool = true
    }

    var config = ValidationConfig()

    /// Valid content types for MCP results
    enum ContentType: String, CaseIterable {
        case text = "text"
        case image = "image"
        case resource = "resource"
        case artifact = "artifact"
        case error = "error"
        case json = "json"

        static func isValid(_ type: String) -> Bool {
            return ContentType(rawValue: type.lowercased()) != nil
        }
    }

    /// Validation result with detailed feedback
    struct ValidationResult {
        let isValid: Bool
        let warnings: [ValidationWarning]
        let errors: [ValidationError]
        let sanitizedResult: MCPToolResult?

        var hasWarnings: Bool { !warnings.isEmpty }
        var hasErrors: Bool { !errors.isEmpty }

        static func valid(_ result: MCPToolResult, warnings: [ValidationWarning] = []) -> ValidationResult {
            ValidationResult(isValid: true, warnings: warnings, errors: [], sanitizedResult: result)
        }

        static func invalid(errors: [ValidationError], warnings: [ValidationWarning] = []) -> ValidationResult {
            ValidationResult(isValid: false, warnings: warnings, errors: errors, sanitizedResult: nil)
        }
    }

    enum ValidationWarning: CustomStringConvertible {
        case resultTruncated(originalSize: Int, truncatedSize: Int)
        case unknownContentType(String)
        case largeResult(sizeBytes: Int)
        case emptyResult
        case deprecatedFormat

        var description: String {
            switch self {
            case .resultTruncated(let original, let truncated):
                return "Result truncated from \(original) to \(truncated) characters"
            case .unknownContentType(let type):
                return "Unknown content type: \(type)"
            case .largeResult(let size):
                return "Large result: \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .memory))"
            case .emptyResult:
                return "Empty result returned"
            case .deprecatedFormat:
                return "Result uses deprecated format"
            }
        }
    }

    enum ValidationError: LocalizedError, CustomStringConvertible {
        case exceedsMaxSize(size: Int, max: Int)
        case invalidContentType(String)
        case malformedContent(details: String)
        case missingRequiredField(String)
        case schemaViolation(field: String, expected: String, actual: String)
        case securityRisk(String)

        var description: String {
            switch self {
            case .exceedsMaxSize(let size, let max):
                return "Result exceeds maximum size (\(size) > \(max) bytes)"
            case .invalidContentType(let type):
                return "Invalid content type: \(type)"
            case .malformedContent(let details):
                return "Malformed content: \(details)"
            case .missingRequiredField(let field):
                return "Missing required field: \(field)"
            case .schemaViolation(let field, let expected, let actual):
                return "Schema violation: \(field) expected \(expected), got \(actual)"
            case .securityRisk(let details):
                return "Security risk detected: \(details)"
            }
        }

        var errorDescription: String? { description }
    }

    // MARK: - Validation Methods

    /// Validate a tool result with optional schema
    func validate(
        result: MCPToolResult,
        toolName: String,
        schema: [String: Any]? = nil
    ) -> ValidationResult {
        var warnings: [ValidationWarning] = []
        var errors: [ValidationError] = []
        var sanitizedContent: [MCPContent] = []

        // Check for empty result
        if result.content.isEmpty {
            warnings.append(.emptyResult)
            return .valid(result, warnings: warnings)
        }

        // Validate each content item
        for content in result.content {
            // Content type validation
            if config.enforceContentTypes && !ContentType.isValid(content.type) {
                if config.enforceContentTypes {
                    warnings.append(.unknownContentType(content.type))
                }
            }

            // Text content validation
            if let text = content.text {
                let textSize = text.utf8.count

                // Size check
                if textSize > config.maxResultSizeBytes {
                    if config.truncateOversizedResults {
                        // Truncate and warn
                        let truncatedText = String(text.prefix(config.maxTextLength))
                        warnings.append(.resultTruncated(originalSize: text.count, truncatedSize: truncatedText.count))
                        sanitizedContent.append(MCPContent(type: content.type, text: truncatedText + "\n\n[... Result truncated due to size ...]"))
                        continue
                    } else {
                        errors.append(.exceedsMaxSize(size: textSize, max: config.maxResultSizeBytes))
                    }
                }

                // Large result warning
                if config.warnOnLargeResults && textSize > 100_000 {
                    warnings.append(.largeResult(sizeBytes: textSize))
                }

                // Security check for suspicious patterns
                if let securityIssue = checkForSecurityRisks(text, toolName: toolName) {
                    warnings.append(.unknownContentType("security_flagged"))
                    AppLogger.shared.log("Security warning in tool result: \(securityIssue)", level: .warning)
                }
            }

            sanitizedContent.append(content)
        }

        // Return validation result
        if !errors.isEmpty {
            return .invalid(errors: errors, warnings: warnings)
        }

        let sanitizedResult = MCPToolResult(content: sanitizedContent, isError: result.isError)
        return .valid(sanitizedResult, warnings: warnings)
    }

    /// Validate result against a JSON schema
    func validateAgainstSchema(
        result: MCPToolResult,
        schema: [String: Any]
    ) -> ValidationResult {
        var errors: [ValidationError] = []

        // Extract the text content as JSON if possible
        for content in result.content {
            guard let text = content.text,
                  let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Validate required properties
            if let required = schema["required"] as? [String] {
                for field in required {
                    if json[field] == nil {
                        errors.append(.missingRequiredField(field))
                    }
                }
            }

            // Validate property types
            if let properties = schema["properties"] as? [String: [String: Any]] {
                for (field, fieldSchema) in properties {
                    if let value = json[field], let expectedType = fieldSchema["type"] as? String {
                        let actualType = jsonType(of: value)
                        if actualType != expectedType && expectedType != "any" {
                            errors.append(.schemaViolation(field: field, expected: expectedType, actual: actualType))
                        }
                    }
                }
            }
        }

        if errors.isEmpty {
            return .valid(result)
        }
        return .invalid(errors: errors)
    }

    // MARK: - Helper Methods

    private func jsonType(of value: Any) -> String {
        switch value {
        case is String: return "string"
        case is Int, is Double, is Float: return "number"
        case is Bool: return "boolean"
        case is [Any]: return "array"
        case is [String: Any]: return "object"
        case is NSNull: return "null"
        default: return "unknown"
        }
    }

    private func checkForSecurityRisks(_ text: String, toolName: String) -> String? {
        // Check for potential command injection in results
        let suspiciousPatterns = [
            "\\$\\([^)]+\\)",           // Command substitution
            "`[^`]+`",                   // Backtick execution
            "eval\\s*\\(",               // Eval calls
            "exec\\s*\\(",               // Exec calls
            "system\\s*\\(",             // System calls
            "<script[^>]*>",             // Script tags
            "javascript:",               // JavaScript URLs
            "data:text/html",            // Data URLs
        ]

        for pattern in suspiciousPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, range: range) != nil {
                    return "Suspicious pattern detected: \(pattern)"
                }
            }
        }

        return nil
    }

    /// Validate artifact result structure
    func validateArtifactResult(_ content: MCPContent) -> ValidationResult {
        guard content.type == "artifact",
              let text = content.text,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .invalid(errors: [.malformedContent(details: "Invalid artifact JSON")])
        }

        var errors: [ValidationError] = []

        // Required fields for artifacts
        let requiredFields = ["artifact_type", "artifact_title", "artifact_content"]
        for field in requiredFields {
            if json[field] == nil {
                errors.append(.missingRequiredField(field))
            }
        }

        // Validate artifact type
        if let type = json["artifact_type"] as? String {
            let validTypes = ["code", "markdown", "html", "svg", "mermaid", "react"]
            if !validTypes.contains(type) {
                errors.append(.schemaViolation(field: "artifact_type", expected: validTypes.joined(separator: "|"), actual: type))
            }
        }

        if errors.isEmpty {
            return .valid(MCPToolResult(content: [content], isError: false))
        }
        return .invalid(errors: errors)
    }
}

// MARK: - MCPServerManager Integration Extension

extension MCPServerManager {
    /// Call tool with validation
    func callToolWithValidation(
        toolName: String,
        arguments: [String: Any],
        conversationId: UUID? = nil,
        schema: [String: Any]? = nil
    ) async -> (result: MCPToolResult, validation: MCPToolResultValidator.ValidationResult) {
        let result = await callTool(toolName: toolName, arguments: arguments, conversationId: conversationId)
        let validation = await MCPToolResultValidator.shared.validate(
            result: result,
            toolName: toolName,
            schema: schema
        )

        // Log validation issues
        if validation.hasWarnings {
            for warning in validation.warnings {
                AppLogger.shared.log("Tool result warning [\(toolName)]: \(warning)", level: .warning)
            }
        }

        if validation.hasErrors {
            for error in validation.errors {
                AppLogger.shared.log("Tool result error [\(toolName)]: \(error)", level: .error)
            }
        }

        // Return sanitized result if available
        if let sanitized = validation.sanitizedResult {
            return (sanitized, validation)
        }
        return (result, validation)
    }
}
