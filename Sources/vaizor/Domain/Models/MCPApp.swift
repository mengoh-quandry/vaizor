import Foundation
import SwiftUI

// MARK: - MCP App Protocol Models

/// Content received from MCP server for app rendering
struct MCPAppContent: Identifiable, Codable {
    let id: UUID
    let serverId: String
    let serverName: String
    let html: String
    let scripts: [String]?
    let styles: [String]?
    let title: String?
    let metadata: MCPAppMetadata?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        serverId: String,
        serverName: String,
        html: String,
        scripts: [String]? = nil,
        styles: [String]? = nil,
        title: String? = nil,
        metadata: MCPAppMetadata? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.serverId = serverId
        self.serverName = serverName
        self.html = html
        self.scripts = scripts
        self.styles = styles
        self.title = title
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

/// Metadata for MCP App
struct MCPAppMetadata: Codable {
    let version: String?
    let permissions: [MCPAppPermission]?
    let sandboxConfig: MCPAppSandboxConfig?
    let displayMode: MCPAppDisplayMode?
}

/// Display mode for MCP Apps
enum MCPAppDisplayMode: String, Codable {
    case inline = "inline"         // Displayed within message
    case panel = "panel"           // Displayed in artifact panel
    case floating = "floating"     // Floating window
    case fullscreen = "fullscreen" // Full screen overlay
}

/// Permissions that an MCP App might request
enum MCPAppPermission: String, Codable {
    case clipboard = "clipboard"
    case localStorage = "localStorage"
    case sessionStorage = "sessionStorage"
    case geolocation = "geolocation"
    case camera = "camera"
    case microphone = "microphone"
    case notifications = "notifications"
}

/// Sandbox configuration for MCP Apps
struct MCPAppSandboxConfig: Codable {
    let allowScripts: Bool
    let allowModals: Bool
    let allowForms: Bool
    let allowPointerLock: Bool
    let allowPopups: Bool
    let allowTopNavigation: Bool
    let allowDownloads: Bool

    static let restrictive = MCPAppSandboxConfig(
        allowScripts: true,
        allowModals: false,
        allowForms: true,
        allowPointerLock: false,
        allowPopups: false,
        allowTopNavigation: false,
        allowDownloads: false
    )

    static let permissive = MCPAppSandboxConfig(
        allowScripts: true,
        allowModals: true,
        allowForms: true,
        allowPointerLock: true,
        allowPopups: true,
        allowTopNavigation: false,
        allowDownloads: true
    )
}

// MARK: - MCP App Actions

/// Action sent from MCP App UI to host
struct MCPAppAction: Codable {
    let type: MCPAppActionType
    let payload: [String: AnyCodable]?
    let requestId: String?

    enum CodingKeys: String, CodingKey {
        case type, payload, requestId
    }
}

/// Types of actions that can be sent from MCP App
enum MCPAppActionType: String, Codable {
    // User interactions
    case buttonClick = "button_click"
    case formSubmit = "form_submit"
    case inputChange = "input_change"
    case selectionChange = "selection_change"

    // Lifecycle events
    case ready = "ready"
    case error = "error"
    case resize = "resize"
    case close = "close"

    // Data requests
    case fetchData = "fetch_data"
    case saveData = "save_data"

    // Navigation
    case navigate = "navigate"
    case refresh = "refresh"
}

/// Response sent from host back to MCP App
struct MCPAppResponse: Codable {
    let requestId: String
    let success: Bool
    let data: [String: AnyCodable]?
    let error: String?
}

// MARK: - MCP App Manager

/// Manages active MCP Apps and their communication
@MainActor
class MCPAppManager: ObservableObject {
    static let shared = MCPAppManager()

    @Published var activeApps: [UUID: MCPAppContent] = [:]
    @Published var appStates: [UUID: MCPAppState] = [:]

    private var actionHandlers: [UUID: (MCPAppAction) async -> MCPAppResponse] = [:]

    private init() {}

    /// Register an MCP App
    func registerApp(_ app: MCPAppContent, handler: @escaping (MCPAppAction) async -> MCPAppResponse) {
        activeApps[app.id] = app
        appStates[app.id] = MCPAppState()
        actionHandlers[app.id] = handler
        AppLogger.shared.log("Registered MCP App: \(app.title ?? app.id.uuidString) from \(app.serverName)", level: .info)
    }

    /// Unregister an MCP App
    func unregisterApp(_ appId: UUID) {
        activeApps.removeValue(forKey: appId)
        appStates.removeValue(forKey: appId)
        actionHandlers.removeValue(forKey: appId)
        AppLogger.shared.log("Unregistered MCP App: \(appId)", level: .info)
    }

    /// Handle action from MCP App
    func handleAction(_ action: MCPAppAction, from appId: UUID) async -> MCPAppResponse {
        guard let handler = actionHandlers[appId] else {
            return MCPAppResponse(
                requestId: action.requestId ?? UUID().uuidString,
                success: false,
                data: nil,
                error: "App not registered"
            )
        }

        AppLogger.shared.log("Handling MCP App action: \(action.type.rawValue) from \(appId)", level: .debug)
        return await handler(action)
    }

    /// Update app state
    func updateState(for appId: UUID, update: (inout MCPAppState) -> Void) {
        var state = appStates[appId] ?? MCPAppState()
        update(&state)
        appStates[appId] = state
    }
}

/// State tracking for an MCP App instance
struct MCPAppState {
    var isLoading: Bool = true
    var lastError: String?
    var lastActionTime: Date?
    var data: [String: Any] = [:]
}

// MARK: - MCP Apps Protocol Extension

/// Protocol message types for MCP Apps
enum MCPAppsMethod: String {
    case render = "mcp_apps/render"
    case update = "mcp_apps/update"
    case close = "mcp_apps/close"
    case action = "mcp_apps/action"
    case actionResponse = "mcp_apps/action_response"
}

/// Request to render an MCP App
struct MCPAppsRenderRequest: Codable {
    let html: String
    let scripts: [String]?
    let styles: [String]?
    let title: String?
    let displayMode: MCPAppDisplayMode?
    let permissions: [MCPAppPermission]?
    let sandboxConfig: MCPAppSandboxConfig?
}

/// Response to render request
struct MCPAppsRenderResponse: Codable {
    let appId: String
    let success: Bool
    let error: String?
}
