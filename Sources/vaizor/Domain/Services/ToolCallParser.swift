import Foundation

struct ToolCallParser {
    struct ParsedToolCall {
        let name: String
        let arguments: [String: Any]
    }

    private let toolStartToken = "```toolcall"
    private let toolEndToken = "```"

    func parseToolCallJSON(_ jsonString: String) -> ParsedToolCall? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String,
              let arguments = json["arguments"] as? [String: Any] else {
            return nil
        }

        return ParsedToolCall(name: name, arguments: arguments)
    }

    func extractToolCall(from text: String) -> (nonToolText: String, toolCall: ParsedToolCall?) {
        guard let startRange = text.range(of: toolStartToken) else {
            return (text, nil)
        }

        let afterStart = text[startRange.upperBound...]
        guard let endRange = afterStart.range(of: toolEndToken) else {
            return (text, nil)
        }

        let contentStart = afterStart.range(of: "\n")?.upperBound ?? afterStart.startIndex
        let jsonString = String(afterStart[contentStart..<endRange.lowerBound])
        let toolCall = parseToolCallJSON(jsonString)

        let before = text[..<startRange.lowerBound]
        let after = afterStart[endRange.upperBound...]
        var afterString = String(after)
        if before.hasSuffix("\n") && afterString.hasPrefix("\n") {
            afterString.removeFirst()
        }
        let nonToolText = String(before) + afterString

        return (nonToolText, toolCall)
    }

    func splitBufferForToolStart(_ buffer: String) -> (emit: String, remainder: String) {
        let maxSuffixLength = min(buffer.count, toolStartToken.count - 1)
        guard maxSuffixLength > 0 else {
            return (buffer, "")
        }

        for length in stride(from: maxSuffixLength, through: 1, by: -1) {
            let suffix = buffer.suffix(length)
            if toolStartToken.hasPrefix(suffix) {
                let emitCount = buffer.count - length
                return (String(buffer.prefix(emitCount)), String(suffix))
            }
        }

        return (buffer, "")
    }
}
