import Foundation
import AppKit

// MARK: - Browser Observer
// Monitors browser tabs and page content across Safari and Chromium browsers

@MainActor
class BrowserObserver {
    weak var delegate: SystemObserverDelegate?

    private let appleScriptBridge = AppleScriptBridge.shared
    private let accessibilityBridge = AccessibilityBridge.shared

    private var isObserving = false
    private var observationTask: Task<Void, Never>?

    // State tracking
    private var lastTab: AppleScriptBridge.BrowserTab?
    private var tabViewStartTime: Date?
    private var pageContent: String?

    // Configuration
    private let readingThreshold: TimeInterval = 30  // Seconds on same page to consider "reading"
    private let contentRefreshInterval: TimeInterval = 10  // How often to refresh page content

    init(delegate: SystemObserverDelegate?) {
        self.delegate = delegate
    }

    // MARK: - Lifecycle

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        AppLogger.shared.log("BrowserObserver: Starting", level: .info)

        observationTask = Task {
            await runObservationLoop()
        }
    }

    func stopObserving() {
        isObserving = false
        observationTask?.cancel()
        observationTask = nil
        AppLogger.shared.log("BrowserObserver: Stopped", level: .info)
    }

    // MARK: - Current State

    struct BrowserState {
        let currentTab: AppleScriptBridge.BrowserTab?
        let pageContent: String?
        let activeBrowser: String?
        let isReadingPage: Bool
    }

    func getCurrentState() async -> BrowserState {
        return BrowserState(
            currentTab: lastTab,
            pageContent: pageContent,
            activeBrowser: lastTab?.browserName,
            isReadingPage: isUserReadingPage()
        )
    }

    // MARK: - Private Methods

    private func runObservationLoop() async {
        var lastContentRefresh = Date.distantPast

        while !Task.isCancelled && isObserving {
            await checkBrowserState()

            // Refresh content periodically if on same page
            if Date().timeIntervalSince(lastContentRefresh) > contentRefreshInterval {
                await refreshPageContent()
                lastContentRefresh = Date()
            }

            // Check if user has been reading same page
            checkReadingState()

            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 second interval
        }
    }

    private func checkBrowserState() async {
        let currentTab = await detectCurrentBrowserTab()

        // Tab changed?
        if currentTab?.url != lastTab?.url {
            if let tab = currentTab {
                // New tab - emit event
                let event = SystemEvent(
                    type: .browserTabChanged,
                    timestamp: Date(),
                    source: "BrowserObserver",
                    data: [
                        "url": tab.url,
                        "title": tab.title,
                        "browser": tab.browserName
                    ]
                )
                delegate?.emitEvent(event)

                // Reset reading timer
                tabViewStartTime = Date()

                // Clear old content
                pageContent = nil
            }

            lastTab = currentTab
        }
    }

    private func detectCurrentBrowserTab() async -> AppleScriptBridge.BrowserTab? {
        // Check which browser is frontmost
        guard let frontApp = try? await appleScriptBridge.getFrontmostApp() else {
            return nil
        }

        // Try Safari first
        if frontApp.lowercased().contains("safari") {
            return try? await appleScriptBridge.getSafariCurrentTab()
        }

        // Try Chromium browsers
        let chromiumBrowsers = ["Google Chrome", "Arc", "Microsoft Edge", "Brave Browser", "Vivaldi", "Opera"]
        for browser in chromiumBrowsers {
            if frontApp.lowercased().contains(browser.lowercased()) ||
               browser.lowercased().contains(frontApp.lowercased()) {
                return try? await appleScriptBridge.getChromeCurrentTab(browserName: browser)
            }
        }

        // Fallback: Try to detect any running browser
        if let runningBrowsers = try? await appleScriptBridge.detectRunningBrowsers(),
           let firstBrowser = runningBrowsers.first {
            if firstBrowser == "Safari" {
                return try? await appleScriptBridge.getSafariCurrentTab()
            } else {
                return try? await appleScriptBridge.getChromeCurrentTab(browserName: firstBrowser)
            }
        }

        // Last resort: use Accessibility API to read window title
        if let focused = accessibilityBridge.getFocusedElement(),
           AppleScriptBridge.supportedBrowsers.contains(where: { focused.appName.contains($0) }) {
            return AppleScriptBridge.BrowserTab(
                url: "unknown",
                title: focused.windowTitle ?? "Unknown",
                browserName: focused.appName
            )
        }

        return nil
    }

    private func refreshPageContent() async {
        guard let tab = lastTab else { return }

        do {
            if tab.browserName == "Safari" {
                pageContent = try await appleScriptBridge.getSafariPageContent()
            } else {
                pageContent = try await appleScriptBridge.getChromePageContent(browserName: tab.browserName)
            }

            // Emit content loaded event if we got substantial content
            if let content = pageContent, content.count > 100 {
                let event = SystemEvent(
                    type: .pageContentLoaded,
                    timestamp: Date(),
                    source: "BrowserObserver",
                    data: [
                        "url": tab.url,
                        "contentLength": "\(content.count)",
                        "preview": String(content.prefix(200))
                    ]
                )
                delegate?.emitEvent(event)
            }
        } catch {
            AppLogger.shared.log("BrowserObserver: Failed to get page content - \(error)", level: .debug)
        }
    }

    private func checkReadingState() {
        guard let startTime = tabViewStartTime else { return }

        let viewDuration = Date().timeIntervalSince(startTime)

        // If user has been on same page for threshold, emit reading event
        if viewDuration >= readingThreshold && !hasEmittedReadingEvent {
            hasEmittedReadingEvent = true

            if let tab = lastTab {
                let event = SystemEvent(
                    type: .userReadingPage,
                    timestamp: Date(),
                    source: "BrowserObserver",
                    data: [
                        "url": tab.url,
                        "title": tab.title,
                        "duration": "\(Int(viewDuration))s"
                    ]
                )
                delegate?.emitEvent(event)
            }
        }
    }

    private var hasEmittedReadingEvent = false

    private func isUserReadingPage() -> Bool {
        guard let startTime = tabViewStartTime else { return false }
        return Date().timeIntervalSince(startTime) >= readingThreshold
    }

    // MARK: - Public Query Methods

    /// Get summary of what user is currently viewing
    func getCurrentPageSummary() -> String? {
        guard let tab = lastTab else { return nil }

        var summary = "Viewing: \(tab.title)"
        summary += "\nURL: \(tab.url)"
        summary += "\nBrowser: \(tab.browserName)"

        if let content = pageContent {
            let wordCount = content.split(separator: " ").count
            summary += "\nContent: ~\(wordCount) words"
        }

        if isUserReadingPage() {
            if let startTime = tabViewStartTime {
                let duration = Int(Date().timeIntervalSince(startTime))
                summary += "\nReading for \(duration)s"
            }
        }

        return summary
    }

    /// Get page content for analysis
    func getPageContent() -> String? {
        return pageContent
    }
}
