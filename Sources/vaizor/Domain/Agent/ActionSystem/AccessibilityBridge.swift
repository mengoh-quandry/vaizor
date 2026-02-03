import Foundation
import AppKit
import ApplicationServices

// MARK: - Accessibility Bridge
// Wrapper for macOS Accessibility API to read screen content and simulate input

@MainActor
class AccessibilityBridge: ObservableObject {
    static let shared = AccessibilityBridge()

    @Published private(set) var hasAccessibilityPermission: Bool = false

    private init() {
        checkPermission()
    }

    // MARK: - Permission Management

    func checkPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestPermission() {
        // Open System Preferences to Accessibility pane
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Focused Element

    struct FocusedElement: Sendable {
        let appName: String
        let windowTitle: String?
        let role: String?
        let value: String?
        let selectedText: String?
    }

    func getFocusedElement() -> FocusedElement? {
        guard hasAccessibilityPermission else { return nil }

        let systemWide = AXUIElementCreateSystemWide()

        // Get focused application
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let app = focusedApp else {
            return nil
        }

        let appElement = app as! AXUIElement

        // Get app name
        var appName: AnyObject?
        AXUIElementCopyAttributeValue(appElement, kAXTitleAttribute as CFString, &appName)
        let appNameString = appName as? String ?? "Unknown"

        // Get focused window
        var focusedWindow: AnyObject?
        AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        var windowTitle: String?
        if let window = focusedWindow {
            var title: AnyObject?
            AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)
            windowTitle = title as? String
        }

        // Get focused UI element
        var focusedUIElement: AnyObject?
        AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedUIElement)

        var role: String?
        var value: String?
        var selectedText: String?

        if let element = focusedUIElement {
            let uiElement = element as! AXUIElement

            var roleValue: AnyObject?
            AXUIElementCopyAttributeValue(uiElement, kAXRoleAttribute as CFString, &roleValue)
            role = roleValue as? String

            var valueAttr: AnyObject?
            AXUIElementCopyAttributeValue(uiElement, kAXValueAttribute as CFString, &valueAttr)
            value = valueAttr as? String

            var selectedTextAttr: AnyObject?
            AXUIElementCopyAttributeValue(uiElement, kAXSelectedTextAttribute as CFString, &selectedTextAttr)
            selectedText = selectedTextAttr as? String
        }

        return FocusedElement(
            appName: appNameString,
            windowTitle: windowTitle,
            role: role,
            value: value,
            selectedText: selectedText
        )
    }

    // MARK: - Window Information

    struct WindowInfo: Sendable {
        let title: String
        let appName: String
        let bounds: CGRect
        let isMinimized: Bool
    }

    func getAllWindows() -> [WindowInfo] {
        guard hasAccessibilityPermission else { return [] }

        var windows: [WindowInfo] = []

        // Get all running applications
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        for app in runningApps {
            guard let appName = app.localizedName else { continue }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            var windowsValue: AnyObject?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                  let windowArray = windowsValue as? [AXUIElement] else {
                continue
            }

            for window in windowArray {
                var title: AnyObject?
                AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
                let titleString = title as? String ?? ""

                var position: AnyObject?
                var size: AnyObject?
                AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position)
                AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size)

                var point = CGPoint.zero
                var sizeValue = CGSize.zero
                if let pos = position {
                    AXValueGetValue(pos as! AXValue, .cgPoint, &point)
                }
                if let sz = size {
                    AXValueGetValue(sz as! AXValue, .cgSize, &sizeValue)
                }

                var minimized: AnyObject?
                AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized)
                let isMinimized = minimized as? Bool ?? false

                windows.append(WindowInfo(
                    title: titleString,
                    appName: appName,
                    bounds: CGRect(origin: point, size: sizeValue),
                    isMinimized: isMinimized
                ))
            }
        }

        return windows
    }

    // MARK: - Screen Content Reading

    func getWindowContent(pid: pid_t) -> String? {
        guard hasAccessibilityPermission else { return nil }

        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let window = focusedWindow else {
            return nil
        }

        return extractTextFromElement(window as! AXUIElement, depth: 0, maxDepth: 10)
    }

    private func extractTextFromElement(_ element: AXUIElement, depth: Int, maxDepth: Int) -> String {
        guard depth < maxDepth else { return "" }

        var texts: [String] = []

        // Try to get value
        var value: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
           let text = value as? String, !text.isEmpty {
            texts.append(text)
        }

        // Try to get title
        var title: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title) == .success,
           let text = title as? String, !text.isEmpty {
            texts.append(text)
        }

        // Try to get description
        var description: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description) == .success,
           let text = description as? String, !text.isEmpty {
            texts.append(text)
        }

        // Recurse into children
        var children: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
           let childArray = children as? [AXUIElement] {
            for child in childArray {
                let childText = extractTextFromElement(child, depth: depth + 1, maxDepth: maxDepth)
                if !childText.isEmpty {
                    texts.append(childText)
                }
            }
        }

        return texts.joined(separator: " ")
    }

    // MARK: - Input Simulation

    func simulateClick(at point: CGPoint) {
        guard hasAccessibilityPermission else { return }

        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)

        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }

    func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard hasAccessibilityPermission else { return }

        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    func simulateTyping(_ text: String) {
        guard hasAccessibilityPermission else { return }

        for char in text {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
            event?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [UniChar(char.unicodeScalars.first!.value)])
            event?.post(tap: .cghidEventTap)

            let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            upEvent?.post(tap: .cghidEventTap)

            // Small delay between characters
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    // MARK: - Element Actions

    func performAction(_ action: String, on element: AXUIElement) -> Bool {
        return AXUIElementPerformAction(element, action as CFString) == .success
    }

    func pressButton(element: AXUIElement) -> Bool {
        return performAction(kAXPressAction as String, on: element)
    }
}

// MARK: - Common Key Codes

extension AccessibilityBridge {
    enum KeyCode: CGKeyCode {
        case returnKey = 36
        case tab = 48
        case space = 49
        case delete = 51
        case escape = 53
        case command = 55
        case shift = 56
        case capsLock = 57
        case option = 58
        case control = 59
        case leftArrow = 123
        case rightArrow = 124
        case downArrow = 125
        case upArrow = 126
    }
}
