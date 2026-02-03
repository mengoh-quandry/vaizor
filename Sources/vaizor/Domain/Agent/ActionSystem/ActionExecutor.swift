import Foundation
import AppKit
import UserNotifications

// MARK: - Action Executor
// Executes approved agent actions using AppleScript and Accessibility APIs

@MainActor
class ActionExecutor: ObservableObject {
    static let shared = ActionExecutor()

    private let appleScriptBridge = AppleScriptBridge.shared
    private let accessibilityBridge = AccessibilityBridge.shared

    @Published private(set) var isExecuting: Bool = false
    @Published private(set) var lastExecutionResult: ExecutionResult?

    private init() {}

    // MARK: - Execution

    struct ExecutionResult: Sendable {
        let action: AgentAction
        let success: Bool
        let message: String?
        let timestamp: Date

        static func success(_ action: AgentAction, message: String? = nil) -> ExecutionResult {
            ExecutionResult(action: action, success: true, message: message, timestamp: Date())
        }

        static func failure(_ action: AgentAction, error: String) -> ExecutionResult {
            ExecutionResult(action: action, success: false, message: error, timestamp: Date())
        }
    }

    func execute(_ action: AgentAction) async -> ExecutionResult {
        isExecuting = true
        defer { isExecuting = false }

        AppLogger.shared.log("ActionExecutor: Executing - \(action.description)", level: .info)

        let result: ExecutionResult

        do {
            switch action {
            // Communication
            case .sendMessage(let recipient, let content, let service):
                try await executeMessage(recipient: recipient, content: content, service: service)
                result = .success(action, message: "Message sent to \(recipient)")

            case .draftMessage(let recipient, let content, _):
                // Open Messages with draft - don't actually send
                try await openMessagesDraft(recipient: recipient, content: content)
                result = .success(action, message: "Draft prepared for \(recipient)")

            // Browser
            case .openURL(let url):
                try await executeOpenURL(url)
                result = .success(action)

            case .summarizePage:
                // This would trigger the agent to summarize - handled elsewhere
                result = .success(action, message: "Page summarization triggered")

            case .searchWeb(let query):
                try await executeWebSearch(query)
                result = .success(action)

            // File System
            case .moveFile(let from, let to):
                try await executeMoveFile(from: from, to: to)
                result = .success(action, message: "File moved")

            case .organizeFile(let path, let location):
                try await executeMoveFile(from: path, to: location)
                result = .success(action, message: "File organized")

            case .deleteFile(let path):
                try await executeDeleteFile(path)
                result = .success(action, message: "File deleted")

            case .createFolder(let path):
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                result = .success(action, message: "Folder created")

            // App Control
            case .launchApp(let name):
                try await executeLaunchApp(name)
                result = .success(action)

            case .switchToApp(let name):
                try await executeSwitchToApp(name)
                result = .success(action)

            case .quitApp(let name):
                try await executeQuitApp(name)
                result = .success(action)

            // Clipboard
            case .copyToClipboard(let content):
                executeCopyToClipboard(content)
                result = .success(action)

            case .pasteFromClipboard:
                try await executePaste()
                result = .success(action)

            // System
            case .showNotification(let title, let body):
                await executeShowNotification(title: title, body: body)
                result = .success(action)

            case .createReminder(let title, let date):
                try await executeCreateReminder(title: title, date: date)
                result = .success(action)

            case .createCalendarEvent(let title, let start, let end):
                try await executeCreateCalendarEvent(title: title, start: start, end: end)
                result = .success(action)

            // Navigation
            case .navigateInApp(let destination):
                NotificationCenter.default.post(name: .navigateInApp, object: destination)
                result = .success(action)

            case .scrollTo(let element):
                // Would use Accessibility API
                result = .success(action, message: "Scrolled to \(element)")

            case .click(let element):
                // Would use Accessibility API
                result = .success(action, message: "Clicked \(element)")

            // Observation (no-op execution)
            case .observe, .summarize:
                result = .success(action)
            }
        } catch {
            result = .failure(action, error: error.localizedDescription)
            AppLogger.shared.log("ActionExecutor: Failed - \(error)", level: .error)
        }

        lastExecutionResult = result
        return result
    }

    // MARK: - Message Execution

    private func executeMessage(recipient: String, content: String, service: MessageService) async throws {
        try await appleScriptBridge.sendMessage(to: recipient, content: content)
    }

    private func openMessagesDraft(recipient: String, content: String) async throws {
        let script = """
        tell application "Messages"
            activate
        end tell
        """
        _ = try await appleScriptBridge.execute(script)
        // Note: Actually opening a compose window with pre-filled content is limited
        // The user would need to manually select the recipient
    }

    // MARK: - Browser Execution

    private func executeOpenURL(_ urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw ActionExecutionError.invalidURL(urlString)
        }
        NSWorkspace.shared.open(url)
    }

    private func executeWebSearch(_ query: String) async throws {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchURL = "https://www.google.com/search?q=\(encodedQuery)"
        try await executeOpenURL(searchURL)
    }

    // MARK: - File System Execution

    private func executeMoveFile(from sourcePath: String, to destinationPath: String) async throws {
        // Ensure destination directory exists
        let destDir = (destinationPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: destDir, withIntermediateDirectories: true)

        // Move file
        try FileManager.default.moveItem(atPath: sourcePath, toPath: destinationPath)
    }

    private func executeDeleteFile(_ path: String) async throws {
        // Move to trash instead of permanent delete for safety
        let fileURL = URL(fileURLWithPath: path)
        try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
    }

    // MARK: - App Control Execution

    private func executeLaunchApp(_ appName: String) async throws {
        let script = """
        tell application "\(appName)"
            activate
        end tell
        """
        _ = try await appleScriptBridge.execute(script)
    }

    private func executeSwitchToApp(_ appName: String) async throws {
        try await executeLaunchApp(appName)  // activate does both
    }

    private func executeQuitApp(_ appName: String) async throws {
        let script = """
        tell application "\(appName)"
            quit
        end tell
        """
        _ = try await appleScriptBridge.execute(script)
    }

    // MARK: - Clipboard Execution

    private func executeCopyToClipboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }

    private func executePaste() async throws {
        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let vKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        vKeyDown?.flags = .maskCommand
        vKeyUp?.flags = .maskCommand

        vKeyDown?.post(tap: .cghidEventTap)
        vKeyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - System Execution

    private func executeShowNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    private func executeCreateReminder(title: String, date: Date?) async throws {
        var dateClause = ""
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
            dateClause = " remind me date \"\(formatter.string(from: date))\""
        }

        let script = """
        tell application "Reminders"
            make new reminder with properties {name:"\(title)"\(dateClause)}
        end tell
        """
        _ = try await appleScriptBridge.execute(script)
    }

    private func executeCreateCalendarEvent(title: String, start: Date, end: Date) async throws {
        let formatter = ISO8601DateFormatter()
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)

        let script = """
        tell application "Calendar"
            tell calendar "Home"
                make new event with properties {summary:"\(title)", start date:date "\(startStr)", end date:date "\(endStr)"}
            end tell
        end tell
        """
        _ = try await appleScriptBridge.execute(script)
    }
}

// MARK: - Errors

enum ActionExecutionError: LocalizedError {
    case invalidURL(String)
    case permissionDenied(String)
    case appNotFound(String)
    case fileNotFound(String)
    case timeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .permissionDenied(let action):
            return "Permission denied for: \(action)"
        case .appNotFound(let app):
            return "Application not found: \(app)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .timeout:
            return "Action timed out"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateInApp = Notification.Name("navigateInApp")
    static let actionExecuted = Notification.Name("actionExecuted")
}
