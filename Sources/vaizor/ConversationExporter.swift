import Foundation
import AppKit

// Conversation export functionality
@MainActor
class ConversationExporter {
    enum ExportFormat {
        case markdown
        case json
        case html
        case plainText
    }
    
    enum ExportError: LocalizedError {
        case noMessages
        case encodingFailed
        case writeFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .noMessages:
                return "No messages to export"
            case .encodingFailed:
                return "Failed to encode conversation data"
            case .writeFailed(let message):
                return "Failed to write file: \(message)"
            }
        }
    }
    
    // Export conversation to file
    func export(
        conversation: Conversation,
        messages: [Message],
        format: ExportFormat
    ) async throws -> URL {
        guard !messages.isEmpty else {
            throw ExportError.noMessages
        }
        
        let content: String
        let fileExtension: String
        
        switch format {
        case .markdown:
            content = exportAsMarkdown(conversation: conversation, messages: messages)
            fileExtension = "md"
        case .json:
            content = try exportAsJSON(conversation: conversation, messages: messages)
            fileExtension = "json"
        case .html:
            content = exportAsHTML(conversation: conversation, messages: messages)
            fileExtension = "html"
        case .plainText:
            content = exportAsPlainText(conversation: conversation, messages: messages)
            fileExtension = "txt"
        }
        
        // Show save panel
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: fileExtension)!]
        panel.nameFieldStringValue = "\(conversation.title).\(fileExtension)"
        panel.message = "Export conversation as \(format)"
        
        guard panel.runModal() == .OK, let url = panel.url else {
            throw ExportError.writeFailed("User cancelled")
        }
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Format Exporters
    
    private func exportAsMarkdown(conversation: Conversation, messages: [Message]) -> String {
        var md = "# \(conversation.title)\n\n"
        
        if !conversation.summary.isEmpty {
            md += "> \(conversation.summary)\n\n"
        }
        
        md += "**Created:** \(formatDate(conversation.createdAt))\n"
        md += "**Messages:** \(messages.count)\n\n"
        md += "---\n\n"
        
        for message in messages {
            let roleIcon: String
            let roleName: String
            
            switch message.role {
            case .user:
                roleIcon = "👤"
                roleName = "User"
            case .assistant:
                roleIcon = "🤖"
                roleName = "Assistant"
            case .system:
                roleIcon = "⚙️"
                roleName = "System"
            case .tool:
                roleIcon = "🔧"
                roleName = "Tool"
            }
            
            md += "## \(roleIcon) \(roleName)\n\n"
            md += "\(message.content)\n\n"
            
            if let attachments = message.attachments, !attachments.isEmpty {
                md += "_Attachments: \(attachments.count)_\n\n"
            }
            
            md += "---\n\n"
        }
        
        return md
    }
    
    private func exportAsJSON(conversation: Conversation, messages: [Message]) throws -> String {
        let exportData: [String: Any] = [
            "conversation": [
                "id": conversation.id.uuidString,
                "title": conversation.title,
                "summary": conversation.summary,
                "createdAt": conversation.createdAt.timeIntervalSince1970,
                "lastUsedAt": conversation.lastUsedAt.timeIntervalSince1970,
                "messageCount": conversation.messageCount
            ],
            "messages": messages.map { message in
                [
                    "id": message.id.uuidString,
                    "role": message.role.rawValue,
                    "content": message.content,
                    "timestamp": message.timestamp.timeIntervalSince1970
                ] as [String: Any]
            }
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted]),
              let json = String(data: data, encoding: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return json
    }
    
    private func exportAsHTML(conversation: Conversation, messages: [Message]) -> String {
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(conversation.title)</title>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 40px 20px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                }
                .container {
                    background: white;
                    border-radius: 16px;
                    padding: 40px;
                    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                }
                h1 {
                    color: #667eea;
                    margin-bottom: 10px;
                    font-size: 2em;
                }
                .summary {
                    color: #666;
                    font-style: italic;
                    margin-bottom: 20px;
                    padding: 15px;
                    background: #f5f5f5;
                    border-left: 4px solid #667eea;
                    border-radius: 4px;
                }
                .meta {
                    color: #999;
                    font-size: 0.9em;
                    margin-bottom: 30px;
                    padding-bottom: 20px;
                    border-bottom: 2px solid #eee;
                }
                .message {
                    margin-bottom: 30px;
                    padding: 20px;
                    border-radius: 12px;
                    background: #f9f9f9;
                }
                .message.user {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    margin-left: 40px;
                }
                .message.assistant {
                    background: #f0f0f0;
                    margin-right: 40px;
                }
                .message.tool {
                    background: #fff3e0;
                    border-left: 4px solid #ff9800;
                }
                .message.system {
                    background: #e3f2fd;
                    border-left: 4px solid #2196f3;
                }
                .message-header {
                    font-weight: bold;
                    margin-bottom: 10px;
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }
                .message-content {
                    white-space: pre-wrap;
                    word-wrap: break-word;
                }
                .message.user .message-content {
                    color: white;
                }
                .icon {
                    font-size: 1.2em;
                }
                code {
                    background: rgba(0,0,0,0.1);
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: 'Monaco', 'Courier New', monospace;
                    font-size: 0.9em;
                }
                pre {
                    background: #2d2d2d;
                    color: #f8f8f2;
                    padding: 15px;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 10px 0;
                }
                pre code {
                    background: none;
                    color: inherit;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>\(conversation.title)</h1>
        """
        
        if !conversation.summary.isEmpty {
            html += """
                <div class="summary">\(conversation.summary)</div>
            """
        }
        
        html += """
                <div class="meta">
                    <div>Created: \(formatDate(conversation.createdAt))</div>
                    <div>Messages: \(messages.count)</div>
                </div>
        """
        
        for message in messages {
            let (icon, roleName) = roleInfo(for: message.role)
            let roleClass = message.role.rawValue
            
            html += """
                <div class="message \(roleClass)">
                    <div class="message-header">
                        <span class="icon">\(icon)</span>
                        <span>\(roleName)</span>
                    </div>
                    <div class="message-content">\(escapeHTML(message.content))</div>
                </div>
            """
        }
        
        html += """
            </div>
        </body>
        </html>
        """
        
        return html
    }
    
    private func exportAsPlainText(conversation: Conversation, messages: [Message]) -> String {
        var text = "\(conversation.title)\n"
        text += String(repeating: "=", count: conversation.title.count) + "\n\n"
        
        if !conversation.summary.isEmpty {
            text += "Summary: \(conversation.summary)\n\n"
        }
        
        text += "Created: \(formatDate(conversation.createdAt))\n"
        text += "Messages: \(messages.count)\n\n"
        text += String(repeating: "-", count: 60) + "\n\n"
        
        for message in messages {
            let (icon, roleName) = roleInfo(for: message.role)
            
            text += "\(icon) \(roleName.uppercased())\n"
            text += message.content + "\n\n"
            text += String(repeating: "-", count: 60) + "\n\n"
        }
        
        return text
    }
    
    // MARK: - Helpers
    
    private func roleInfo(for role: MessageRole) -> (String, String) {
        switch role {
        case .user:
            return ("👤", "User")
        case .assistant:
            return ("🤖", "Assistant")
        case .system:
            return ("⚙️", "System")
        case .tool:
            return ("🔧", "Tool")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
