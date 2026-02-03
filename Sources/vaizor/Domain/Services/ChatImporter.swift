import Foundation
import UniformTypeIdentifiers
import GRDB

/// Service for importing chat histories from various AI platforms
/// Supports OpenAI and Anthropic export formats
@MainActor
class ChatImporter: ObservableObject {
    static let shared = ChatImporter()

    enum ImportFormat: String, CaseIterable, Identifiable {
        case openAI = "OpenAI"
        case anthropic = "Anthropic"
        case claudeCode = "Claude Code"
        case chatGPTShare = "ChatGPT Share"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .openAI: return "OpenAI JSON export (conversations.json)"
            case .anthropic: return "Anthropic/Claude JSON export"
            case .claudeCode: return "Claude Code JSONL transcript"
            case .chatGPTShare: return "ChatGPT shared conversation link"
            }
        }

        var fileExtensions: [String] {
            switch self {
            case .openAI, .anthropic: return ["json"]
            case .claudeCode: return ["jsonl"]
            case .chatGPTShare: return []
            }
        }
    }

    enum ImportError: LocalizedError {
        case invalidFormat(String)
        case parseError(String)
        case emptyFile
        case unsupportedVersion(String)
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat(let detail): return "Invalid format: \(detail)"
            case .parseError(let detail): return "Parse error: \(detail)"
            case .emptyFile: return "The file contains no conversations"
            case .unsupportedVersion(let version): return "Unsupported export version: \(version)"
            case .networkError(let detail): return "Network error: \(detail)"
            }
        }
    }

    struct ImportResult {
        let conversations: [ImportedConversation]
        let totalMessages: Int
        let format: ImportFormat
        let warnings: [String]
    }

    struct ImportedConversation: Identifiable {
        let id: UUID
        let title: String
        let messages: [ImportedMessage]
        let createdAt: Date
        let source: ImportFormat
    }

    struct ImportedMessage: Identifiable {
        let id: UUID
        let role: String
        let content: String
        let timestamp: Date?
    }

    @Published var isImporting = false
    @Published var importProgress: Double = 0
    @Published var lastError: ImportError?

    private init() {}

    // MARK: - Public Import Methods

    /// Import from file URL
    func importFromFile(_ url: URL, format: ImportFormat? = nil) async throws -> ImportResult {
        isImporting = true
        importProgress = 0
        defer { isImporting = false }

        let data = try Data(contentsOf: url)

        // Auto-detect format if not specified
        let detectedFormat = format ?? detectFormat(from: data, filename: url.lastPathComponent)

        return try await processData(data, format: detectedFormat)
    }

    /// Import from raw data
    func importFromData(_ data: Data, format: ImportFormat) async throws -> ImportResult {
        isImporting = true
        importProgress = 0
        defer { isImporting = false }

        return try await processData(data, format: format)
    }

    /// Import from ChatGPT share URL
    func importFromShareURL(_ urlString: String) async throws -> ImportResult {
        isImporting = true
        importProgress = 0
        defer { isImporting = false }

        // ChatGPT share URLs look like: https://chat.openai.com/share/xxx
        guard let url = URL(string: urlString),
              url.host?.contains("openai.com") == true || url.host?.contains("chatgpt.com") == true else {
            throw ImportError.invalidFormat("Not a valid ChatGPT share URL")
        }

        // Note: This would require web scraping or API access which may not be available
        throw ImportError.networkError("ChatGPT share URL import requires browser authentication")
    }

    // MARK: - Format Detection

    private func detectFormat(from data: Data, filename: String) -> ImportFormat {
        // Check file extension first
        let ext = (filename as NSString).pathExtension.lowercased()
        if ext == "jsonl" {
            return .claudeCode
        }

        // Try to parse as JSON and detect structure
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // Single object format
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if obj["chat_messages"] != nil {
                    return .anthropic
                }
                if obj["mapping"] != nil {
                    return .openAI
                }
            }
            return .openAI // Default
        }

        // Array format - check first object
        if let first = json.first {
            if first["mapping"] != nil || first["create_time"] != nil {
                return .openAI
            }
            if first["chat_messages"] != nil || first["uuid"] != nil {
                return .anthropic
            }
        }

        return .openAI
    }

    // MARK: - Data Processing

    private func processData(_ data: Data, format: ImportFormat) async throws -> ImportResult {
        importProgress = 0.1

        switch format {
        case .openAI:
            return try parseOpenAIFormat(data)
        case .anthropic:
            return try parseAnthropicFormat(data)
        case .claudeCode:
            return try parseClaudeCodeFormat(data)
        case .chatGPTShare:
            throw ImportError.invalidFormat("Use importFromShareURL for ChatGPT share links")
        }
    }

    // MARK: - OpenAI Format Parser

    private func parseOpenAIFormat(_ data: Data) throws -> ImportResult {
        var conversations: [ImportedConversation] = []
        var warnings: [String] = []

        // OpenAI exports can be a single conversation or array
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            importProgress = 0.3
            for (index, item) in jsonArray.enumerated() {
                if let conv = parseOpenAIConversation(item) {
                    conversations.append(conv)
                }
                importProgress = 0.3 + (0.6 * Double(index + 1) / Double(jsonArray.count))
            }
        } else if let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let conv = parseOpenAIConversation(jsonObj) {
                conversations.append(conv)
            }
        } else {
            throw ImportError.parseError("Could not parse OpenAI JSON format")
        }

        if conversations.isEmpty {
            throw ImportError.emptyFile
        }

        importProgress = 1.0
        let totalMessages = conversations.reduce(0) { $0 + $1.messages.count }

        return ImportResult(
            conversations: conversations,
            totalMessages: totalMessages,
            format: .openAI,
            warnings: warnings
        )
    }

    private func parseOpenAIConversation(_ json: [String: Any]) -> ImportedConversation? {
        let title = json["title"] as? String ?? "Imported Chat"
        let createTime = json["create_time"] as? Double
        let createdAt = createTime.map { Date(timeIntervalSince1970: $0) } ?? Date()

        var messages: [ImportedMessage] = []

        // OpenAI format uses a "mapping" object with tree structure
        if let mapping = json["mapping"] as? [String: [String: Any]] {
            var messageNodes: [(String, [String: Any])] = Array(mapping)
            // Sort by create_time if available
            messageNodes.sort { node1, node2 in
                let t1 = (node1.1["message"] as? [String: Any])?["create_time"] as? Double ?? 0
                let t2 = (node2.1["message"] as? [String: Any])?["create_time"] as? Double ?? 0
                return t1 < t2
            }

            for (_, nodeData) in messageNodes {
                guard let messageData = nodeData["message"] as? [String: Any],
                      let author = messageData["author"] as? [String: Any],
                      let role = author["role"] as? String,
                      let content = messageData["content"] as? [String: Any] else {
                    continue
                }

                // Skip system messages
                if role == "system" { continue }

                // Extract text content
                var textContent = ""
                if let parts = content["parts"] as? [Any] {
                    textContent = parts.compactMap { $0 as? String }.joined(separator: "\n")
                } else if let text = content["text"] as? String {
                    textContent = text
                }

                if textContent.isEmpty { continue }

                let timestamp = (messageData["create_time"] as? Double).map { Date(timeIntervalSince1970: $0) }

                messages.append(ImportedMessage(
                    id: UUID(),
                    role: role == "assistant" ? "assistant" : "user",
                    content: textContent,
                    timestamp: timestamp
                ))
            }
        }

        // Alternative flat format
        if messages.isEmpty, let rawMessages = json["messages"] as? [[String: Any]] {
            for msg in rawMessages {
                guard let role = msg["role"] as? String,
                      let content = msg["content"] as? String else { continue }
                if role == "system" { continue }

                messages.append(ImportedMessage(
                    id: UUID(),
                    role: role,
                    content: content,
                    timestamp: nil
                ))
            }
        }

        guard !messages.isEmpty else { return nil }

        return ImportedConversation(
            id: UUID(),
            title: title,
            messages: messages,
            createdAt: createdAt,
            source: .openAI
        )
    }

    // MARK: - Anthropic Format Parser

    private func parseAnthropicFormat(_ data: Data) throws -> ImportResult {
        var conversations: [ImportedConversation] = []
        var warnings: [String] = []

        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            importProgress = 0.3
            for (index, item) in jsonArray.enumerated() {
                if let conv = parseAnthropicConversation(item) {
                    conversations.append(conv)
                }
                importProgress = 0.3 + (0.6 * Double(index + 1) / Double(jsonArray.count))
            }
        } else if let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let conv = parseAnthropicConversation(jsonObj) {
                conversations.append(conv)
            }
        } else {
            throw ImportError.parseError("Could not parse Anthropic JSON format")
        }

        if conversations.isEmpty {
            throw ImportError.emptyFile
        }

        importProgress = 1.0
        let totalMessages = conversations.reduce(0) { $0 + $1.messages.count }

        return ImportResult(
            conversations: conversations,
            totalMessages: totalMessages,
            format: .anthropic,
            warnings: warnings
        )
    }

    private func parseAnthropicConversation(_ json: [String: Any]) -> ImportedConversation? {
        let title = json["name"] as? String ?? json["title"] as? String ?? "Imported Chat"
        let createdAt: Date

        if let dateStr = json["created_at"] as? String {
            createdAt = ISO8601DateFormatter().date(from: dateStr) ?? Date()
        } else if let timestamp = json["created_at"] as? Double {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            createdAt = Date()
        }

        var messages: [ImportedMessage] = []

        // Anthropic format uses "chat_messages" array
        if let chatMessages = json["chat_messages"] as? [[String: Any]] {
            for msg in chatMessages {
                guard let sender = msg["sender"] as? String else { continue }

                // Extract content - can be string or array of content blocks
                var textContent = ""
                if let content = msg["text"] as? String {
                    textContent = content
                } else if let content = msg["content"] as? String {
                    textContent = content
                } else if let contentBlocks = msg["content"] as? [[String: Any]] {
                    textContent = contentBlocks.compactMap { block in
                        if block["type"] as? String == "text" {
                            return block["text"] as? String
                        }
                        return nil
                    }.joined(separator: "\n")
                }

                if textContent.isEmpty { continue }

                let role = sender == "human" ? "user" : "assistant"

                let timestamp: Date?
                if let dateStr = msg["created_at"] as? String {
                    timestamp = ISO8601DateFormatter().date(from: dateStr)
                } else if let ts = msg["created_at"] as? Double {
                    timestamp = Date(timeIntervalSince1970: ts)
                } else {
                    timestamp = nil
                }

                messages.append(ImportedMessage(
                    id: UUID(),
                    role: role,
                    content: textContent,
                    timestamp: timestamp
                ))
            }
        }

        guard !messages.isEmpty else { return nil }

        return ImportedConversation(
            id: UUID(),
            title: title,
            messages: messages,
            createdAt: createdAt,
            source: .anthropic
        )
    }

    // MARK: - Claude Code Format Parser

    private func parseClaudeCodeFormat(_ data: Data) throws -> ImportResult {
        var conversations: [ImportedConversation] = []
        var messages: [ImportedMessage] = []
        var warnings: [String] = []

        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.parseError("Could not decode JSONL file")
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        importProgress = 0.3

        for (index, line) in lines.enumerated() {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            // Claude Code JSONL format
            if let role = json["role"] as? String,
               let content = json["content"] as? String {
                messages.append(ImportedMessage(
                    id: UUID(),
                    role: role,
                    content: content,
                    timestamp: nil
                ))
            }

            // Alternative: content as array
            if let role = json["role"] as? String,
               let contentArray = json["content"] as? [[String: Any]] {
                let text = contentArray.compactMap { block -> String? in
                    if block["type"] as? String == "text" {
                        return block["text"] as? String
                    }
                    return nil
                }.joined(separator: "\n")

                if !text.isEmpty {
                    messages.append(ImportedMessage(
                        id: UUID(),
                        role: role,
                        content: text,
                        timestamp: nil
                    ))
                }
            }

            importProgress = 0.3 + (0.6 * Double(index + 1) / Double(lines.count))
        }

        if messages.isEmpty {
            throw ImportError.emptyFile
        }

        // Create single conversation from all messages
        conversations.append(ImportedConversation(
            id: UUID(),
            title: "Imported Claude Code Session",
            messages: messages,
            createdAt: Date(),
            source: .claudeCode
        ))

        importProgress = 1.0

        return ImportResult(
            conversations: conversations,
            totalMessages: messages.count,
            format: .claudeCode,
            warnings: warnings
        )
    }

    // MARK: - Save to Database

    /// Save imported conversations to the database
    func saveToDatabase(_ result: ImportResult) async throws {
        let repo = ConversationRepository()
        let pgRepo = PGConversationRepository(db: PostgresManager.shared)

        for imported in result.conversations {
            // Create conversation
            let conversation = Conversation(
                id: imported.id,
                title: imported.title,
                summary: "Imported from \(imported.source.rawValue)",
                createdAt: imported.createdAt,
                lastUsedAt: imported.createdAt,
                messageCount: imported.messages.count
            )

            // Save conversation to PostgreSQL
            try await pgRepo.save(conversation)

            // Add messages
            for importedMsg in imported.messages {
                let role: MessageRole = importedMsg.role == "assistant" ? .assistant : .user
                let message = Message(
                    id: importedMsg.id,
                    conversationId: conversation.id,
                    role: role,
                    content: importedMsg.content,
                    timestamp: importedMsg.timestamp ?? Date(),
                    attachments: nil
                )
                await repo.saveMessage(message)
            }
        }

        AppLogger.shared.log("Imported \(result.conversations.count) conversations with \(result.totalMessages) messages", level: .info)
    }
}

