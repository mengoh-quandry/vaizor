import Foundation
import AppKit

// MARK: - AppleScript Bridge
// Unified interface for executing AppleScript commands to control system apps

actor AppleScriptBridge {
    static let shared = AppleScriptBridge()

    private init() {}

    // MARK: - Core Execution

    func execute(_ script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let result = appleScript?.executeAndReturnError(&error)

                if let error = error {
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                    let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
                    continuation.resume(throwing: AppleScriptError.executionFailed(
                        message: errorMessage,
                        code: errorNumber
                    ))
                    return
                }

                let stringResult = result?.stringValue ?? ""
                continuation.resume(returning: stringResult)
            }
        }
    }

    // MARK: - Messages.app Integration

    struct MessageChat: Sendable {
        let id: String
        let participantName: String
        let lastMessage: String
        let lastMessageDate: Date?
        let unreadCount: Int
    }

    struct Message: Sendable {
        let id: String
        let sender: String
        let content: String
        let date: Date?
        let isFromMe: Bool
    }

    func getMessagesChats() async throws -> [MessageChat] {
        let script = """
        tell application "Messages"
            set chatList to {}
            repeat with c in chats
                try
                    set chatId to id of c
                    set chatName to name of c
                    if chatName is missing value then
                        set chatName to "Unknown"
                    end if
                    set end of chatList to {chatId, chatName}
                end try
            end repeat
            return chatList
        end tell
        """

        let result = try await execute(script)
        // Parse result - AppleScript returns nested lists as comma-separated
        // This is a simplified parser; real implementation would be more robust
        var chats: [MessageChat] = []

        // For now, return empty array - full parsing needs more work
        await MainActor.run {
            AppLogger.shared.log("AppleScriptBridge: Retrieved chats raw: \(result.prefix(200))", level: .debug)
        }

        return chats
    }

    func getRecentMessages(limit: Int = 10) async throws -> [Message] {
        // Get recent messages across all chats
        let script = """
        tell application "Messages"
            set messageList to {}
            repeat with c in (chats whose service type is iMessage)
                try
                    set msgs to messages of c
                    if (count of msgs) > 0 then
                        repeat with i from 1 to (minimum of {\(limit), count of msgs})
                            set m to item i of msgs
                            set msgContent to text of m
                            set msgSender to name of sender of m
                            set msgDate to date sent of m
                            set isMe to (sender of m is missing value)
                            set end of messageList to {msgContent, msgSender, msgDate as string, isMe}
                        end repeat
                    end if
                end try
            end repeat
            return messageList
        end tell
        """

        let _ = try await execute(script)
        // Parsing would happen here
        return []
    }

    func sendMessage(to recipient: String, content: String) async throws {
        // Escape content for AppleScript
        let escapedContent = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Messages"
            set targetBuddy to buddy "\(recipient)" of (service 1 whose service type is iMessage)
            send "\(escapedContent)" to targetBuddy
        end tell
        """

        _ = try await execute(script)
        await MainActor.run {
            AppLogger.shared.log("AppleScriptBridge: Sent message to \(recipient)", level: .info)
        }
    }

    // MARK: - Safari Integration

    struct BrowserTab: Sendable {
        let url: String
        let title: String
        let browserName: String
    }

    func getSafariCurrentTab() async throws -> BrowserTab? {
        let script = """
        tell application "Safari"
            if (count of windows) > 0 then
                set currentTab to current tab of window 1
                return {URL of currentTab, name of currentTab}
            end if
            return {}
        end tell
        """

        let result = try await execute(script)
        guard !result.isEmpty else { return nil }

        // Parse "url, title" format
        let components = result.components(separatedBy: ", ")
        guard components.count >= 2 else { return nil }

        return BrowserTab(
            url: components[0],
            title: components[1...].joined(separator: ", "),
            browserName: "Safari"
        )
    }

    func getSafariPageContent() async throws -> String {
        let script = """
        tell application "Safari"
            if (count of windows) > 0 then
                do JavaScript "document.body.innerText" in current tab of window 1
            end if
        end tell
        """

        return try await execute(script)
    }

    func getSafariAllTabs() async throws -> [BrowserTab] {
        let script = """
        tell application "Safari"
            set tabList to {}
            repeat with w in windows
                repeat with t in tabs of w
                    set end of tabList to {URL of t, name of t}
                end repeat
            end repeat
            return tabList
        end tell
        """

        let _ = try await execute(script)
        // Parsing would happen here
        return []
    }

    // MARK: - Chrome/Chromium Integration

    func getChromeCurrentTab(browserName: String = "Google Chrome") async throws -> BrowserTab? {
        let script = """
        tell application "\(browserName)"
            if (count of windows) > 0 then
                set currentTab to active tab of window 1
                return {URL of currentTab, title of currentTab}
            end if
            return {}
        end tell
        """

        let result = try await execute(script)
        guard !result.isEmpty else { return nil }

        let components = result.components(separatedBy: ", ")
        guard components.count >= 2 else { return nil }

        return BrowserTab(
            url: components[0],
            title: components[1...].joined(separator: ", "),
            browserName: browserName
        )
    }

    func getChromePageContent(browserName: String = "Google Chrome") async throws -> String {
        let script = """
        tell application "\(browserName)"
            if (count of windows) > 0 then
                execute active tab of window 1 javascript "document.body.innerText"
            end if
        end tell
        """

        return try await execute(script)
    }

    // MARK: - Finder Integration

    func getFinderSelection() async throws -> [String] {
        let script = """
        tell application "Finder"
            set selectedItems to selection
            set pathList to {}
            repeat with item_ in selectedItems
                set end of pathList to POSIX path of (item_ as alias)
            end repeat
            return pathList
        end tell
        """

        let result = try await execute(script)
        return result.components(separatedBy: ", ").filter { !$0.isEmpty }
    }

    func revealInFinder(path: String) async throws {
        let script = """
        tell application "Finder"
            reveal POSIX file "\(path)"
            activate
        end tell
        """

        _ = try await execute(script)
    }

    func moveFile(from sourcePath: String, to destinationPath: String) async throws {
        let script = """
        tell application "Finder"
            move POSIX file "\(sourcePath)" to POSIX file "\(destinationPath)"
        end tell
        """

        _ = try await execute(script)
        await MainActor.run {
            AppLogger.shared.log("AppleScriptBridge: Moved file from \(sourcePath) to \(destinationPath)", level: .info)
        }
    }

    // MARK: - System Queries

    func getFrontmostApp() async throws -> String {
        let script = """
        tell application "System Events"
            name of first application process whose frontmost is true
        end tell
        """

        return try await execute(script)
    }

    func getRunningApps() async throws -> [String] {
        let script = """
        tell application "System Events"
            name of every application process whose background only is false
        end tell
        """

        let result = try await execute(script)
        return result.components(separatedBy: ", ")
    }

    func activateApp(_ appName: String) async throws {
        let script = """
        tell application "\(appName)"
            activate
        end tell
        """

        _ = try await execute(script)
    }

    // MARK: - Supported Browsers

    static let supportedBrowsers = [
        "Safari",
        "Google Chrome",
        "Arc",
        "Microsoft Edge",
        "Brave Browser",
        "Vivaldi",
        "Opera"
    ]

    func detectRunningBrowsers() async throws -> [String] {
        let runningApps = try await getRunningApps()
        return Self.supportedBrowsers.filter { browser in
            runningApps.contains { $0.lowercased().contains(browser.lowercased()) }
        }
    }
}

// MARK: - Errors

enum AppleScriptError: LocalizedError {
    case executionFailed(message: String, code: Int)
    case appNotRunning(String)
    case permissionDenied(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .executionFailed(let message, let code):
            return "AppleScript failed (\(code)): \(message)"
        case .appNotRunning(let app):
            return "\(app) is not running"
        case .permissionDenied(let app):
            return "Permission denied to control \(app). Grant Automation permission in System Preferences."
        case .timeout:
            return "AppleScript execution timed out"
        }
    }
}
