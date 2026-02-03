import Foundation
import AppKit
import Combine

// MARK: - Activity Tracker
// Monitors user activity (mouse/keyboard) to determine idle/active state
// Used by SystemObserver to adjust polling frequency

@MainActor
class ActivityTracker: ObservableObject {
    static let shared = ActivityTracker()

    // MARK: - Published State
    @Published private(set) var isUserActive: Bool = true
    @Published private(set) var isScreenLocked: Bool = false
    @Published private(set) var lastActivityTime: Date = Date()
    @Published private(set) var idleDuration: TimeInterval = 0

    // MARK: - Configuration
    var idleThreshold: TimeInterval = 60  // Seconds before considered idle

    // MARK: - Private
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var idleTimer: Timer?
    private var screenLockObserver: NSObjectProtocol?
    private var screenUnlockObserver: NSObjectProtocol?

    private init() {}

    // MARK: - Lifecycle

    func startTracking() {
        AppLogger.shared.log("ActivityTracker: Starting activity monitoring", level: .info)

        // Monitor global mouse and keyboard events
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recordActivity()
            }
        }

        // Also monitor local events (within our app)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]
        ) { [weak self] event in
            Task { @MainActor in
                self?.recordActivity()
            }
            return event
        }

        // Monitor screen lock/unlock
        let dnc = DistributedNotificationCenter.default()

        screenLockObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenLocked()
            }
        }

        screenUnlockObserver = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenUnlocked()
            }
        }

        // Start idle check timer
        startIdleTimer()
    }

    func stopTracking() {
        AppLogger.shared.log("ActivityTracker: Stopping activity monitoring", level: .info)

        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }

        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }

        if let observer = screenLockObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenLockObserver = nil
        }

        if let observer = screenUnlockObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenUnlockObserver = nil
        }

        idleTimer?.invalidate()
        idleTimer = nil
    }

    // MARK: - Activity Recording

    private func recordActivity() {
        lastActivityTime = Date()
        idleDuration = 0

        if !isUserActive {
            isUserActive = true
            AppLogger.shared.log("ActivityTracker: User became active", level: .debug)
            NotificationCenter.default.post(name: .userBecameActive, object: nil)
        }
    }

    private func startIdleTimer() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIdleState()
            }
        }
    }

    private func checkIdleState() {
        guard !isScreenLocked else { return }

        idleDuration = Date().timeIntervalSince(lastActivityTime)

        if idleDuration >= idleThreshold && isUserActive {
            isUserActive = false
            AppLogger.shared.log("ActivityTracker: User became idle (duration: \(Int(idleDuration))s)", level: .debug)
            NotificationCenter.default.post(name: .userBecameIdle, object: nil)
        }
    }

    // MARK: - Screen Lock Handling

    private func handleScreenLocked() {
        isScreenLocked = true
        isUserActive = false
        AppLogger.shared.log("ActivityTracker: Screen locked", level: .info)
        NotificationCenter.default.post(name: .screenLocked, object: nil)
    }

    private func handleScreenUnlocked() {
        isScreenLocked = false
        recordActivity()
        AppLogger.shared.log("ActivityTracker: Screen unlocked", level: .info)
        NotificationCenter.default.post(name: .screenUnlocked, object: nil)
    }

    // MARK: - Query Methods

    /// Returns recommended polling interval based on activity state
    var recommendedPollingInterval: TimeInterval {
        if isScreenLocked {
            return .infinity  // Don't poll when locked
        } else if isUserActive {
            return 1.5  // Fast polling when active
        } else {
            return 30.0  // Slow polling when idle
        }
    }

    /// Activity level from 0.0 (completely idle) to 1.0 (very active)
    var activityLevel: Float {
        if isScreenLocked { return 0.0 }

        // Decay activity level based on idle duration
        let decayFactor = max(0, 1.0 - Float(idleDuration / idleThreshold))
        return decayFactor
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userBecameActive = Notification.Name("userBecameActive")
    static let userBecameIdle = Notification.Name("userBecameIdle")
    static let screenLocked = Notification.Name("screenLocked")
    static let screenUnlocked = Notification.Name("screenUnlocked")
}
