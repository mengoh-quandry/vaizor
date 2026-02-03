import Foundation
import Combine
import AppKit

// MARK: - System Observer
// Main coordinator for ambient system observation
// Manages adaptive polling and delegates to specialist observers

@MainActor
class SystemObserver: ObservableObject {
    static let shared = SystemObserver()

    // MARK: - Published State
    @Published private(set) var isObserving: Bool = false
    @Published private(set) var currentState: SystemState = SystemState()
    @Published private(set) var recentEvents: [SystemEvent] = []

    // MARK: - Subsystems
    private let activityTracker = ActivityTracker.shared
    private let appleScriptBridge = AppleScriptBridge.shared
    private let accessibilityBridge = AccessibilityBridge.shared

    // Specialist observers (lazy init)
    private var browserObserver: BrowserObserver?
    private var fileSystemObserver: FileSystemObserver?
    private var messagesObserver: MessagesObserver?

    // MARK: - Private
    private var observationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var eventHandlers: [(SystemEvent) -> Void] = []

    private let maxRecentEvents = 100

    private init() {
        setupActivityTracking()
    }

    // MARK: - Lifecycle

    func startObserving() {
        guard !isObserving else { return }

        AppLogger.shared.log("SystemObserver: Starting observation", level: .info)
        isObserving = true

        // Start activity tracking
        activityTracker.startTracking()

        // Initialize specialist observers
        browserObserver = BrowserObserver(delegate: self)
        fileSystemObserver = FileSystemObserver(delegate: self)
        messagesObserver = MessagesObserver(delegate: self)

        // Start specialist observers
        browserObserver?.startObserving()
        fileSystemObserver?.startObserving()
        messagesObserver?.startObserving()

        // Start main observation loop
        observationTask = Task {
            await runObservationLoop()
        }
    }

    func stopObserving() {
        guard isObserving else { return }

        AppLogger.shared.log("SystemObserver: Stopping observation", level: .info)
        isObserving = false

        observationTask?.cancel()
        observationTask = nil

        activityTracker.stopTracking()

        browserObserver?.stopObserving()
        fileSystemObserver?.stopObserving()
        messagesObserver?.stopObserving()
    }

    // MARK: - Event Subscription

    func onEvent(_ handler: @escaping (SystemEvent) -> Void) {
        eventHandlers.append(handler)
    }

    // MARK: - Private Methods

    private func setupActivityTracking() {
        // React to activity state changes
        NotificationCenter.default.publisher(for: .userBecameActive)
            .sink { [weak self] _ in
                self?.handleActivityChange(active: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .userBecameIdle)
            .sink { [weak self] _ in
                self?.handleActivityChange(active: false)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .screenLocked)
            .sink { [weak self] _ in
                self?.handleScreenLock(locked: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .screenUnlocked)
            .sink { [weak self] _ in
                self?.handleScreenLock(locked: false)
            }
            .store(in: &cancellables)
    }

    private func handleActivityChange(active: Bool) {
        let event = SystemEvent(
            type: active ? .userBecameActive : .userBecameIdle,
            timestamp: Date(),
            source: "ActivityTracker",
            data: [:]
        )
        emitEvent(event)
    }

    private func handleScreenLock(locked: Bool) {
        let event = SystemEvent(
            type: locked ? .screenLocked : .screenUnlocked,
            timestamp: Date(),
            source: "ActivityTracker",
            data: [:]
        )
        emitEvent(event)
    }

    private func runObservationLoop() async {
        while !Task.isCancelled && isObserving {
            let interval = activityTracker.recommendedPollingInterval

            // Don't poll if screen is locked
            guard interval != .infinity else {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // Check every 5s when locked
                continue
            }

            // Update system state
            await updateSystemState()

            // Sleep for the recommended interval
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    private func updateSystemState() async {
        let previousState = currentState

        // Get current frontmost app
        let frontmostApp = try? await appleScriptBridge.getFrontmostApp()

        // Get focused element info
        let focusedElement = accessibilityBridge.getFocusedElement()

        // Get browser state from browser observer
        let browserState = await browserObserver?.getCurrentState()

        // Build new state
        var newState = SystemState()
        newState.timestamp = Date()
        newState.frontmostApp = frontmostApp ?? "Unknown"
        newState.focusedWindowTitle = focusedElement?.windowTitle
        newState.isUserActive = activityTracker.isUserActive
        newState.activityLevel = activityTracker.activityLevel
        newState.currentBrowserTab = browserState?.currentTab
        newState.browserContent = browserState?.pageContent

        currentState = newState

        // Detect meaningful changes and emit events
        detectChanges(from: previousState, to: newState)
    }

    private func detectChanges(from previous: SystemState, to current: SystemState) {
        // App switch
        if previous.frontmostApp != current.frontmostApp {
            let event = SystemEvent(
                type: .appSwitched,
                timestamp: Date(),
                source: "SystemObserver",
                data: [
                    "previousApp": previous.frontmostApp,
                    "currentApp": current.frontmostApp
                ]
            )
            emitEvent(event)
        }

        // Window focus change
        if previous.focusedWindowTitle != current.focusedWindowTitle,
           let newTitle = current.focusedWindowTitle {
            let event = SystemEvent(
                type: .windowFocusChanged,
                timestamp: Date(),
                source: "SystemObserver",
                data: [
                    "windowTitle": newTitle,
                    "app": current.frontmostApp
                ]
            )
            emitEvent(event)
        }

        // Browser tab change
        if previous.currentBrowserTab?.url != current.currentBrowserTab?.url,
           let tab = current.currentBrowserTab {
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
            emitEvent(event)
        }
    }

    func emitEvent(_ event: SystemEvent) {
        // Add to recent events
        recentEvents.append(event)
        if recentEvents.count > maxRecentEvents {
            recentEvents.removeFirst()
        }

        // Notify handlers
        for handler in eventHandlers {
            handler(event)
        }

        // Post notification for app-wide listeners
        NotificationCenter.default.post(
            name: .systemEventOccurred,
            object: event
        )

        AppLogger.shared.log("SystemObserver: Event - \(event.type.rawValue)", level: .debug)
    }
}

// MARK: - Observer Delegate Protocol

protocol SystemObserverDelegate: AnyObject {
    func emitEvent(_ event: SystemEvent)
}

extension SystemObserver: SystemObserverDelegate {}

// MARK: - System State

struct SystemState {
    var timestamp: Date = Date()
    var frontmostApp: String = "Unknown"
    var focusedWindowTitle: String?
    var isUserActive: Bool = true
    var activityLevel: Float = 1.0
    var currentBrowserTab: AppleScriptBridge.BrowserTab?
    var browserContent: String?
    var unreadMessageCount: Int = 0
    var recentDownloads: [String] = []
}

// MARK: - System Events

struct SystemEvent: Identifiable, Sendable {
    let id = UUID()
    let type: SystemEventType
    let timestamp: Date
    let source: String
    let data: [String: String]
}

enum SystemEventType: String, Sendable {
    // Activity events
    case userBecameActive
    case userBecameIdle
    case screenLocked
    case screenUnlocked

    // App events
    case appSwitched
    case windowFocusChanged

    // Browser events
    case browserTabChanged
    case pageContentLoaded
    case userReadingPage  // Stayed on page for extended time

    // iMessage events
    case newMessageReceived
    case messageRead

    // File system events
    case fileCreated
    case fileModified
    case fileDeleted
    case downloadCompleted
}

// MARK: - Notification Names

extension Notification.Name {
    static let systemEventOccurred = Notification.Name("systemEventOccurred")
}
