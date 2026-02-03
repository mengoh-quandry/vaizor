import Foundation
import SQLite3

// MARK: - iMessage Observer
// Monitors Messages.app for new incoming messages

@MainActor
class MessagesObserver {
    weak var delegate: SystemObserverDelegate?

    private let appleScriptBridge = AppleScriptBridge.shared

    private var isObserving = false
    private var observationTask: Task<Void, Never>?

    // State tracking
    private var lastMessageId: Int64 = 0
    private var knownMessages: Set<Int64> = []

    // Database path
    private let chatDBPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Messages/chat.db"
    }()

    init(delegate: SystemObserverDelegate?) {
        self.delegate = delegate
    }

    // MARK: - Lifecycle

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        AppLogger.shared.log("MessagesObserver: Starting", level: .info)

        // Initialize last message ID
        if let lastId = getLastMessageId() {
            lastMessageId = lastId
        }

        observationTask = Task {
            await runObservationLoop()
        }
    }

    func stopObserving() {
        isObserving = false
        observationTask?.cancel()
        observationTask = nil
        AppLogger.shared.log("MessagesObserver: Stopped", level: .info)
    }

    // MARK: - Observation Loop

    private func runObservationLoop() async {
        while !Task.isCancelled && isObserving {
            await checkForNewMessages()
            try? await Task.sleep(nanoseconds: 3_000_000_000)  // Check every 3 seconds
        }
    }

    private func checkForNewMessages() async {
        guard let messages = getNewMessages() else { return }

        for message in messages {
            // Skip if we've already seen this message
            guard !knownMessages.contains(message.rowId) else { continue }
            knownMessages.insert(message.rowId)

            // Skip messages from self
            guard !message.isFromMe else { continue }

            // Update last ID
            if message.rowId > lastMessageId {
                lastMessageId = message.rowId
            }

            // Emit event
            let event = SystemEvent(
                type: .newMessageReceived,
                timestamp: message.date,
                source: "MessagesObserver",
                data: [
                    "sender": message.senderName ?? message.senderId,
                    "senderId": message.senderId,
                    "content": message.content,
                    "chatId": message.chatId,
                    "isGroup": message.isGroup ? "true" : "false"
                ]
            )
            delegate?.emitEvent(event)

            AppLogger.shared.log("MessagesObserver: New message from \(message.senderName ?? message.senderId)", level: .info)
        }

        // Clean up old known messages to prevent memory growth
        if knownMessages.count > 1000 {
            let sortedIds = knownMessages.sorted()
            knownMessages = Set(sortedIds.suffix(500))
        }
    }

    // MARK: - Database Access

    struct IncomingMessage {
        let rowId: Int64
        let content: String
        let senderId: String
        let senderName: String?
        let date: Date
        let chatId: String
        let isFromMe: Bool
        let isGroup: Bool
    }

    private func getNewMessages() -> [IncomingMessage]? {
        var db: OpaquePointer?

        // Open database read-only
        guard sqlite3_open_v2(chatDBPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            AppLogger.shared.log("MessagesObserver: Cannot open chat.db", level: .debug)
            return nil
        }
        defer { sqlite3_close(db) }

        // Query for new messages
        let query = """
            SELECT
                m.ROWID,
                m.text,
                m.is_from_me,
                m.date,
                h.id as sender_id,
                c.chat_identifier,
                c.display_name,
                (SELECT COUNT(*) FROM chat_handle_join WHERE chat_id = c.ROWID) as participant_count
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            LEFT JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            LEFT JOIN chat c ON cmj.chat_id = c.ROWID
            WHERE m.ROWID > ?
            AND m.text IS NOT NULL
            AND m.text != ''
            ORDER BY m.ROWID ASC
            LIMIT 50
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, lastMessageId)

        var messages: [IncomingMessage] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let rowId = sqlite3_column_int64(statement, 0)

            // Get text content
            guard let textPtr = sqlite3_column_text(statement, 1) else { continue }
            let content = String(cString: textPtr)

            let isFromMe = sqlite3_column_int(statement, 2) == 1

            // Convert Apple's timestamp (nanoseconds since 2001)
            let appleTimestamp = sqlite3_column_int64(statement, 3)
            let date = Date(timeIntervalSinceReferenceDate: Double(appleTimestamp) / 1_000_000_000)

            // Sender ID
            var senderId = "unknown"
            if let senderPtr = sqlite3_column_text(statement, 4) {
                senderId = String(cString: senderPtr)
            }

            // Chat identifier
            var chatId = ""
            if let chatPtr = sqlite3_column_text(statement, 5) {
                chatId = String(cString: chatPtr)
            }

            // Display name (for groups)
            var senderName: String?
            if let namePtr = sqlite3_column_text(statement, 6) {
                let name = String(cString: namePtr)
                if !name.isEmpty {
                    senderName = name
                }
            }

            let participantCount = sqlite3_column_int(statement, 7)
            let isGroup = participantCount > 2

            messages.append(IncomingMessage(
                rowId: rowId,
                content: content,
                senderId: senderId,
                senderName: senderName ?? getSenderName(for: senderId),
                date: date,
                chatId: chatId,
                isFromMe: isFromMe,
                isGroup: isGroup
            ))
        }

        return messages
    }

    private func getLastMessageId() -> Int64? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(chatDBPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        let query = "SELECT MAX(ROWID) FROM message"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        if sqlite3_step(statement) == SQLITE_ROW {
            return sqlite3_column_int64(statement, 0)
        }

        return nil
    }

    private func getSenderName(for phoneOrEmail: String) -> String? {
        // Try to resolve via Contacts (would need CNContactStore access)
        // For now, just format phone numbers nicely
        if phoneOrEmail.hasPrefix("+") {
            return formatPhoneNumber(phoneOrEmail)
        }
        return nil
    }

    private func formatPhoneNumber(_ number: String) -> String {
        // Simple phone formatting
        let digits = number.filter { $0.isNumber }
        if digits.count == 11 && digits.hasPrefix("1") {
            let area = digits.dropFirst().prefix(3)
            let prefix = digits.dropFirst(4).prefix(3)
            let line = digits.suffix(4)
            return "(\(area)) \(prefix)-\(line)"
        }
        return number
    }

    // MARK: - Query Methods

    /// Get recent conversations
    func getRecentConversations(limit: Int = 10) -> [Conversation]? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(chatDBPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        let query = """
            SELECT
                c.chat_identifier,
                c.display_name,
                MAX(m.date) as last_date,
                (SELECT text FROM message WHERE ROWID = MAX(m.ROWID)) as last_message
            FROM chat c
            LEFT JOIN chat_message_join cmj ON c.ROWID = cmj.chat_id
            LEFT JOIN message m ON cmj.message_id = m.ROWID
            GROUP BY c.ROWID
            ORDER BY last_date DESC
            LIMIT ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(limit))

        var conversations: [Conversation] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idPtr = sqlite3_column_text(statement, 0) else { continue }
            let chatId = String(cString: idPtr)

            var displayName: String?
            if let namePtr = sqlite3_column_text(statement, 1) {
                displayName = String(cString: namePtr)
            }

            let timestamp = sqlite3_column_int64(statement, 2)
            let lastDate = Date(timeIntervalSinceReferenceDate: Double(timestamp) / 1_000_000_000)

            var lastMessage: String?
            if let msgPtr = sqlite3_column_text(statement, 3) {
                lastMessage = String(cString: msgPtr)
            }

            conversations.append(Conversation(
                chatId: chatId,
                displayName: displayName ?? chatId,
                lastMessage: lastMessage,
                lastMessageDate: lastDate
            ))
        }

        return conversations
    }

    struct Conversation {
        let chatId: String
        let displayName: String
        let lastMessage: String?
        let lastMessageDate: Date
    }
}