// MARK: - SwiftUI Import View

import SwiftUI

// Dark theme colors for import view
private let importDarkBase = Color(hex: "1c1d1f")
private let importDarkSurface = Color(hex: "232426")
private let importDarkBorder = Color(hex: "2d2e30")
private let importTextPrimary = Color.white
private let importTextSecondary = Color(hex: "808080")
private let importAccent = Color(hex: "00976d")

struct ChatImportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var importer = ChatImporter.shared

    @State private var selectedFormat: ChatImporter.ImportFormat = .openAI
    @State private var showFilePicker = false
    @State private var importResult: ChatImporter.ImportResult?
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import Chats")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(importTextPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(importTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(importDarkBase)

            Rectangle().fill(importDarkBorder).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Format selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import Format")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(importTextSecondary)

                        ForEach(ChatImporter.ImportFormat.allCases) { format in
                            Button {
                                selectedFormat = format
                            } label: {
                                HStack {
                                    Image(systemName: selectedFormat == format ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedFormat == format ? importAccent : importTextSecondary)
                                    VStack(alignment: .leading) {
                                        Text(format.rawValue)
                                            .font(.system(size: 13))
                                            .foregroundStyle(importTextPrimary)
                                        Text(format.description)
                                            .font(.system(size: 11))
                                            .foregroundStyle(importTextSecondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Rectangle().fill(importDarkBorder).frame(height: 1)

                    // Import button
                    if selectedFormat != .chatGPTShare {
                        Button {
                            showFilePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Select File to Import")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(importAccent)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(importer.isImporting)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Paste ChatGPT Share URL")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(importTextSecondary)
                            Text("Note: This feature requires browser authentication and is not yet available.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "d4a017"))
                        }
                    }

                    // Progress indicator
                    if importer.isImporting {
                        VStack(spacing: 8) {
                            ProgressView(value: importer.importProgress)
                                .tint(importAccent)
                            Text("Importing...")
                                .font(.system(size: 11))
                                .foregroundStyle(importTextSecondary)
                        }
                    }

                    // Error message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color(hex: "d4a017"))
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundStyle(importTextPrimary)
                        }
                        .padding()
                        .background(Color(hex: "d4a017").opacity(0.12))
                        .cornerRadius(8)
                    }

                    // Success message
                    if showSuccess, let result = importResult {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(importAccent)
                                Text("Import Successful!")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(importTextPrimary)
                            }
                            Text("Imported \(result.conversations.count) conversation(s) with \(result.totalMessages) messages.")
                                .font(.system(size: 11))
                                .foregroundStyle(importTextSecondary)

                            if !result.warnings.isEmpty {
                                Text("Warnings:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(hex: "d4a017"))
                                ForEach(result.warnings, id: \.self) { warning in
                                    Text("• \(warning)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(hex: "d4a017"))
                                }
                            }
                        }
                        .padding()
                        .background(importAccent.opacity(0.12))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .background(importDarkBase)
        }
        .frame(width: 400, height: 500)
        .background(importDarkBase)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json, UTType(filenameExtension: "jsonl") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleFileSelection(result)
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) async {
        errorMessage = nil

        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = "Could not access the selected file"
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let importResult = try await importer.importFromFile(url, format: selectedFormat)
                try await importer.saveToDatabase(importResult)

                self.importResult = importResult
                self.showSuccess = true

            } catch let error as ChatImporter.ImportError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = error.localizedDescription
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ChatImportView()
}
