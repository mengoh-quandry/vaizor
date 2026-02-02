import Foundation
import GRDB

// MCP (Model Context Protocol) Server Manager
@MainActor
@preconcurrency
class MCPServerManager: ObservableObject {
    @Published var availableServers: [MCPServer] = []
    @Published var enabledServers: Set<String> = []
    @Published var availableTools: [MCPTool] = []
    @Published var availableResources: [MCPResource] = []
    @Published var availablePrompts: [MCPPrompt] = []
    @Published var serverErrors: [String: String] = [:] // Track errors by server ID

    // Progress tracking for long-running MCP operations
    @Published var activeProgress: [String: MCPProgress] = [:] // keyed by progressToken

    // Sampling handler for agentic MCP servers - set by the LLM provider
    var samplingHandler: ((MCPSamplingRequest) async -> [String: Any]?)?

    // Roots provider for workspace paths
    var workspaceRoots: [URL] = []

    private var serverProcesses: [String: MCPServerConnection] = [:]
    private let legacyConfigURL: URL

    init() {
        let baseDir: URL
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            baseDir = appSupport
        } else {
            baseDir = FileManager.default.temporaryDirectory
        }
        let vaizorDir = baseDir.appendingPathComponent("Vaizor")
        try? FileManager.default.createDirectory(at: vaizorDir, withIntermediateDirectories: true)
        legacyConfigURL = vaizorDir.appendingPathComponent("mcp-servers.json")

        loadServers()
    }

    func discoverServers() {
        // Reload from saved config
        loadServers()
    }

    private func loadServers() {
        do {
            var servers = try DatabaseManager.shared.dbQueue.read { db in
                try MCPServerRecord.fetchAll(db).map { $0.asModel() }
            }

            // If no servers in database, try to import from legacy JSON
            if servers.isEmpty {
                let imported = importLegacyServersIfNeeded()
                if !imported.isEmpty {
                    servers = imported
                    AppLogger.shared.log("Imported \(imported.count) MCP servers from legacy JSON", level: .info)
                } else {
                    // Check if legacy JSON exists but wasn't imported (maybe migration failed)
                    if FileManager.default.fileExists(atPath: legacyConfigURL.path) {
                        AppLogger.shared.log("Legacy MCP servers JSON found but import failed. Check logs for errors.", level: .warning)
                    }
                }
            }

            availableServers = servers
            
            // Only remove legacy JSON if we successfully loaded servers from database
            if !servers.isEmpty && FileManager.default.fileExists(atPath: legacyConfigURL.path) {
                // Keep legacy JSON as backup for now - don't delete immediately
                // User can manually delete it after confirming servers are working
                AppLogger.shared.log("MCP servers loaded from database. Legacy JSON kept as backup at: \(legacyConfigURL.path)", level: .info)
            }
            
            if servers.isEmpty {
                AppLogger.shared.log("No MCP servers found. Add servers in Settings → MCP Servers", level: .info)
            } else {
                AppLogger.shared.log("Loaded \(servers.count) MCP server(s) from database", level: .info)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to load MCP servers")
            availableServers = []
            
            // Try to recover from legacy JSON if database read failed
            let recovered = importLegacyServersIfNeeded()
            if !recovered.isEmpty {
                availableServers = recovered
                AppLogger.shared.log("Recovered \(recovered.count) MCP server(s) from legacy JSON after database error", level: .warning)
            }
        }

        // Servers are started on-demand to reduce launch overhead.
    }

    private func importLegacyServersIfNeeded() -> [MCPServer] {
        guard FileManager.default.fileExists(atPath: legacyConfigURL.path),
              let data = try? Data(contentsOf: legacyConfigURL),
              let servers = try? JSONDecoder().decode([MCPServer].self, from: data) else {
            return []
        }

        // Only import if we have servers to import
        guard !servers.isEmpty else {
            return []
        }

        do {
            // Check if servers already exist in database to avoid duplicates
            let existingIds = try DatabaseManager.shared.dbQueue.read { db in
                try MCPServerRecord.fetchAll(db).map { $0.id }
            }
            
            var importedCount = 0
            try DatabaseManager.shared.dbQueue.write { db in
                for server in servers {
                    // Skip if already exists
                    if existingIds.contains(server.id) {
                        continue
                    }
                    try MCPServerRecord(server).save(db)
                    importedCount += 1
                }
            }
            
            if importedCount > 0 {
                AppLogger.shared.log("Imported \(importedCount) new MCP server(s) from legacy JSON to database", level: .info)
            } else {
                AppLogger.shared.log("All MCP servers from legacy JSON already exist in database", level: .info)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to migrate MCP servers from legacy JSON")
            // Return servers anyway so they can be used even if database save failed
            return servers
        }

        return servers
    }

    private func upsertServer(_ server: MCPServer) {
        do {
            try DatabaseManager.shared.dbQueue.write { db in
                try MCPServerRecord(server).save(db)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to save MCP server")
        }
    }

    private func deleteServer(_ server: MCPServer) {
        do {
            _ = try DatabaseManager.shared.dbQueue.write { db in
                try MCPServerRecord.deleteOne(db, key: server.id)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to delete MCP server")
        }
    }

    func addServer(_ server: MCPServer) {
        availableServers.append(server)
        upsertServer(server)
    }

    func removeServer(_ server: MCPServer) {
        Task {
            await stopServer(server)
        }
        availableServers.removeAll { $0.id == server.id }
        deleteServer(server)
    }

    func updateServer(_ server: MCPServer) {
        if let index = availableServers.firstIndex(where: { $0.id == server.id }) {
            let wasRunning = enabledServers.contains(server.id)
            let oldServer = availableServers[index]

            availableServers[index] = server
            upsertServer(server)

            if wasRunning {
                // Stop and restart in a single Task to ensure proper sequencing
                Task {
                    await stopServer(oldServer)
                    try? await startServer(server)
                }
            }
        }
    }

    /// Commit imported servers from the preview panel
    func commitImported(_ servers: [MCPServer]) {
        for server in servers {
            addServer(server)
        }
    }

    /// Parse unstructured folder content to discover MCP servers
    func parseUnstructured(
        from folder: URL,
        config: LLMConfiguration,
        provider: any LLMProviderProtocol
    ) async -> (servers: [MCPServer], errors: [String]) {
        var result: [MCPServer] = []
        var errors: [String] = []

        // Use the enhanced import from MCPImportEnhanced
        let importResult = await importUnstructuredEnhanced(
            from: folder,
            config: config,
            provider: provider,
            progressHandler: { _ in }
        )

        switch importResult {
        case .success(let servers):
            result = servers
        case .failure(let error):
            errors.append(error.localizedDescription)
        }

        return (result, errors)
    }

    func testConnection(_ server: MCPServer) async -> (Bool, String) {
        do {
            let process = Process()

            // Check if command exists
            let whichProcess = Process()
            whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            whichProcess.arguments = [server.command]

            let whichPipe = Pipe()
            whichProcess.standardOutput = whichPipe
            whichProcess.standardError = Pipe()

            try whichProcess.run()
            whichProcess.waitUntilExit()

            if whichProcess.terminationStatus != 0 {
                return (false, "Command '\(server.command)' not found in PATH")
            }

            let whichData = whichPipe.fileHandleForReading.readDataToEndOfFile()
            guard let commandPath = String(data: whichData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !commandPath.isEmpty else {
                return (false, "Command not found")
            }

            // Try to run the server briefly to test
            process.executableURL = URL(fileURLWithPath: commandPath)
            process.arguments = server.args

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()

            // Give it a moment to start
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            if process.isRunning {
                process.terminate()
                return (true, "Connection successful")
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return (false, "Server failed to start: \(errorOutput.prefix(100))")
            }
        } catch {
            return (false, "Error: \(error.localizedDescription)")
        }
    }

    func startServer(_ server: MCPServer) async throws {
        AppLogger.shared.log("Starting MCP server: \(server.name) (ID: \(server.id))", level: .info)

        // Check if already running
        if serverProcesses.keys.contains(server.id) {
            AppLogger.shared.log("MCP server \(server.name) is already running", level: .info)
            // Already running, ensure it's in enabled set
            await MainActor.run {
                _ = enabledServers.insert(server.id)
            }
            return
        }

        // Track what we add for cleanup on error
        var connection: MCPServerConnection?
        var toolsAdded: [MCPTool] = []
        var connectionStarted = false

        do {
            // Resolve command path
            var commandPath = server.command
            AppLogger.shared.log("Resolving command path for: \(server.command)", level: .debug)
            if !commandPath.hasPrefix("/") {
                do {
                    commandPath = try await resolveCommandPath(server.command)
                    AppLogger.shared.log("Resolved command path to: \(commandPath)", level: .debug)
                } catch {
                    AppLogger.shared.logError(error, context: "Failed to resolve command path for \(server.command)")
                    throw error
                }
            }

            // Create MCP server connection with notification callbacks
            AppLogger.shared.log("Creating MCP server connection with command: \(commandPath), args: \(server.args)", level: .debug)

            // Create notification callbacks to handle server events
            let callbacks = MCPNotificationCallbacks(
                onToolsListChanged: { [weak self] in
                    guard let self = self else { return }
                    await self.refreshToolsForServer(serverId: server.id)
                },
                onResourcesListChanged: { [weak self] in
                    guard let self = self else { return }
                    await self.refreshResourcesForServer(serverId: server.id)
                },
                onResourceUpdated: { [weak self] uri in
                    guard self != nil else { return }
                    await MainActor.run {
                        AppLogger.shared.log("Resource updated: \(uri) from server \(server.name)", level: .info)
                    }
                    // Could emit an event or refresh specific resource content here
                },
                onPromptsListChanged: { [weak self] in
                    guard let self = self else { return }
                    await self.refreshPromptsForServer(serverId: server.id)
                },
                onProgress: { [weak self] progress in
                    guard let self = self else { return }
                    await MainActor.run {
                        self.activeProgress[progress.progressToken] = progress
                        // Remove completed progress after a delay
                        if let total = progress.total, progress.progress >= total {
                            Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                                _ = await MainActor.run {
                                    self.activeProgress.removeValue(forKey: progress.progressToken)
                                }
                            }
                        }
                    }
                },
                onLogMessage: { logMessage in
                    await MainActor.run {
                        let levelMap: [String: LogLevel] = [
                            "debug": .debug,
                            "info": .info,
                            "warning": .warning,
                            "error": .error
                        ]
                        let level = levelMap[logMessage.level] ?? .info
                        let dataStr = logMessage.data.map { String(describing: $0) } ?? ""
                        AppLogger.shared.log("MCP[\(logMessage.logger ?? "server")]: \(dataStr)", level: level)
                    }
                },
                onSamplingRequest: { [weak self] request in
                    guard let self = self else { return nil }
                    // Route sampling request to the configured handler
                    return await self.samplingHandler?(request)
                },
                onRootsListRequest: { [weak self] in
                    guard let self = self else { return [] }
                    // Return workspace roots as MCP root objects
                    return await MainActor.run {
                        self.workspaceRoots.map { url in
                            [
                                "uri": url.absoluteString,
                                "name": url.lastPathComponent
                            ]
                        }
                    }
                }
            )

            // Determine working directory: prefer workingDirectory, fall back to path
            let workingDirURL: URL?
            if let workingDir = server.workingDirectory {
                workingDirURL = URL(fileURLWithPath: workingDir)
            } else {
                workingDirURL = server.path
            }

            connection = try MCPServerConnection(
                command: commandPath,
                arguments: server.args,
                workingDirectory: workingDirURL,
                env: server.env,
                onDisconnect: { [weak self] serverId in
                    Task { @MainActor in
                        self?.handleServerDisconnection(serverId: serverId)
                    }
                },
                serverId: server.id,
                notificationCallbacks: callbacks
            )
            AppLogger.shared.log("MCP server connection object created successfully", level: .debug)

            guard let conn = connection else {
                throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create MCP server connection"])
            }

            // Start the process
            AppLogger.shared.log("Starting MCP server process", level: .debug)
            try conn.start()
            connectionStarted = true
            AppLogger.shared.log("MCP server process started", level: .debug)

            // Initialize the MCP server
            AppLogger.shared.log("Initializing MCP server protocol", level: .debug)
            try await conn.initialize()
            AppLogger.shared.log("MCP server initialized successfully", level: .debug)

            // Discover available tools, resources, and prompts in parallel
            AppLogger.shared.log("Discovering MCP server capabilities", level: .debug)

            async let toolsFuture = conn.listTools()
            async let resourcesFuture = conn.listResources()
            async let promptsFuture = conn.listPrompts()

            let tools = try await toolsFuture
            let resources = try await resourcesFuture
            let prompts = try await promptsFuture

            AppLogger.shared.log("Discovered \(tools.count) tools, \(resources.count) resources, \(prompts.count) prompts from MCP server", level: .info)

            // Atomic state update with cleanup tracking
            await MainActor.run {
                self.serverProcesses[server.id] = conn
                self.enabledServers.insert(server.id)

                // Clear any previous errors for this server
                self.serverErrors.removeValue(forKey: server.id)

                // Add tools with server prefix
                for tool in tools {
                    var prefixedTool = tool
                    prefixedTool.serverId = server.id
                    prefixedTool.serverName = server.name
                    self.availableTools.append(prefixedTool)
                    toolsAdded.append(prefixedTool)
                }

                // Add resources with server prefix
                for resource in resources {
                    var prefixedResource = resource
                    prefixedResource.serverId = server.id
                    prefixedResource.serverName = server.name
                    self.availableResources.append(prefixedResource)
                }

                // Add prompts with server prefix
                for prompt in prompts {
                    var prefixedPrompt = prompt
                    prefixedPrompt.serverId = server.id
                    prefixedPrompt.serverName = server.name
                    self.availablePrompts.append(prefixedPrompt)
                }

                AppLogger.shared.log("MCP server \(server.name) started successfully with \(tools.count) tools, \(resources.count) resources, \(prompts.count) prompts", level: .info)
            }
        } catch {
            // Cleanup on any error
            AppLogger.shared.logError(error, context: "Failed to start MCP server \(server.name)")
            
            if connectionStarted {
                await connection?.stop()
            }
            
            await MainActor.run {
                self.serverProcesses.removeValue(forKey: server.id)
                self.enabledServers.remove(server.id)
                for tool in toolsAdded {
                    self.availableTools.removeAll { $0.id == tool.id }
                }
                // Store error for UI display
                self.serverErrors[server.id] = error.localizedDescription
            }
            
            throw error
        }
    }
    
    private func handleServerDisconnection(serverId: String) {
        AppLogger.shared.log("MCP server disconnected unexpectedly (ID: \(serverId))", level: .warning)

        // Find server name for logging
        let serverName = availableServers.first(where: { $0.id == serverId })?.name ?? "Unknown"

        // Clean up state
        serverProcesses.removeValue(forKey: serverId)
        enabledServers.remove(serverId)
        availableTools.removeAll { $0.serverId == serverId }
        availableResources.removeAll { $0.serverId == serverId }
        availablePrompts.removeAll { $0.serverId == serverId }
        serverErrors[serverId] = "Server disconnected unexpectedly"
        
        AppLogger.shared.log("Cleaned up disconnected MCP server: \(serverName)", level: .info)
    }
    
    func clearError(for serverId: String) {
        serverErrors.removeValue(forKey: serverId)
    }

    // MARK: - Dynamic Refresh Methods (for MCP notifications)

    /// Refresh tools for a specific server when notified of changes
    private func refreshToolsForServer(serverId: String) async {
        guard let connection = serverProcesses[serverId] else {
            AppLogger.shared.log("Cannot refresh tools: server \(serverId) not connected", level: .warning)
            return
        }

        do {
            let tools = try await connection.listTools()
            await MainActor.run {
                // Remove old tools from this server
                self.availableTools.removeAll { $0.serverId == serverId }

                // Add refreshed tools with server prefix
                let serverName = self.availableServers.first(where: { $0.id == serverId })?.name
                for tool in tools {
                    var prefixedTool = tool
                    prefixedTool.serverId = serverId
                    prefixedTool.serverName = serverName
                    self.availableTools.append(prefixedTool)
                }

                AppLogger.shared.log("Refreshed \(tools.count) tools for server \(serverName ?? serverId)", level: .info)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to refresh tools for server \(serverId)")
        }
    }

    /// Refresh resources for a specific server when notified of changes
    private func refreshResourcesForServer(serverId: String) async {
        guard let connection = serverProcesses[serverId] else {
            AppLogger.shared.log("Cannot refresh resources: server \(serverId) not connected", level: .warning)
            return
        }

        do {
            let resources = try await connection.listResources()
            await MainActor.run {
                // Remove old resources from this server
                self.availableResources.removeAll { $0.serverId == serverId }

                // Add refreshed resources with server prefix
                let serverName = self.availableServers.first(where: { $0.id == serverId })?.name
                for resource in resources {
                    var prefixedResource = resource
                    prefixedResource.serverId = serverId
                    prefixedResource.serverName = serverName
                    self.availableResources.append(prefixedResource)
                }

                AppLogger.shared.log("Refreshed \(resources.count) resources for server \(serverName ?? serverId)", level: .info)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to refresh resources for server \(serverId)")
        }
    }

    /// Refresh prompts for a specific server when notified of changes
    private func refreshPromptsForServer(serverId: String) async {
        guard let connection = serverProcesses[serverId] else {
            AppLogger.shared.log("Cannot refresh prompts: server \(serverId) not connected", level: .warning)
            return
        }

        do {
            let prompts = try await connection.listPrompts()
            await MainActor.run {
                // Remove old prompts from this server
                self.availablePrompts.removeAll { $0.serverId == serverId }

                // Add refreshed prompts with server prefix
                let serverName = self.availableServers.first(where: { $0.id == serverId })?.name
                for prompt in prompts {
                    var prefixedPrompt = prompt
                    prefixedPrompt.serverId = serverId
                    prefixedPrompt.serverName = serverName
                    self.availablePrompts.append(prefixedPrompt)
                }

                AppLogger.shared.log("Refreshed \(prompts.count) prompts for server \(serverName ?? serverId)", level: .info)
            }
        } catch {
            AppLogger.shared.logError(error, context: "Failed to refresh prompts for server \(serverId)")
        }
    }

    // MARK: - Resource Subscription Management

    /// Subscribe to updates for a specific resource
    func subscribeToResource(uri: String) async throws {
        guard let resource = availableResources.first(where: { $0.uri == uri }),
              let serverId = resource.serverId,
              let connection = serverProcesses[serverId] else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Resource not found or server not connected"])
        }

        try await connection.subscribeToResource(uri: uri)
        AppLogger.shared.log("Subscribed to resource: \(uri)", level: .info)
    }

    /// Unsubscribe from updates for a specific resource
    func unsubscribeFromResource(uri: String) async throws {
        guard let resource = availableResources.first(where: { $0.uri == uri }),
              let serverId = resource.serverId,
              let connection = serverProcesses[serverId] else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Resource not found or server not connected"])
        }

        try await connection.unsubscribeFromResource(uri: uri)
        AppLogger.shared.log("Unsubscribed from resource: \(uri)", level: .info)
    }

    // MARK: - Path Resolution

    private func resolveCommandPath(_ command: String) async throws -> String {
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = [command]

        let whichPipe = Pipe()
        whichProcess.standardOutput = whichPipe
        whichProcess.standardError = Pipe()

        try whichProcess.run()
        whichProcess.waitUntilExit()

        guard whichProcess.terminationStatus == 0 else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Command '\(command)' not found in PATH"])
        }

        let data = whichPipe.fileHandleForReading.readDataToEndOfFile()
        guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Command not found"])
        }

        return path
    }

    func stopServer(_ server: MCPServer) async {
        AppLogger.shared.log("Stopping MCP server: \(server.name) (ID: \(server.id))", level: .info)
        guard let connection = serverProcesses[server.id] else {
            AppLogger.shared.log("MCP server \(server.name) is not running", level: .warning)
            return
        }

        await connection.stop()
        serverProcesses.removeValue(forKey: server.id)
        enabledServers.remove(server.id)

        // Remove tools, resources, and prompts from this server
        availableTools.removeAll { $0.serverId == server.id }
        availableResources.removeAll { $0.serverId == server.id }
        availablePrompts.removeAll { $0.serverId == server.id }

        AppLogger.shared.log("MCP server \(server.name) stopped", level: .info)
    }

    /// Cancel all pending requests for a specific server
    func cancelRequests(for server: MCPServer) async {
        guard let connection = serverProcesses[server.id] else {
            AppLogger.shared.log("Server \(server.name) not running, no requests to cancel", level: .debug)
            return
        }
        await connection.cancelAllRequests()
    }

    /// Cancel all pending requests across all servers
    func cancelAllRequests() async {
        for (serverId, connection) in serverProcesses {
            await connection.cancelAllRequests()
            if let server = availableServers.first(where: { $0.id == serverId }) {
                AppLogger.shared.log("Cancelled all requests for server: \(server.name)", level: .info)
            }
        }
    }

    func callTool(toolName: String, arguments: [String: Any], conversationId: UUID? = nil) async -> MCPToolResult {
        // Check for built-in tools first (respecting enabled/disabled state)
        let toolsManager = BuiltInToolsManager.shared

        if toolName == "web_search" {
            guard toolsManager.isToolEnabled("web_search") else {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Web search tool is currently disabled. Enable it in the tools menu to use this feature.")],
                    isError: true
                )
            }
            return await callBuiltInWebSearch(arguments: arguments)
        }

        if toolName == "execute_code" {
            guard toolsManager.isToolEnabled("execute_code") else {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Code execution tool is currently disabled. Enable it in the tools menu to use this feature.")],
                    isError: true
                )
            }
            return await callBuiltInCodeExecution(arguments: arguments, conversationId: conversationId ?? UUID())
        }

        if toolName == "create_artifact" {
            guard toolsManager.isToolEnabled("create_artifact") else {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Artifact creation tool is currently disabled. Enable it in the tools menu to use this feature.")],
                    isError: true
                )
            }
            return await callBuiltInCreateArtifact(arguments: arguments)
        }

        if toolName == "browser_action" {
            guard toolsManager.isToolEnabled("browser_action") else {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Browser control tool is currently disabled. Enable it in the tools menu to use this feature.")],
                    isError: true
                )
            }
            return await callBuiltInBrowserAction(arguments: arguments)
        }

        // Find which server provides this tool
        guard let tool = availableTools.first(where: { $0.name == toolName }),
              let serverId = tool.serverId,
              let connection = serverProcesses[serverId] else {
            let errorMsg = "Tool '\(toolName)' not found or server not running"
            AppLogger.shared.log(errorMsg, level: .error)
            return MCPToolResult(
                content: [MCPContent(type: "text", text: errorMsg)],
                isError: true
            )
        }

        AppLogger.shared.log("Calling MCP tool: \(toolName) on server \(tool.serverName ?? "unknown")", level: .info)
        do {
            let safeArguments = wrapAnyCodable(arguments)
            return try await connection.callTool(name: toolName, arguments: safeArguments)
        } catch {
            AppLogger.shared.logError(error, context: "Failed to call tool \(toolName)")
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error calling tool '\(toolName)': \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    /// Call built-in code execution tool
    private func callBuiltInCodeExecution(arguments: [String: Any], conversationId: UUID) async -> MCPToolResult {
        AppLogger.shared.log("Calling built-in code execution tool", level: .info)

        guard let languageString = arguments["language"] as? String,
              let codeLanguage = CodeLanguage(rawValue: languageString),
              let code = arguments["code"] as? String else {
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error: 'language' and 'code' parameters are required for code execution")],
                isError: true
            )
        }

        let timeout = (arguments["timeout"] as? Double) ?? 30.0
        let capabilities = (arguments["capabilities"] as? [String])?.compactMap { ExecutionCapability(rawValue: $0) } ?? []
        
        do {
            let result = try await ExecutionBroker.shared.requestExecution(
                conversationId: conversationId,
                language: codeLanguage,
                code: code,
                requestedCapabilities: capabilities,
                timeout: timeout
            )
            
            var output = "## Code Execution Result\n\n"
            output += "**Exit Code:** \(result.exitCode)\n"
            output += "**Duration:** \(String(format: "%.2f", result.duration))s\n"
            output += "**Memory:** \(formatBytes(result.resourceUsage.memoryBytes))\n\n"
            
            if !result.stdout.isEmpty {
                output += "### Output\n```\n\(result.stdout)\n```\n\n"
            }
            
            if !result.stderr.isEmpty {
                output += "### Errors\n```\n\(result.stderr)\n```\n\n"
            }
            
            if result.secretsDetected {
                output += "⚠️ **Note:** Secrets detected and redacted in output\n"
            }
            
            return MCPToolResult(
                content: [MCPContent(type: "text", text: output)],
                isError: result.exitCode != 0
            )
        } catch {
            AppLogger.shared.logError(error, context: "Code execution failed")
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error executing code: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Call built-in web search tool
    private func callBuiltInWebSearch(arguments: [String: Any]) async -> MCPToolResult {
        AppLogger.shared.log("Calling built-in web search tool", level: .info)
        
        guard let query = arguments["query"] as? String ?? arguments["q"] as? String else {
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error: 'query' parameter is required for web_search")],
                isError: true
            )
        }
        
        let maxResults = (arguments["max_results"] as? Int) ?? (arguments["maxResults"] as? Int) ?? 5
        
        do {
            let results = try await WebSearchService.shared.search(query, maxResults: maxResults)
            
            if results.isEmpty {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "No search results found for: \(query)")],
                    isError: false
                )
            }
            
            // Format results as markdown
            var resultText = "## Web Search Results for: \(query)\n\n"
            for (index, result) in results.enumerated() {
                resultText += "### \(index + 1). \(result.title)\n"
                resultText += "**URL:** \(result.url)\n"
                resultText += "**Snippet:** \(result.snippet)\n"
                resultText += "**Source:** \(result.source)\n\n"
            }
            
            return MCPToolResult(
                content: [MCPContent(type: "text", text: resultText)],
                isError: false
            )
        } catch {
            AppLogger.shared.logError(error, context: "Web search failed")
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error performing web search: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    /// Call built-in browser automation tool
    private func callBuiltInBrowserAction(arguments: [String: Any]) async -> MCPToolResult {
        AppLogger.shared.log("Calling built-in browser action tool", level: .info)

        guard let action = arguments["action"] as? String else {
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error: 'action' parameter is required for browser_action")],
                isError: true
            )
        }

        let browserService = BrowserService.shared

        switch action.lowercased() {
        case "navigate":
            guard let url = arguments["url"] as? String else {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Error: 'url' parameter is required for navigate action")],
                    isError: true
                )
            }

            await browserService.navigate(to: url)

            // Wait for page to load
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            if let error = browserService.error {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Navigation error: \(error)")],
                    isError: true
                )
            }

            let title = browserService.currentURL?.absoluteString ?? url
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Navigated to: \(title)\n\nUse 'extract' action to get page content for analysis.")],
                isError: false
            )

        case "extract":
            guard let content = await browserService.extractPageContent() else {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Error: Could not extract page content. Make sure a page is loaded.")],
                    isError: true
                )
            }

            var resultText = "## Page Content Extraction\n\n"
            resultText += "**Title:** \(content.title)\n"
            resultText += "**URL:** \(content.url.absoluteString)\n"

            if let description = content.metadata.description {
                resultText += "**Description:** \(description)\n"
            }

            resultText += "\n### Main Text Content\n"
            // Truncate text to avoid token overflow
            let truncatedText = String(content.text.prefix(5000))
            resultText += truncatedText
            if content.text.count > 5000 {
                resultText += "\n...[truncated, \(content.text.count - 5000) more characters]"
            }

            resultText += "\n\n### Links (\(content.links.count) total)\n"
            for link in content.links.prefix(20) {
                resultText += "- [\(link.text.prefix(50))](\(link.href))\n"
            }

            if content.links.count > 20 {
                resultText += "\n...and \(content.links.count - 20) more links"
            }

            if !content.forms.isEmpty {
                resultText += "\n\n### Forms (\(content.forms.count) total)\n"
                for form in content.forms {
                    resultText += "- Form: \(form.id) (\(form.method)) - \(form.fields.count) fields\n"
                }
            }

            return MCPToolResult(
                content: [MCPContent(type: "text", text: resultText)],
                isError: false
            )

        case "screenshot":
            guard let _ = await browserService.takeScreenshot() else {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Error: Could not take screenshot. Make sure a page is loaded.")],
                    isError: true
                )
            }

            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Screenshot captured successfully. The screenshot has been copied to the clipboard and can be sent to a vision-capable model for analysis.")],
                isError: false
            )

        case "click":
            guard let selector = arguments["selector"] as? String else {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Error: 'selector' parameter is required for click action")],
                    isError: true
                )
            }

            let elements = await browserService.findElements(matching: selector)
            guard let element = elements.first else {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Error: No element found matching: \(selector)")],
                    isError: true
                )
            }

            let success = await browserService.click(element: element, requireConfirmation: true)
            return MCPToolResult(
                content: [MCPContent(type: "text", text: success ? "Clicked element: \(element.selector)" : "Click action was denied or failed")],
                isError: !success
            )

        case "type":
            guard let selector = arguments["selector"] as? String,
                  let text = arguments["text"] as? String else {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Error: 'selector' and 'text' parameters are required for type action")],
                    isError: true
                )
            }

            let elements = await browserService.findElements(matching: selector)
            guard let element = elements.first else {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Error: No element found matching: \(selector)")],
                    isError: true
                )
            }

            let success = await browserService.type(text: text, into: element, requireConfirmation: true)
            return MCPToolResult(
                content: [MCPContent(type: "text", text: success ? "Typed text into element: \(element.selector)" : "Type action was denied or failed")],
                isError: !success
            )

        case "find":
            guard let selector = arguments["selector"] as? String else {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "Error: 'selector' parameter is required for find action")],
                    isError: true
                )
            }

            let elements = await browserService.findElements(matching: selector)
            if elements.isEmpty {
                return MCPToolResult(
                    content: [MCPContent(type: "text", text: "No elements found matching: \(selector)")],
                    isError: false
                )
            }

            var resultText = "## Found \(elements.count) Elements\n\n"
            for (index, element) in elements.prefix(20).enumerated() {
                resultText += "### \(index + 1). \(element.tagName)\n"
                resultText += "- **Selector:** `\(element.selector)`\n"
                if let text = element.text {
                    resultText += "- **Text:** \(text.prefix(100))\n"
                }
                resultText += "- **Clickable:** \(element.isClickable ? "Yes" : "No")\n"
                resultText += "- **Visible:** \(element.isVisible ? "Yes" : "No")\n\n"
            }

            if elements.count > 20 {
                resultText += "...and \(elements.count - 20) more elements"
            }

            return MCPToolResult(
                content: [MCPContent(type: "text", text: resultText)],
                isError: false
            )

        case "scroll":
            let scrollPos = arguments["scroll_position"] as? String ?? "bottom"
            let selector = arguments["selector"] as? String

            switch scrollPos.lowercased() {
            case "top":
                await browserService.scroll(to: .top)
            case "bottom":
                await browserService.scroll(to: .bottom)
            case "element":
                if let selector = selector {
                    await browserService.scroll(to: .element(selector: selector))
                } else {
                    return MCPToolResult(
                        content: [MCPContent(type: "text", text: "Error: 'selector' parameter required when scroll_position is 'element'")],
                        isError: true
                    )
                }
            default:
                await browserService.scroll(to: .bottom)
            }

            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Scrolled to: \(scrollPos)")],
                isError: false
            )

        default:
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error: Unknown action '\(action)'. Valid actions: navigate, click, type, extract, screenshot, find, scroll")],
                isError: true
            )
        }
    }

    /// Sanitize and validate artifact content from LLM
    /// Sanitize artifact content by removing imports, exports, and instructions
    func sanitizeArtifactContent(_ content: String, type: String) -> String {
        var result = content

        // Extract from markdown code fences if wrapped
        if let fenceRegex = try? NSRegularExpression(pattern: #"```(?:jsx?|tsx?|javascript|typescript|react)?\s*([\s\S]*?)```"#, options: []),
           let match = fenceRegex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
           let range = Range(match.range(at: 1), in: result) {
            result = String(result[range])
            AppLogger.shared.log("Extracted artifact code from markdown fence", level: .debug)
        }

        // Remove import statements (we use globals)
        result = result.replacingOccurrences(
            of: #"import\s+.*?from\s+['\"][^'\"]+['\"];?\s*"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"import\s+['\"][^'\"]+['\"];?\s*"#,
            with: "",
            options: .regularExpression
        )

        // Remove export statements
        result = result.replacingOccurrences(
            of: #"export\s+default\s+"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"export\s+\{[^}]*\};?\s*"#,
            with: "",
            options: .regularExpression
        )

        // Remove instructions/prose that slipped through
        let instructionPatterns = [
            #"^#+ .*$"#,  // Markdown headers
            #"^\d+\.\s+(?:Create|Install|Run|Open|Add|Copy|First|Then|Next).*$"#,  // Numbered instructions
            #"^(?:npm|npx|yarn|pnpm)\s+.*$"#,  // Package manager commands
            #"^(?:cd|mkdir|touch)\s+.*$"#,  // Shell commands
            #"^// ?(?:In|Create|Add|File:).*$"#,  // Comment instructions
            #"^/\*\*?[\s\S]*?File:.*?\*/"#,  // Block comment with file path
        ]

        for pattern in instructionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive]) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Clean up excessive blank lines
        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        // Trim
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate: For React, ensure it has a function component
        if type == "react" && !result.contains("function ") && !result.contains("const ") {
            AppLogger.shared.log("Warning: React artifact may not contain a valid component", level: .warning)
        }

        return result
    }

    /// Call built-in artifact creation tool
    private func callBuiltInCreateArtifact(arguments: [String: Any]) async -> MCPToolResult {
        AppLogger.shared.log("Calling built-in create_artifact tool", level: .info)

        guard let typeString = arguments["type"] as? String,
              let title = arguments["title"] as? String,
              let rawContent = arguments["content"] as? String else {
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error: 'type', 'title', and 'content' parameters are required for create_artifact")],
                isError: true
            )
        }

        guard let artifactType = ArtifactType(rawValue: typeString) else {
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error: Invalid artifact type '\(typeString)'. Must be one of: react, html, svg, mermaid")],
                isError: true
            )
        }

        // Sanitize and validate the content
        let content = sanitizeArtifactContent(rawContent, type: typeString)

        if content.isEmpty {
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error: Artifact content is empty after sanitization. Please provide valid component code, not setup instructions.")],
                isError: true
            )
        }

        AppLogger.shared.log("Creating artifact: type=\(typeString), title=\(title), content length: \(content.count) (sanitized from \(rawContent.count))", level: .info)

        // Return artifact as JSON that the UI can parse and render
        let artifactJSON: [String: Any] = [
            "artifact_type": typeString,
            "artifact_title": title,
            "artifact_content": content
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: artifactJSON),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return MCPToolResult(
                content: [MCPContent(type: "artifact", text: jsonString)],
                isError: false
            )
        }

        // Fallback if JSON encoding fails
        return MCPToolResult(
            content: [MCPContent(type: "text", text: "Created \(artifactType.displayName): \(title)\n\n```\(typeString)\n\(content)\n```")],
            isError: false
        )
    }

    func ensureServersStarted() async {
        guard enabledServers.isEmpty else { return }
        for server in availableServers {
            do {
                try await startServer(server)
                AppLogger.shared.log("Started MCP server on demand: \(server.name)", level: .info)
            } catch {
                AppLogger.shared.logError(error, context: "Failed to start MCP server on demand \(server.name)")
            }
        }
    }

    // MARK: - Resource Operations

    /// Read content of a specific MCP resource
    func readResource(uri: String) async -> MCPResourceContent? {
        // Find which server provides this resource
        guard let resource = availableResources.first(where: { $0.uri == uri }),
              let serverId = resource.serverId,
              let connection = serverProcesses[serverId] else {
            AppLogger.shared.log("Resource '\(uri)' not found or server not running", level: .warning)
            return nil
        }

        do {
            let content = try await connection.readResource(uri: uri)
            AppLogger.shared.log("Read resource \(uri) from server \(resource.serverName ?? "unknown")", level: .info)
            return content
        } catch {
            AppLogger.shared.logError(error, context: "Failed to read resource \(uri)")
            return nil
        }
    }

    // MARK: - Prompt Operations

    /// Get and render an MCP prompt with optional arguments
    func getPrompt(name: String, arguments: [String: String] = [:]) async -> MCPPromptResult? {
        // Find which server provides this prompt
        guard let prompt = availablePrompts.first(where: { $0.name == name }),
              let serverId = prompt.serverId,
              let connection = serverProcesses[serverId] else {
            AppLogger.shared.log("Prompt '\(name)' not found or server not running", level: .warning)
            return nil
        }

        do {
            let result = try await connection.getPrompt(name: name, arguments: arguments)
            AppLogger.shared.log("Got prompt \(name) from server \(prompt.serverName ?? "unknown")", level: .info)
            return result
        } catch {
            AppLogger.shared.logError(error, context: "Failed to get prompt \(name)")
            return nil
        }
    }

    /// Start all configured MCP servers automatically
    func startAllServers() async {
        AppLogger.shared.log("Auto-starting all MCP servers (\(availableServers.count) configured)", level: .info)
        for server in availableServers {
            if !enabledServers.contains(server.id) {
                do {
                    try await startServer(server)
                    AppLogger.shared.log("Auto-started MCP server: \(server.name)", level: .info)
                } catch {
                    AppLogger.shared.logError(error, context: "Failed to auto-start MCP server \(server.name)")
                }
            }
        }
    }
}

/// Source from which an MCP server was discovered/imported
enum DiscoverySource: String, Codable, CaseIterable {
    case manual = "manual"
    case claudeDesktop = "claude_desktop"
    case cursor = "cursor"
    case claudeCode = "claude_code"
    case vscode = "vscode"
    case dotfile = "dotfile"

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .claudeDesktop: return "Claude Desktop"
        case .cursor: return "Cursor"
        case .claudeCode: return "Claude Code"
        case .vscode: return "VS Code"
        case .dotfile: return "Project Config"
        }
    }

    var icon: String {
        switch self {
        case .manual: return "plus.circle"
        case .claudeDesktop: return "sparkle"
        case .cursor: return "cursorarrow"
        case .claudeCode: return "terminal"
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        case .dotfile: return "doc.badge.gearshape"
        }
    }
}

struct MCPServer: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let command: String
    let args: [String]
    let path: URL?
    let env: [String: String]?           // Environment variables for the server process
    let workingDirectory: String?         // Working directory (cwd) for the server process
    let sourceConfig: DiscoverySource?    // Where this server was imported from

    enum CodingKeys: String, CodingKey {
        case id, name, description, command, args, path, env, workingDirectory, sourceConfig
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        command: String,
        args: [String] = [],
        path: URL? = nil,
        env: [String: String]? = nil,
        workingDirectory: String? = nil,
        sourceConfig: DiscoverySource? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.command = command
        self.args = args
        self.path = path
        self.env = env
        self.workingDirectory = workingDirectory
        self.sourceConfig = sourceConfig
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        command = try container.decode(String.self, forKey: .command)
        args = try container.decode([String].self, forKey: .args)
        path = try container.decodeIfPresent(URL.self, forKey: .path)
        env = try container.decodeIfPresent([String: String].self, forKey: .env)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        sourceConfig = try container.decodeIfPresent(DiscoverySource.self, forKey: .sourceConfig)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(command, forKey: .command)
        try container.encode(args, forKey: .args)
        try container.encodeIfPresent(path, forKey: .path)
        try container.encodeIfPresent(env, forKey: .env)
        try container.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
        try container.encodeIfPresent(sourceConfig, forKey: .sourceConfig)
    }
}

// MCP Tool definition
struct MCPTool: Codable, Identifiable, @unchecked Sendable {
    let name: String
    let description: String
    let inputSchema: AnyCodable
    var serverId: String?
    var serverName: String?

    var id: String { "\(serverId ?? ""):\(name)" }

    enum CodingKeys: String, CodingKey {
        case name, description, inputSchema
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        inputSchema = try container.decode(AnyCodable.self, forKey: .inputSchema)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(inputSchema, forKey: .inputSchema)
    }

    init(name: String, description: String, inputSchema: AnyCodable, serverId: String? = nil, serverName: String? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.serverId = serverId
        self.serverName = serverName
    }
}

// Result from MCP tool execution
struct MCPToolResult {
    let content: [MCPContent]
    let isError: Bool

    init(content: [MCPContent], isError: Bool = false) {
        self.content = content
        self.isError = isError
    }
}

// MARK: - MCP Resource

/// Represents an MCP resource - read-only data exposed by servers
struct MCPResource: Codable, Identifiable, @unchecked Sendable {
    let uri: String
    let name: String
    let description: String?
    let mimeType: String?
    var serverId: String?
    var serverName: String?

    var id: String { "\(serverId ?? ""):\(uri)" }

    enum CodingKeys: String, CodingKey {
        case uri, name, description, mimeType
    }

    init(uri: String, name: String, description: String? = nil, mimeType: String? = nil, serverId: String? = nil, serverName: String? = nil) {
        self.uri = uri
        self.name = name
        self.description = description
        self.mimeType = mimeType
        self.serverId = serverId
        self.serverName = serverName
    }
}

/// Result of reading an MCP resource
struct MCPResourceContent: @unchecked Sendable {
    let uri: String
    let mimeType: String?
    let text: String?
    let blob: Data?

    var isText: Bool { text != nil }
}

// MARK: - MCP Prompt

/// Represents an MCP prompt template - reusable instructions for the LLM
struct MCPPrompt: Codable, Identifiable, @unchecked Sendable {
    let name: String
    let description: String?
    let arguments: [MCPPromptArgument]?
    var serverId: String?
    var serverName: String?

    var id: String { "\(serverId ?? ""):\(name)" }

    enum CodingKeys: String, CodingKey {
        case name, description, arguments
    }

    init(name: String, description: String? = nil, arguments: [MCPPromptArgument]? = nil, serverId: String? = nil, serverName: String? = nil) {
        self.name = name
        self.description = description
        self.arguments = arguments
        self.serverId = serverId
        self.serverName = serverName
    }
}

/// Argument definition for an MCP prompt
struct MCPPromptArgument: Codable, @unchecked Sendable {
    let name: String
    let description: String?
    let required: Bool?
}

/// Result of getting an MCP prompt - contains the rendered messages
struct MCPPromptResult: @unchecked Sendable {
    let description: String?
    let messages: [MCPPromptMessage]
}

/// A message in an MCP prompt result
struct MCPPromptMessage: @unchecked Sendable {
    let role: String  // "user" or "assistant"
    let content: String
}

// MCP content can be text or other types
struct MCPContent: Codable, @unchecked Sendable {
    let type: String
    let text: String?

    init(type: String = "text", text: String) {
        self.type = type
        self.text = text
    }
}

struct ParsedToolCall: @unchecked Sendable {
    let id: String
    let name: String
    let arguments: [String: Any]
}

// Helper for encoding/decoding Any values
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let arrayValue = value as? [Any] {
            try container.encode(arrayValue.map { AnyCodable($0) })
        } else if let dictValue = value as? [String: Any] {
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }
}

private func wrapAnyCodable(_ dict: [String: Any]) -> [String: AnyCodable] {
    dict.mapValues { AnyCodable($0) }
}

private func unwrapAnyCodable(_ dict: [String: AnyCodable]) -> [String: Any] {
    dict.mapValues { $0.value }
}

private actor StreamAccumulator {
    private var value = ""

    func append(_ chunk: String) {
        value += chunk
    }

    func current() -> String {
        value
    }
}

/// Actor to safely manage pending JSON-RPC requests, eliminating race conditions
private actor PendingRequestsManager {
    private var pendingRequests: [Int: CheckedContinuation<[String: AnyCodable], Error>] = [:]
    private var nextMessageId = 0

    /// Generate a new message ID and store the continuation atomically
    func addRequest(_ continuation: CheckedContinuation<[String: AnyCodable], Error>) -> Int {
        nextMessageId += 1
        let id = nextMessageId
        pendingRequests[id] = continuation
        return id
    }

    /// Remove and return a pending request by ID
    func removeRequest(forKey id: Int) -> CheckedContinuation<[String: AnyCodable], Error>? {
        return pendingRequests.removeValue(forKey: id)
    }

    /// Remove all pending requests and return them (for cleanup on disconnect)
    func removeAllRequests() -> [Int: CheckedContinuation<[String: AnyCodable], Error>] {
        let pending = pendingRequests
        pendingRequests.removeAll()
        return pending
    }

    /// Check if a request exists
    func hasRequest(forKey id: Int) -> Bool {
        return pendingRequests[id] != nil
    }
}

/// Actor to safely manage resource subscriptions, eliminating race conditions with NSLock
private actor ResourceSubscriptionsManager {
    private var subscriptions: Set<String> = []

    /// Add a subscription
    func insert(_ uri: String) {
        subscriptions.insert(uri)
    }

    /// Remove a subscription
    func remove(_ uri: String) {
        subscriptions.remove(uri)
    }

    /// Check if subscribed to a URI
    func contains(_ uri: String) -> Bool {
        return subscriptions.contains(uri)
    }

    /// Get all subscriptions
    func getAll() -> Set<String> {
        return subscriptions
    }
}

// MARK: - MCP Notification Types

/// Progress information from MCP server
struct MCPProgress: @unchecked Sendable {
    let progressToken: String
    let progress: Double
    let total: Double?
    let message: String?
}

/// Log message from MCP server
struct MCPLogMessage: @unchecked Sendable {
    let level: String  // "debug", "info", "warning", "error"
    let logger: String?
    let data: Any?
}

/// Sampling request from agentic MCP servers
struct MCPSamplingRequest: @unchecked Sendable {
    let id: Int
    let messages: [[String: Any]]
    let modelPreferences: [String: Any]?
    let systemPrompt: String?
    let includeContext: String?
    let maxTokens: Int?
}

/// Notification callbacks for MCP server events
struct MCPNotificationCallbacks: @unchecked Sendable {
    let onToolsListChanged: (() async -> Void)?
    let onResourcesListChanged: (() async -> Void)?
    let onResourceUpdated: ((String) async -> Void)?  // URI of updated resource
    let onPromptsListChanged: (() async -> Void)?
    let onProgress: ((MCPProgress) async -> Void)?
    let onLogMessage: ((MCPLogMessage) async -> Void)?
    let onSamplingRequest: ((MCPSamplingRequest) async -> [String: Any]?)?
    let onRootsListRequest: (() async -> [[String: Any]])?

    init(
        onToolsListChanged: (() async -> Void)? = nil,
        onResourcesListChanged: (() async -> Void)? = nil,
        onResourceUpdated: ((String) async -> Void)? = nil,
        onPromptsListChanged: (() async -> Void)? = nil,
        onProgress: ((MCPProgress) async -> Void)? = nil,
        onLogMessage: ((MCPLogMessage) async -> Void)? = nil,
        onSamplingRequest: ((MCPSamplingRequest) async -> [String: Any]?)? = nil,
        onRootsListRequest: (() async -> [[String: Any]])? = nil
    ) {
        self.onToolsListChanged = onToolsListChanged
        self.onResourcesListChanged = onResourcesListChanged
        self.onResourceUpdated = onResourceUpdated
        self.onPromptsListChanged = onPromptsListChanged
        self.onProgress = onProgress
        self.onLogMessage = onLogMessage
        self.onSamplingRequest = onSamplingRequest
        self.onRootsListRequest = onRootsListRequest
    }
}

// MCP Server Connection - Handles JSON-RPC communication via stdio
@preconcurrency
class MCPServerConnection {
    private let process: Process
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let pendingRequestsManager = PendingRequestsManager()
    private let onDisconnect: ((String) -> Void)?
    private let serverId: String

    // Notification callbacks for handling server events
    private var notificationCallbacks: MCPNotificationCallbacks?

    // Resource subscriptions tracking (actor-based for thread safety)
    private let subscriptionsManager = ResourceSubscriptionsManager()

    // Server capabilities (populated after initialize)
    private var serverCapabilities: [String: Any] = [:]
    private var serverSupportsRoots: Bool = false
    private var serverSupportsSampling: Bool = false

    init(command: String, arguments: [String], workingDirectory: URL?, env: [String: String]? = nil, onDisconnect: ((String) -> Void)? = nil, serverId: String = "", notificationCallbacks: MCPNotificationCallbacks? = nil) throws {
        self.onDisconnect = onDisconnect
        self.serverId = serverId
        self.notificationCallbacks = notificationCallbacks
        Task { @MainActor in
            AppLogger.shared.log("Creating MCPServerConnection with command: \(command), args: \(arguments)", level: .debug)
        }
        process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
            Task { @MainActor in
                AppLogger.shared.log("Set working directory: \(workingDirectory.path)", level: .debug)
            }
        }

        // Set environment variables - merge with current process environment
        if let env = env, !env.isEmpty {
            var environment = Foundation.ProcessInfo.processInfo.environment
            for (key, value) in env {
                environment[key] = value
            }
            process.environment = environment
            Task { @MainActor in
                AppLogger.shared.log("Set \(env.count) custom environment variable(s)", level: .debug)
            }
        }

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        Task { @MainActor in
            AppLogger.shared.log("MCPServerConnection initialized", level: .debug)
        }
    }

    func start() throws {
        Task { @MainActor in
            AppLogger.shared.log("Starting MCP server process", level: .debug)
        }
        do {
            try process.run()
            let pid = process.processIdentifier
            Task { @MainActor in
                AppLogger.shared.log("MCP server process started (PID: \(pid))", level: .info)
            }

            // Start reading responses in background
            Task { [weak self] in
                await self?.readResponses()
            }

            // Start reading stderr in background for error logging
            Task { [weak self] in
                await self?.readStderr()
            }
        } catch {
            Task { @MainActor in
                AppLogger.shared.logError(error, context: "Failed to start MCP server process")
            }
            throw error
        }
    }

    /// Stop the MCP server process with proper cleanup
    /// Waits for the process to exit (with timeout) and closes all pipes to prevent resource leaks
    /// - Note: This function is async to ensure cleanup completes before returning
    func stop() async {
        let pid = process.processIdentifier
        await MainActor.run {
            AppLogger.shared.log("Stopping MCP server process (PID: \(pid))", level: .info)
        }

        // Close stdin first to signal the process to exit gracefully
        try? stdinPipe.fileHandleForWriting.close()

        // Terminate the process
        process.terminate()

        // Wait for process exit with timeout to ensure clean shutdown
        let timeoutNanoseconds: UInt64 = 5_000_000_000 // 5 seconds
        let startTime = DispatchTime.now()

        while process.isRunning {
            let elapsed = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            if elapsed > timeoutNanoseconds {
                await MainActor.run {
                    AppLogger.shared.log("MCP server process (PID: \(pid)) did not exit within timeout, forcing termination", level: .warning)
                }
                // Force kill if still running after timeout
                if process.isRunning {
                    kill(pid, SIGKILL)
                    // Brief wait for SIGKILL to take effect
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                break
            }

            try? await Task.sleep(nanoseconds: 100_000_000) // Check every 100ms
        }

        // Wait for process to fully exit after termination/kill
        process.waitUntilExit()

        // Close remaining pipes to release file descriptors
        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()

        // Cancel any pending requests
        let pending = await pendingRequestsManager.removeAllRequests()
        if !pending.isEmpty {
            let error = NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server stopped"])
            for (_, continuation) in pending {
                continuation.resume(throwing: error)
            }
        }

        await MainActor.run {
            AppLogger.shared.log("MCP server process (PID: \(pid)) stopped and resources cleaned up", level: .info)
        }
    }
    
    private func readStderr() async {
        let handle = stderrPipe.fileHandleForReading
        while process.isRunning {
            guard let data = try? handle.read(upToCount: 1024), !data.isEmpty else {
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }
            if let stderrText = String(data: data, encoding: .utf8),
               !stderrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task { @MainActor in
                    AppLogger.shared.log("MCP server stderr received", level: .warning)
                }
            }
        }
    }

    func initialize() async throws {
        await AppLogger.shared.log("Sending initialize request to MCP server", level: .debug)
        let params = wrapAnyCodable([
            "protocolVersion": "2024-11-05",
            "capabilities": [
                "tools": [:],           // Support for tool calls
                "resources": [          // Support for reading resources
                    "subscribe": true,  // Support resource subscriptions
                    "listChanged": true // Support notifications when resource list changes
                ],
                "prompts": [            // Support for prompt templates
                    "listChanged": true // Support notifications when prompt list changes
                ],
                "logging": [:],         // Support for receiving log messages
                "sampling": [:],        // CRITICAL: Support for sampling requests from agentic servers
                "roots": [              // Support for roots (workspace paths)
                    "listChanged": true // Support notifications when roots change
                ]
            ],
            "clientInfo": [
                "name": "Vaizor",
                "version": "1.0.0"
            ]
        ])

        do {
            let response = try await sendRequest(method: "initialize", params: params)
            let responseDescription = String(describing: response)
            await AppLogger.shared.log("Received initialize response: \(responseDescription)", level: .debug)

            // Parse and store server capabilities
            if let serverCaps = response["capabilities"]?.value as? [String: Any] {
                serverCapabilities = serverCaps
                let hasTools = serverCaps["tools"] != nil
                let hasResources = serverCaps["resources"] != nil
                let hasPrompts = serverCaps["prompts"] != nil
                serverSupportsSampling = serverCaps["sampling"] != nil
                serverSupportsRoots = serverCaps["roots"] != nil
                await AppLogger.shared.log("Server capabilities - tools: \(hasTools), resources: \(hasResources), prompts: \(hasPrompts), sampling: \(serverSupportsSampling), roots: \(serverSupportsRoots)", level: .info)
            }

            // Send initialized notification (no response expected)
            try sendNotification(method: "initialized", params: [:])
            await AppLogger.shared.log("Sent initialized notification", level: .debug)
        } catch {
            await AppLogger.shared.logError(error, context: "Failed to initialize MCP server")
            throw error
        }
    }

    func listTools() async throws -> [MCPTool] {
        await AppLogger.shared.log("Requesting tools list from MCP server", level: .debug)
        do {
            let response = try await sendRequest(method: "tools/list", params: [:])
            await AppLogger.shared.log("Received tools list response", level: .debug)

            guard let tools = response["tools"]?.value as? [[String: Any]] else {
                await AppLogger.shared.log("No tools found in response or invalid format", level: .warning)
                return []
            }

            await AppLogger.shared.log("Found \(tools.count) tools in response", level: .info)
            
            let decodedTools = tools.compactMap { toolDict -> MCPTool? in
                guard let name = toolDict["name"] as? String,
                      let description = toolDict["description"] as? String else {
                    let toolDescription = String(describing: toolDict)
                    Task { @MainActor in
                        AppLogger.shared.log("Tool missing name or description: \(toolDescription)", level: .warning)
                    }
                    return nil
                }

                let inputSchema = toolDict["inputSchema"] ?? [:]
                let toolData: [String: Any] = [
                    "name": name,
                    "description": description,
                    "inputSchema": inputSchema
                ]

                guard let jsonData = try? JSONSerialization.data(withJSONObject: toolData),
                      let tool = try? JSONDecoder().decode(MCPTool.self, from: jsonData) else {
                    Task { @MainActor in
                        AppLogger.shared.log("Failed to decode tool: \(name)", level: .warning)
                    }
                    return nil
                }

                Task { @MainActor in
                    AppLogger.shared.log("Decoded tool: \(name)", level: .debug)
                }
                return tool
            }
            
            await AppLogger.shared.log("Successfully decoded \(decodedTools.count) tools", level: .info)
            return decodedTools
        } catch {
            await AppLogger.shared.logError(error, context: "Failed to list tools from MCP server")
            throw error
        }
    }

    // MARK: - Resources

    /// List available resources from the MCP server
    func listResources() async throws -> [MCPResource] {
        await AppLogger.shared.log("Requesting resources list from MCP server", level: .debug)
        do {
            let response = try await sendRequest(method: "resources/list", params: [:])
            await AppLogger.shared.log("Received resources list response", level: .debug)

            guard let resources = response["resources"]?.value as? [[String: Any]] else {
                await AppLogger.shared.log("No resources found in response or invalid format", level: .debug)
                return []
            }

            await AppLogger.shared.log("Found \(resources.count) resources in response", level: .info)

            let decodedResources = resources.compactMap { resourceDict -> MCPResource? in
                guard let uri = resourceDict["uri"] as? String,
                      let name = resourceDict["name"] as? String else {
                    return nil
                }

                return MCPResource(
                    uri: uri,
                    name: name,
                    description: resourceDict["description"] as? String,
                    mimeType: resourceDict["mimeType"] as? String
                )
            }

            await AppLogger.shared.log("Successfully decoded \(decodedResources.count) resources", level: .info)
            return decodedResources
        } catch {
            // Resources may not be supported by all servers - don't treat as fatal error
            await AppLogger.shared.log("Failed to list resources (server may not support resources): \(error.localizedDescription)", level: .debug)
            return []
        }
    }

    /// Read content of a specific resource
    func readResource(uri: String) async throws -> MCPResourceContent {
        await AppLogger.shared.log("Reading resource: \(uri)", level: .debug)
        let params: [String: Any] = ["uri": uri]

        let response = try await sendRequest(method: "resources/read", params: wrapAnyCodable(params))

        guard let contents = response["contents"]?.value as? [[String: Any]],
              let firstContent = contents.first else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid resource response format"])
        }

        let contentUri = firstContent["uri"] as? String ?? uri
        let mimeType = firstContent["mimeType"] as? String
        let text = firstContent["text"] as? String
        var blob: Data? = nil

        if let blobString = firstContent["blob"] as? String {
            blob = Data(base64Encoded: blobString)
        }

        await AppLogger.shared.log("Read resource \(uri) (mimeType: \(mimeType ?? "unknown"), hasText: \(text != nil), hasBlob: \(blob != nil))", level: .info)

        return MCPResourceContent(uri: contentUri, mimeType: mimeType, text: text, blob: blob)
    }

    // MARK: - Prompts

    /// List available prompts from the MCP server
    func listPrompts() async throws -> [MCPPrompt] {
        await AppLogger.shared.log("Requesting prompts list from MCP server", level: .debug)
        do {
            let response = try await sendRequest(method: "prompts/list", params: [:])
            await AppLogger.shared.log("Received prompts list response", level: .debug)

            guard let prompts = response["prompts"]?.value as? [[String: Any]] else {
                await AppLogger.shared.log("No prompts found in response or invalid format", level: .debug)
                return []
            }

            await AppLogger.shared.log("Found \(prompts.count) prompts in response", level: .info)

            let decodedPrompts = prompts.compactMap { promptDict -> MCPPrompt? in
                guard let name = promptDict["name"] as? String else {
                    return nil
                }

                var arguments: [MCPPromptArgument]? = nil
                if let argsArray = promptDict["arguments"] as? [[String: Any]] {
                    arguments = argsArray.compactMap { argDict -> MCPPromptArgument? in
                        guard let argName = argDict["name"] as? String else { return nil }
                        return MCPPromptArgument(
                            name: argName,
                            description: argDict["description"] as? String,
                            required: argDict["required"] as? Bool
                        )
                    }
                }

                return MCPPrompt(
                    name: name,
                    description: promptDict["description"] as? String,
                    arguments: arguments
                )
            }

            await AppLogger.shared.log("Successfully decoded \(decodedPrompts.count) prompts", level: .info)
            return decodedPrompts
        } catch {
            // Prompts may not be supported by all servers - don't treat as fatal error
            await AppLogger.shared.log("Failed to list prompts (server may not support prompts): \(error.localizedDescription)", level: .debug)
            return []
        }
    }

    /// Get a specific prompt with optional arguments
    func getPrompt(name: String, arguments: [String: String] = [:]) async throws -> MCPPromptResult {
        await AppLogger.shared.log("Getting prompt: \(name) with \(arguments.count) arguments", level: .debug)
        var params: [String: Any] = ["name": name]
        if !arguments.isEmpty {
            params["arguments"] = arguments
        }

        let response = try await sendRequest(method: "prompts/get", params: wrapAnyCodable(params))

        guard let messagesArray = response["messages"]?.value as? [[String: Any]] else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid prompt response format"])
        }

        let messages = messagesArray.compactMap { msgDict -> MCPPromptMessage? in
            guard let role = msgDict["role"] as? String else { return nil }

            // Content can be a string or an object with text
            var content = ""
            if let contentString = msgDict["content"] as? String {
                content = contentString
            } else if let contentObj = msgDict["content"] as? [String: Any],
                      let text = contentObj["text"] as? String {
                content = text
            }

            return MCPPromptMessage(role: role, content: content)
        }

        let description = response["description"]?.value as? String

        await AppLogger.shared.log("Got prompt \(name) with \(messages.count) messages", level: .info)

        return MCPPromptResult(description: description, messages: messages)
    }

    func callTool(name: String, arguments: [String: AnyCodable]) async throws -> MCPToolResult {
        await AppLogger.shared.log("Calling MCP tool: \(name) (arg keys: \(arguments.count))", level: .info)
        let params: [String: Any] = [
            "name": name,
            "arguments": unwrapAnyCodable(arguments)
        ]

        do {
            let response = try await sendRequest(method: "tools/call", params: wrapAnyCodable(params), timeout: 60)
            await AppLogger.shared.log("Received tool call response for \(name)", level: .debug)

            guard let content = response["content"]?.value as? [[String: Any]] else {
                let error = NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid tool response format"])
                await AppLogger.shared.logError(error, context: "Tool \(name) returned invalid response format")
                throw error
            }

            let mcpContent = content.compactMap { dict -> MCPContent? in
                guard let type = dict["type"] as? String else {
                    let dictDescription = String(describing: dict)
                    Task { @MainActor in
                        AppLogger.shared.log("Content item missing type: \(dictDescription)", level: .warning)
                    }
                    return nil
                }
                let text = dict["text"] as? String
                return MCPContent(type: type, text: text ?? "")
            }

            let isError = response["isError"]?.value as? Bool ?? false
            await AppLogger.shared.log("Tool \(name) execution completed (error: \(isError), content items: \(mcpContent.count))", level: .info)
            return MCPToolResult(content: mcpContent, isError: isError)
        } catch {
            await AppLogger.shared.logError(error, context: "Failed to call MCP tool \(name)")
            // Return error result instead of throwing, so LLM can handle it
            let errorMessage = error.localizedDescription
            await AppLogger.shared.log("Returning error result for tool \(name)", level: .warning)
            return MCPToolResult(
                content: [MCPContent(type: "text", text: "Error executing tool '\(name)': \(errorMessage)")],
                isError: true
            )
        }
    }
    
    private func sendRequest(method: String, params: [String: AnyCodable], timeout: TimeInterval = 15) async throws -> [String: AnyCodable] {
        // Prepare the request data before entering the continuation
        let paramsUnwrapped = unwrapAnyCodable(params)

        return try await withCheckedThrowingContinuation { continuation in
            // Use a Task to interact with the actor
            Task { [weak self] in
                guard let self else {
                    continuation.resume(throwing: NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server deallocated"]))
                    return
                }

                // Atomically add request and get ID through the actor
                let id = await self.pendingRequestsManager.addRequest(continuation)

                let request: [String: Any] = [
                    "jsonrpc": "2.0",
                    "id": id,
                    "method": method,
                    "params": paramsUnwrapped
                ]

                Task { @MainActor in
                    AppLogger.shared.log("Sending JSON-RPC request: method=\(method), id=\(id)", level: .debug)
                }

                // Set up timeout if specified
                if timeout > 0 {
                    Task { [weak self] in
                        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        guard let self else { return }
                        // Atomically remove and resume with timeout error if still pending
                        if let pending = await self.pendingRequestsManager.removeRequest(forKey: id) {
                            let error = NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])
                            pending.resume(throwing: error)
                        }
                    }
                }

                // Serialize and send the request
                do {
                    let data = try JSONSerialization.data(withJSONObject: request)
                    guard let jsonString = String(data: data, encoding: .utf8) else {
                        let error = NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request as UTF-8"])
                        Task { @MainActor in
                            AppLogger.shared.logError(error, context: "Failed to encode JSON-RPC request")
                        }
                        if let pending = await self.pendingRequestsManager.removeRequest(forKey: id) {
                            pending.resume(throwing: error)
                        }
                        return
                    }

                    let requestString = jsonString + "\n"

                    guard let requestData = requestString.data(using: .utf8) else {
                        let error = NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request string"])
                        Task { @MainActor in
                            AppLogger.shared.logError(error, context: "Failed to encode request string")
                        }
                        if let pending = await self.pendingRequestsManager.removeRequest(forKey: id) {
                            pending.resume(throwing: error)
                        }
                        return
                    }

                    do {
                        try self.stdinPipe.fileHandleForWriting.write(contentsOf: requestData)
                        Task { @MainActor in
                            AppLogger.shared.log("Request written successfully", level: .debug)
                        }
                    } catch {
                        Task { @MainActor in
                            AppLogger.shared.logError(error, context: "Failed to write request to stdin")
                        }
                        if let pending = await self.pendingRequestsManager.removeRequest(forKey: id) {
                            pending.resume(throwing: error)
                        }
                    }
                } catch {
                    Task { @MainActor in
                        AppLogger.shared.logError(error, context: "Failed to serialize JSON-RPC request")
                    }
                    if let pending = await self.pendingRequestsManager.removeRequest(forKey: id) {
                        pending.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func sendNotification(method: String, params: [String: AnyCodable]) throws {
        let notification: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "params": unwrapAnyCodable(params)
        ]

        let data = try JSONSerialization.data(withJSONObject: notification)
        guard var jsonString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON string to UTF-8"])
        }
        jsonString += "\n"

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JSON data"])
        }
        stdinPipe.fileHandleForWriting.write(jsonData)
    }

    /// Cancel a pending request by ID
    /// Sends notifications/cancelled to the server and cancels the local continuation
    func cancelRequest(_ requestId: Int) async {
        // Cancel the pending request locally
        if let continuation = await pendingRequestsManager.removeRequest(forKey: requestId) {
            let error = NSError(domain: "MCPServer", code: -32800, userInfo: [NSLocalizedDescriptionKey: "Request cancelled by client"])
            continuation.resume(throwing: error)

            // Notify the server about the cancellation
            do {
                try sendNotification(
                    method: "notifications/cancelled",
                    params: wrapAnyCodable(["requestId": requestId, "reason": "Cancelled by user"])
                )
                Task { @MainActor in
                    AppLogger.shared.log("Cancelled request \(requestId)", level: .debug)
                }
            } catch {
                Task { @MainActor in
                    AppLogger.shared.logError(error, context: "Failed to send cancellation notification")
                }
            }
        }
    }

    /// Cancel all pending requests
    func cancelAllRequests() async {
        let pending = await pendingRequestsManager.removeAllRequests()
        let error = NSError(domain: "MCPServer", code: -32800, userInfo: [NSLocalizedDescriptionKey: "All requests cancelled"])

        for (requestId, continuation) in pending {
            continuation.resume(throwing: error)
            // Notify the server about each cancellation
            do {
                try sendNotification(
                    method: "notifications/cancelled",
                    params: wrapAnyCodable(["requestId": requestId, "reason": "Cancelled by user"])
                )
            } catch {
                // Log but don't throw - best effort
                Task { @MainActor in
                    AppLogger.shared.logError(error, context: "Failed to send cancellation notification for request \(requestId)")
                }
            }
        }

        if !pending.isEmpty {
            Task { @MainActor in
                AppLogger.shared.log("Cancelled \(pending.count) pending request(s)", level: .info)
            }
        }
    }

    private nonisolated func readResponses() async {
        Task { @MainActor in
            AppLogger.shared.log("Starting to read MCP server responses", level: .debug)
        }
        let handle = stdoutPipe.fileHandleForReading

        while process.isRunning {
            guard let line = try? handle.readLine() else {
                // Check if process is still running before sleeping
                guard process.isRunning else { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }

            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            guard let data = line.data(using: .utf8) else {
                Task { @MainActor in
                    AppLogger.shared.log("Failed to convert line to UTF-8 data", level: .warning)
                }
                continue
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Task { @MainActor in
                    AppLogger.shared.log("Failed to parse JSON from server response", level: .warning)
                }
                continue
            }

            // Check if this is a notification (no ID or null ID) or a request from server (has ID and method)
            // JSON-RPC notifications have no "id" field, but some servers may send "id": null
            let idValue = json["id"]
            let isNotification = idValue == nil || idValue is NSNull

            if isNotification {
                // This is a notification from server - route it appropriately
                if let method = json["method"] as? String {
                    await handleNotification(method: method, params: json["params"] as? [String: Any])
                } else {
                    Task { @MainActor in
                        AppLogger.shared.log("Received notification without method - ignoring", level: .debug)
                    }
                }
                continue
            }

            // Check if this is a request from server (has both ID and method)
            if let method = json["method"] as? String, let id = json["id"] as? Int {
                // This is a request from the server (e.g., sampling/createMessage, roots/list)
                await handleServerRequest(id: id, method: method, params: json["params"] as? [String: Any])
                continue
            }

            // This is a response to one of our requests
            guard let id = json["id"] as? Int else {
                Task { @MainActor in
                    AppLogger.shared.log("Response missing valid ID - ignoring", level: .warning)
                }
                continue
            }

            Task { @MainActor in
                AppLogger.shared.log("Processing response with ID: \(id)", level: .debug)
            }

            // Use actor to atomically remove the pending request
            let continuation = await pendingRequestsManager.removeRequest(forKey: id)

            guard let continuation = continuation else {
                Task { @MainActor in
                    AppLogger.shared.log("No pending request found for ID: \(id)", level: .warning)
                }
                continue
            }

            if let error = json["error"] as? [String: Any] {
                let message = error["message"] as? String ?? "Unknown error"
                let code = error["code"] as? Int ?? -1
                Task { @MainActor in
                    AppLogger.shared.log("MCP server returned error for request \(id): \(message) (code: \(code))", level: .error)
                }
                let nsError = NSError(domain: "MCPServer", code: code, userInfo: [NSLocalizedDescriptionKey: message])
                continuation.resume(throwing: nsError)
            } else if let result = json["result"] as? [String: Any] {
                Task { @MainActor in
                    AppLogger.shared.log("MCP server returned success for request \(id)", level: .debug)
                }
                continuation.resume(returning: wrapAnyCodable(result))
            } else {
                Task { @MainActor in
                    AppLogger.shared.log("MCP server returned empty result for request \(id)", level: .debug)
                }
                continuation.resume(returning: [:])
            }
        }

        Task { @MainActor in
            AppLogger.shared.log("MCP server response reader stopped (process no longer running)", level: .info)
        }

        // Clean up any remaining pending requests using actor
        let pending = await pendingRequestsManager.removeAllRequests()
        if !pending.isEmpty {
            let error = NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server disconnected"])
            for (_, continuation) in pending {
                continuation.resume(throwing: error)
            }
        }
        
        // Notify about disconnection if callback provided
        if !serverId.isEmpty {
            onDisconnect?(serverId)
        }
    }

    // MARK: - Notification Router

    /// Handle incoming notifications from the MCP server
    private func handleNotification(method: String, params: [String: Any]?) async {
        Task { @MainActor in
            AppLogger.shared.log("Received MCP notification: \(method)", level: .debug)
        }

        switch method {
        case "notifications/tools/listChanged":
            // Server's tool list has changed - refresh our tools
            Task { @MainActor in
                AppLogger.shared.log("Tools list changed notification received", level: .info)
            }
            await notificationCallbacks?.onToolsListChanged?()

        case "notifications/resources/listChanged":
            // Server's resource list has changed - refresh our resources
            Task { @MainActor in
                AppLogger.shared.log("Resources list changed notification received", level: .info)
            }
            await notificationCallbacks?.onResourcesListChanged?()

        case "notifications/resources/updated":
            // A specific resource was updated
            if let uri = params?["uri"] as? String {
                Task { @MainActor in
                    AppLogger.shared.log("Resource updated notification: \(uri)", level: .info)
                }
                // Only notify if we're subscribed to this resource
                let isSubscribed = await subscriptionsManager.contains(uri)
                if isSubscribed {
                    await notificationCallbacks?.onResourceUpdated?(uri)
                }
            }

        case "notifications/prompts/listChanged":
            // Server's prompt list has changed - refresh our prompts
            Task { @MainActor in
                AppLogger.shared.log("Prompts list changed notification received", level: .info)
            }
            await notificationCallbacks?.onPromptsListChanged?()

        case "notifications/progress":
            // Progress update from a long-running operation
            if let progressToken = params?["progressToken"] as? String,
               let progress = params?["progress"] as? Double {
                let total = params?["total"] as? Double
                let message = params?["message"] as? String
                let progressInfo = MCPProgress(
                    progressToken: progressToken,
                    progress: progress,
                    total: total,
                    message: message
                )
                Task { @MainActor in
                    let progressDesc = total.map { "\(progress)/\($0)" } ?? "\(progress)"
                    AppLogger.shared.log("Progress notification: \(progressToken) - \(progressDesc)", level: .debug)
                }
                await notificationCallbacks?.onProgress?(progressInfo)
            }

        case "notifications/message":
            // Log message from server
            if let level = params?["level"] as? String {
                let logger = params?["logger"] as? String
                let data = params?["data"]
                let logMessage = MCPLogMessage(level: level, logger: logger, data: data)
                Task { @MainActor in
                    AppLogger.shared.log("MCP server log [\(level)]: \(logger ?? "unknown")", level: .debug)
                }
                await notificationCallbacks?.onLogMessage?(logMessage)
            }

        case "notifications/cancelled":
            // Request was cancelled by server
            if let requestId = params?["requestId"] as? Int {
                Task { @MainActor in
                    AppLogger.shared.log("Request \(requestId) cancelled by server", level: .warning)
                }
                // Cancel the pending request if it exists
                if let continuation = await pendingRequestsManager.removeRequest(forKey: requestId) {
                    let error = NSError(domain: "MCPServer", code: -32800, userInfo: [NSLocalizedDescriptionKey: "Request cancelled by server"])
                    continuation.resume(throwing: error)
                }
            }

        default:
            Task { @MainActor in
                AppLogger.shared.log("Unknown notification method: \(method)", level: .debug)
            }
        }
    }

    // MARK: - MCP Apps Protocol Handlers

    /// Handle mcp_apps/render request from servers wanting to display UI
    private func handleAppsRenderRequest(id: Int, params: [String: Any]?) async {
        guard let params = params,
              let html = params["html"] as? String else {
            sendErrorResponse(id: id, code: -32602, message: "Invalid params: html required")
            return
        }

        Task { @MainActor in
            AppLogger.shared.log("Processing mcp_apps/render request", level: .info)
        }

        let scripts = params["scripts"] as? [String]
        let styles = params["styles"] as? [String]
        let title = params["title"] as? String
        let displayModeString = params["displayMode"] as? String
        let displayMode = MCPAppDisplayMode(rawValue: displayModeString ?? "panel") ?? .panel
        let permissionsStrings = params["permissions"] as? [String]
        let permissions = permissionsStrings?.compactMap { MCPAppPermission(rawValue: $0) }

        // Create sandbox config from params if provided
        var sandboxConfig: MCPAppSandboxConfig? = nil
        if let sandboxParams = params["sandboxConfig"] as? [String: Any] {
            sandboxConfig = MCPAppSandboxConfig(
                allowScripts: sandboxParams["allowScripts"] as? Bool ?? true,
                allowModals: sandboxParams["allowModals"] as? Bool ?? false,
                allowForms: sandboxParams["allowForms"] as? Bool ?? true,
                allowPointerLock: sandboxParams["allowPointerLock"] as? Bool ?? false,
                allowPopups: sandboxParams["allowPopups"] as? Bool ?? false,
                allowTopNavigation: sandboxParams["allowTopNavigation"] as? Bool ?? false,
                allowDownloads: sandboxParams["allowDownloads"] as? Bool ?? false
            )
        }

        // Create MCP App content
        let appContent = MCPAppContent(
            serverId: serverId,
            serverName: "MCP Server",  // Would need to get actual server name
            html: html,
            scripts: scripts,
            styles: styles,
            title: title,
            metadata: MCPAppMetadata(
                version: params["version"] as? String,
                permissions: permissions,
                sandboxConfig: sandboxConfig,
                displayMode: displayMode
            )
        )

        // Register with MCP App Manager and setup action handler
        await MainActor.run {
            MCPAppManager.shared.registerApp(appContent) { [weak self] action in
                guard let self = self else {
                    return MCPAppResponse(requestId: action.requestId ?? "", success: false, data: nil, error: "Server disconnected")
                }
                return await self.handleAppAction(action, appId: appContent.id)
            }
        }

        // Send success response with app ID
        sendSuccessResponse(id: id, result: [
            "appId": appContent.id.uuidString,
            "success": true
        ])

        Task { @MainActor in
            AppLogger.shared.log("MCP App registered: \(appContent.id)", level: .info)
        }
    }

    /// Handle mcp_apps/update request
    private func handleAppsUpdateRequest(id: Int, params: [String: Any]?) async {
        guard let params = params,
              let appIdString = params["appId"] as? String,
              let appId = UUID(uuidString: appIdString),
              let html = params["html"] as? String else {
            sendErrorResponse(id: id, code: -32602, message: "Invalid params: appId and html required")
            return
        }

        Task { @MainActor in
            AppLogger.shared.log("Processing mcp_apps/update request for \(appIdString)", level: .debug)

            // Update the app content
            if var existingApp = MCPAppManager.shared.activeApps[appId] {
                // Create updated app content
                let updatedApp = MCPAppContent(
                    id: appId,
                    serverId: existingApp.serverId,
                    serverName: existingApp.serverName,
                    html: html,
                    scripts: params["scripts"] as? [String] ?? existingApp.scripts,
                    styles: params["styles"] as? [String] ?? existingApp.styles,
                    title: params["title"] as? String ?? existingApp.title,
                    metadata: existingApp.metadata,
                    createdAt: existingApp.createdAt
                )
                MCPAppManager.shared.activeApps[appId] = updatedApp
            }
        }

        sendSuccessResponse(id: id, result: ["success": true])
    }

    /// Handle mcp_apps/close request
    private func handleAppsCloseRequest(id: Int, params: [String: Any]?) async {
        guard let params = params,
              let appIdString = params["appId"] as? String,
              let appId = UUID(uuidString: appIdString) else {
            sendErrorResponse(id: id, code: -32602, message: "Invalid params: appId required")
            return
        }

        Task { @MainActor in
            AppLogger.shared.log("Processing mcp_apps/close request for \(appIdString)", level: .debug)
            MCPAppManager.shared.unregisterApp(appId)
        }

        sendSuccessResponse(id: id, result: ["success": true])
    }

    /// Handle action from MCP App UI - forward to server
    private func handleAppAction(_ action: MCPAppAction, appId: UUID) async -> MCPAppResponse {
        Task { @MainActor in
            AppLogger.shared.log("Forwarding app action to server: \(action.type.rawValue)", level: .debug)
        }

        do {
            // Send action to server via mcp_apps/action method
            let params: [String: Any] = [
                "appId": appId.uuidString,
                "type": action.type.rawValue,
                "payload": action.payload?.mapValues { $0.value } ?? [:],
                "requestId": action.requestId ?? UUID().uuidString
            ]

            let response = try await sendRequest(method: "mcp_apps/action", params: wrapAnyCodable(params), timeout: 30)

            // Parse response
            let success = response["success"]?.value as? Bool ?? false
            let data = response["data"]?.value as? [String: Any]
            let error = response["error"]?.value as? String

            return MCPAppResponse(
                requestId: action.requestId ?? "",
                success: success,
                data: data?.mapValues { AnyCodable($0) },
                error: error
            )
        } catch {
            Task { @MainActor in
                AppLogger.shared.logError(error, context: "Failed to forward app action")
            }
            return MCPAppResponse(
                requestId: action.requestId ?? "",
                success: false,
                data: nil,
                error: error.localizedDescription
            )
        }
    }

    // MARK: - Server Request Handler

    /// Handle incoming requests from the MCP server (e.g., sampling, roots)
    private func handleServerRequest(id: Int, method: String, params: [String: Any]?) async {
        Task { @MainActor in
            AppLogger.shared.log("Received MCP server request: \(method) (ID: \(id))", level: .debug)
        }

        switch method {
        case "sampling/createMessage":
            // Agentic server wants us to generate an LLM response
            await handleSamplingRequest(id: id, params: params)

        case "roots/list":
            // Server wants to know our workspace roots
            await handleRootsListRequest(id: id)

        // MCP Apps protocol methods
        case "mcp_apps/render":
            // Server wants to render interactive UI
            await handleAppsRenderRequest(id: id, params: params)

        case "mcp_apps/update":
            // Server wants to update existing app UI
            await handleAppsUpdateRequest(id: id, params: params)

        case "mcp_apps/close":
            // Server wants to close an app
            await handleAppsCloseRequest(id: id, params: params)

        default:
            // Unknown request method - send error response
            Task { @MainActor in
                AppLogger.shared.log("Unknown server request method: \(method)", level: .warning)
            }
            sendErrorResponse(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    /// Handle sampling/createMessage request from agentic MCP servers
    private func handleSamplingRequest(id: Int, params: [String: Any]?) async {
        guard let params = params,
              let messages = params["messages"] as? [[String: Any]] else {
            sendErrorResponse(id: id, code: -32602, message: "Invalid params: messages array required")
            return
        }

        let request = MCPSamplingRequest(
            id: id,
            messages: messages,
            modelPreferences: params["modelPreferences"] as? [String: Any],
            systemPrompt: params["systemPrompt"] as? String,
            includeContext: params["includeContext"] as? String,
            maxTokens: params["maxTokens"] as? Int
        )

        Task { @MainActor in
            AppLogger.shared.log("Processing sampling request with \(messages.count) messages", level: .info)
        }

        // Call the sampling callback to get an LLM response
        if let callback = notificationCallbacks?.onSamplingRequest {
            if let response = await callback(request) {
                // Send successful response
                sendSuccessResponse(id: id, result: response)
            } else {
                // Callback returned nil - send error
                sendErrorResponse(id: id, code: -32603, message: "Sampling request failed: no response generated")
            }
        } else {
            // No sampling callback configured
            sendErrorResponse(id: id, code: -32603, message: "Sampling not supported: no handler configured")
        }
    }

    /// Handle roots/list request from MCP servers
    private func handleRootsListRequest(id: Int) async {
        Task { @MainActor in
            AppLogger.shared.log("Processing roots/list request", level: .info)
        }

        // Call the roots callback to get workspace paths
        if let callback = notificationCallbacks?.onRootsListRequest {
            let roots = await callback()
            sendSuccessResponse(id: id, result: ["roots": roots])
        } else {
            // No roots callback - return empty list
            sendSuccessResponse(id: id, result: ["roots": []])
        }
    }

    /// Send a success response to the server
    private func sendSuccessResponse(id: Int, result: [String: Any]) {
        let response: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "result": result
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: response)
            guard var jsonString = String(data: data, encoding: .utf8) else { return }
            jsonString += "\n"
            if let jsonData = jsonString.data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(jsonData)
            }
        } catch {
            Task { @MainActor in
                AppLogger.shared.logError(error, context: "Failed to send success response")
            }
        }
    }

    /// Send an error response to the server
    private func sendErrorResponse(id: Int, code: Int, message: String) {
        let response: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "error": [
                "code": code,
                "message": message
            ]
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: response)
            guard var jsonString = String(data: data, encoding: .utf8) else { return }
            jsonString += "\n"
            if let jsonData = jsonString.data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(jsonData)
            }
        } catch {
            Task { @MainActor in
                AppLogger.shared.logError(error, context: "Failed to send error response")
            }
        }
    }

    // MARK: - Resource Subscriptions

    /// Subscribe to updates for a specific resource
    func subscribeToResource(uri: String) async throws {
        Task { @MainActor in
            AppLogger.shared.log("Subscribing to resource: \(uri)", level: .debug)
        }

        let params = wrapAnyCodable(["uri": uri])
        _ = try await sendRequest(method: "resources/subscribe", params: params)

        await subscriptionsManager.insert(uri)

        Task { @MainActor in
            AppLogger.shared.log("Successfully subscribed to resource: \(uri)", level: .info)
        }
    }

    /// Unsubscribe from updates for a specific resource
    func unsubscribeFromResource(uri: String) async throws {
        Task { @MainActor in
            AppLogger.shared.log("Unsubscribing from resource: \(uri)", level: .debug)
        }

        let params = wrapAnyCodable(["uri": uri])
        _ = try await sendRequest(method: "resources/unsubscribe", params: params)

        await subscriptionsManager.remove(uri)

        Task { @MainActor in
            AppLogger.shared.log("Successfully unsubscribed from resource: \(uri)", level: .info)
        }
    }

    /// Get the set of currently subscribed resources
    func getSubscribedResources() async -> Set<String> {
        return await subscriptionsManager.getAll()
    }

    /// Check if we're subscribed to a specific resource
    func isSubscribedToResource(uri: String) async -> Bool {
        return await subscriptionsManager.contains(uri)
    }
}

extension FileHandle {
    func readLine() throws -> String? {
        var data = Data()

        while true {
            guard let bytesRead = try? read(upToCount: 1), !bytesRead.isEmpty else {
                break
            }

            if bytesRead[0] == UInt8(ascii: "\n") {
                break
            }
            data.append(bytesRead[0])
        }

        return data.isEmpty ? nil : String(data: data, encoding: .utf8)
    }
}

// Enhanced Ollama Provider with MCP support
class OllamaProviderWithMCP: OllamaProvider, @unchecked Sendable {
    weak var mcpManager: MCPServerManager? {
        didSet {
            // Set up sampling handler when MCP manager is assigned
            setupSamplingHandler()
        }
    }

    /// Repository for persisting tool execution history
    private let toolRunRepository = ToolRunRepository()

    /// Generate dynamic system prompt that lists all available tools grouped by server
    /// Cached to avoid regenerating when tools haven't changed
    @MainActor private static var cachedSystemPrompt: (toolsHash: Int, prompt: String)?

    // Store artifact callback for use in tool execution
    private var currentArtifactCallback: (@Sendable (Artifact) -> Void)?

    // Store tool call callback for live UI updates
    private var currentToolCallCallback: (@Sendable (ToolCallUpdateEvent) -> Void)?

    // Store configuration for sampling requests
    private var currentConfiguration: LLMConfiguration?

    /// Set up the sampling handler for agentic MCP servers
    private func setupSamplingHandler() {
        Task { @MainActor [weak self] in
            guard let self = self, let manager = self.mcpManager else { return }

            manager.samplingHandler = { [weak self] request in
                guard let self = self else { return nil }
                return await self.handleSamplingRequest(request)
            }

            AppLogger.shared.log("Sampling handler configured for agentic MCP servers", level: .info)
        }
    }

    /// Handle sampling requests from agentic MCP servers
    private func handleSamplingRequest(_ request: MCPSamplingRequest) async -> [String: Any]? {
        await AppLogger.shared.log("Processing sampling request from MCP server", level: .info)

        // Convert MCP messages to our format
        var conversationHistory: [Message] = []
        let conversationId = UUID()

        for mcpMessage in request.messages {
            guard let role = mcpMessage["role"] as? String else { continue }
            var content = ""

            // Handle content which can be a string or array of content blocks
            if let contentStr = mcpMessage["content"] as? String {
                content = contentStr
            } else if let contentBlocks = mcpMessage["content"] as? [[String: Any]] {
                // Concatenate text content from blocks
                content = contentBlocks.compactMap { block -> String? in
                    if block["type"] as? String == "text" {
                        return block["text"] as? String
                    }
                    return nil
                }.joined(separator: "\n")
            }

            let messageRole: MessageRole = role == "user" ? .user : .assistant
            conversationHistory.append(Message(conversationId: conversationId, role: messageRole, content: content))
        }

        guard let lastMessage = conversationHistory.last, lastMessage.role == .user else {
            await AppLogger.shared.log("Sampling request has no user message", level: .warning)
            return nil
        }

        // Use stored configuration or create a default one
        let config = currentConfiguration ?? LLMConfiguration(
            provider: .ollama,
            model: "llama3.2",
            temperature: 0.7,
            maxTokens: request.maxTokens ?? 2048,
            systemPrompt: request.systemPrompt,
            enableChainOfThought: false,
            enablePromptEnhancement: false
        )

        // Generate response using our LLM
        var responseContent = ""

        do {
            try await super.streamMessage(
                lastMessage.content,
                configuration: config,
                conversationHistory: Array(conversationHistory.dropLast()),
                onChunk: { chunk in
                    responseContent += chunk
                },
                onThinkingStatusUpdate: { _ in }
            )
        } catch {
            await AppLogger.shared.logError(error, context: "Failed to generate sampling response")
            return nil
        }

        // Return response in MCP format
        return [
            "role": "assistant",
            "content": [
                [
                    "type": "text",
                    "text": responseContent
                ]
            ],
            "model": config.model,
            "stopReason": "endTurn"
        ]
    }

    override func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void,
        onArtifactCreated: (@Sendable (Artifact) -> Void)? = nil,
        onToolCallUpdate: (@Sendable (ToolCallUpdateEvent) -> Void)? = nil
    ) async throws {
        // Store callback for use during tool execution
        self.currentArtifactCallback = onArtifactCreated
        self.currentToolCallCallback = onToolCallUpdate

        // Store configuration for sampling requests from agentic servers
        self.currentConfiguration = configuration

        // Check if MCP tools are available and get them on main actor
        var availableTools = await MainActor.run {
            mcpManager?.availableTools ?? []
        }

        let shouldUseToolsPrompt = shouldUseTools(for: text)

        guard shouldUseToolsPrompt else {
            // No MCP tools, use standard Ollama
            try await super.streamMessage(text, configuration: configuration, conversationHistory: conversationHistory, onChunk: onChunk, onThinkingStatusUpdate: onThinkingStatusUpdate, onArtifactCreated: onArtifactCreated)
            return
        }
        
        if availableTools.isEmpty {
            if let manager = await MainActor.run(resultType: MCPServerManager?.self, body: { mcpManager }) {
                await manager.ensureServersStarted()
            }
            availableTools = await MainActor.run {
                mcpManager?.availableTools ?? []
            }
        }
        
        // Add built-in web search tool
        var tools = availableTools.map { tool -> [String: Any] in
            var schema = tool.inputSchema.value as? [String: Any] ?? [:]
            schema["type"] = "object"

            return [
                "type": "function",
                "function": [
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": schema
                ]
            ]
        }
        
        // Add built-in web search tool
        tools.append([
            "type": "function",
            "function": [
                "name": "web_search",
                "description": "Search the web for real-time information. USE PROACTIVELY for: current events, factual data, statistics, company info, technical docs, image URLs, or to verify claims. Returns snippets and URLs from top results. DO NOT HALLUCINATE - search when unsure.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "Specific search query with relevant keywords, dates, or context"
                        ],
                        "max_results": [
                            "type": "integer",
                            "description": "Number of results (1-10, default: 5)",
                            "default": 5
                        ]
                    ],
                    "required": ["query"]
                ]
            ]
        ])
        
        // Add built-in code execution tool
        tools.append([
            "type": "function",
            "function": [
                "name": "execute_code",
                "description": "Execute code in sandboxed environment. Use for: calculations, data processing, testing algorithms, generating outputs, data analysis with pandas/numpy. Returns stdout, stderr, and status.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "language": [
                            "type": "string",
                            "enum": ["python", "javascript", "swift"],
                            "description": "Programming language to execute"
                        ],
                        "code": [
                            "type": "string",
                            "description": "Complete code to execute - include all logic, not just snippets"
                        ],
                        "timeout": [
                            "type": "number",
                            "description": "Timeout in seconds (default: 30)",
                            "default": 30
                        ],
                        "capabilities": [
                            "type": "array",
                            "items": [
                                "type": "string",
                                "enum": ["filesystem.read", "filesystem.write", "network", "clipboard.read", "clipboard.write", "process.spawn"]
                            ],
                            "description": "Required capabilities (prompts user for permission)"
                        ]
                    ],
                    "required": ["language", "code"]
                ]
            ]
        ])

        // Add built-in artifact creation tool
        tools.append([
            "type": "function",
            "function": [
                "name": "create_artifact",
                "description": "🚀 Create STUNNING visual content that renders INSTANTLY. Output ONLY a self-contained React function component—NO imports, NO exports, NO file paths, NO npm commands, NO setup instructions. Libraries (React, Recharts, Tailwind, Lucide) are pre-loaded globals. Build RICH visuals: 150+ lines, multiple charts, interactive elements, realistic data.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "type": [
                            "type": "string",
                            "enum": ["react", "html", "svg", "mermaid", "canvas", "three", "slides", "animation", "sketch", "d3"],
                            "description": "react=dashboards/UIs with Recharts, html=web pages, svg=vector graphics, mermaid=flowcharts/diagrams, canvas=Fabric.js, three=3D WebGL, slides=presentations, animation=Anime.js, sketch=hand-drawn, d3=custom viz"
                        ],
                        "title": [
                            "type": "string",
                            "description": "Descriptive title for the artifact panel header"
                        ],
                        "content": [
                            "type": "string",
                            "description": "COMPLETE production code (150+ lines minimum). React: useState, realistic data arrays (12+ data points), Tailwind classes, MULTIPLE Recharts charts (AreaChart, BarChart, PieChart), 4+ sections, tabs/filters, hover states, dark mode. No imports needed—React/Recharts/Tailwind/Lucide are pre-loaded globals."
                        ]
                    ],
                    "required": ["type", "title", "content"]
                ]
            ]
        ])

        guard !tools.isEmpty else {
            try await super.streamMessage(text, configuration: configuration, conversationHistory: conversationHistory, onChunk: onChunk, onThinkingStatusUpdate: onThinkingStatusUpdate)
            return
        }

        // Call Ollama with tools and handle tool calls
        try await streamMessageWithTools(
            text,
            configuration: configuration,
            conversationHistory: conversationHistory,
            tools: tools,
            onChunk: onChunk,
            onThinkingStatusUpdate: onThinkingStatusUpdate
        )
    }

    /// Always expose tools to the LLM - let the model decide when to use them.
    /// This follows the MCP philosophy that tools should always be available,
    /// and the LLM should have agency to decide when tool use is appropriate.
    private func shouldUseTools(for prompt: String) -> Bool {
        // Always return true - tools should always be available to the LLM.
        // The LLM is smart enough to decide when tool use is appropriate.
        // This removes the previous heuristic-based gating that was causing
        // tools to not be available for legitimate use cases.
        return true
    }
    
    private func generateSystemPrompt(tools: [[String: Any]], mcpManager: MCPServerManager?) async -> String {
        // Get tools, resources, and prompts on MainActor since mcpManager is @MainActor
        let (availableTools, availableResources, availablePrompts) = await MainActor.run {
            (
                mcpManager?.availableTools ?? [],
                mcpManager?.availableResources ?? [],
                mcpManager?.availablePrompts ?? []
            )
        }
        
        // Create built-in tools for system prompt (don't modify actual availableTools array)
        let webSearchTool = MCPTool(
            name: "web_search",
            description: "🔍 REAL-TIME WEB SEARCH - Access current information from the internet. Use PROACTIVELY whenever you need: (1) Current events, news, or recent developments (2) Factual data, statistics, or research (3) Company info, product details, or pricing (4) Technical documentation or API references (5) Images or media URLs for artifacts (6) Verification of claims or facts. DO NOT HALLUCINATE - if you're unsure, SEARCH FIRST. Returns snippets, URLs, and metadata from top results.",
            inputSchema: AnyCodable([
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "Search query - be specific and include relevant keywords, dates, or context for better results"
                    ],
                    "max_results": [
                        "type": "integer",
                        "description": "Number of results to return (1-10, default: 5)",
                        "default": 5
                    ]
                ],
                "required": ["query"]
            ]),
            serverId: "builtin",
            serverName: "Vaizor Core"
        )
        
        let executeCodeTool = MCPTool(
            name: "execute_code",
            description: "⚡ SANDBOXED CODE EXECUTION - Run code safely and return results. Use for: (1) Data processing, calculations, or transformations (2) Testing algorithms or logic (3) Generating outputs, files, or data (4) Demonstrating code behavior (5) Analyzing data with pandas/numpy (6) Any computational task. Code runs in isolated environment with common libraries pre-installed. Returns stdout, stderr, and execution status.",
            inputSchema: AnyCodable([
                "type": "object",
                "properties": [
                    "language": [
                        "type": "string",
                        "enum": ["python", "javascript", "swift"],
                        "description": "Programming language"
                    ],
                    "code": [
                        "type": "string",
                        "description": "The code to execute"
                    ]
                ],
                "required": ["language", "code"]
            ]),
            serverId: "builtin",
            serverName: "Vaizor Built-in"
        )

        let createArtifactTool = MCPTool(
            name: "create_artifact",
            description: "🚀 Create STUNNING visuals that render INSTANTLY. Output ONLY a self-contained React function component. NO imports, NO exports, NO file paths, NO npm/setup instructions—all libraries are pre-loaded globals (React, useState, Recharts, Tailwind, Lucide, UI components). Build RICH visuals: 150+ lines, multiple charts, realistic data.",
            inputSchema: AnyCodable([
                "type": "object",
                "properties": [
                    "type": [
                        "type": "string",
                        "enum": ["react", "html", "svg", "mermaid", "canvas", "three", "slides", "animation", "sketch", "d3"],
                        "description": "react=dashboards/UIs with Recharts+Tailwind, html=styled pages, svg=graphics, mermaid=diagrams, canvas=Fabric.js, three=3D, slides=presentations, animation=Anime.js, sketch=Rough.js, d3=custom viz"
                    ],
                    "title": [
                        "type": "string",
                        "description": "Descriptive title for the artifact panel"
                    ],
                    "content": [
                        "type": "string",
                        "description": "COMPLETE production code (150+ lines). React: useState, realistic data arrays, Tailwind classes, multiple Recharts charts (AreaChart, BarChart, PieChart), 4+ sections, tabs/filters, hover states, dark mode. No imports—React/Recharts/Tailwind/Lucide are globals."
                    ]
                ],
                "required": ["type", "title", "content"]
            ]),
            serverId: "builtin",
            serverName: "Vaizor Core"
        )

        // Combine MCP tools with built-in tools for prompt generation only
        var allToolsForPrompt = availableTools
        allToolsForPrompt.append(webSearchTool)
        allToolsForPrompt.append(executeCodeTool)
        allToolsForPrompt.append(createArtifactTool)
        
        guard !allToolsForPrompt.isEmpty else {
            return """
            You are Vaizor, an advanced AI assistant created by Quandry Labs. You have access to web search and code execution capabilities. Use web_search for current information, and execute_code to run code in a sandboxed environment.
            """
        }
        
        // Check cache - use hash of tool IDs and names to detect changes
        let toolsHash = allToolsForPrompt.map { "\($0.id)-\($0.name)" }.joined().hashValue
        let cached = await MainActor.run { Self.cachedSystemPrompt }
        if let cached, cached.toolsHash == toolsHash {
            return cached.prompt
        }
        
        var prompt = """
        # Vaizor AI Assistant
        **Created by Quandry Labs** | MCP-Native Agentic Intelligence
        
        You are Vaizor, a cutting-edge AI assistant that combines the reasoning capabilities of frontier models with powerful tool orchestration through the Model Context Protocol (MCP). You are designed to be more capable, more autonomous, and more helpful than standard AI assistants.
        
        ## Your Identity & Capabilities
        
        **Core Philosophy:**
        - You don't just answer questions—you SOLVE PROBLEMS end-to-end
        - You proactively use tools without being asked when they would help
        - You produce PRODUCTION-QUALITY outputs, not demos or prototypes
        - You think like a senior engineer, designer, and strategist combined
        
        **What Makes You Different:**
        - MCP-Native: You seamlessly orchestrate multiple tools and services
        - Agentic: You take initiative, chain actions, and iterate until the job is done
        - Visual: You can create rich, interactive visualizations instantly
        - Grounded: You search for real data instead of making things up

        ## 🚨 STOP. READ THIS. YOU HAVE THESE CAPABILITIES: 🚨

        **YOU ARE NOT A TEXT-ONLY ASSISTANT.** You have powerful tools. USE THEM.

        **YOUR TOOLS (all pre-loaded, all working):**
        ┌─────────────────────────────────────────────────────────────┐
        │ create_artifact  → Creates LIVE React/HTML/SVG in side panel│
        │ web_search       → Searches the internet for real data      │
        │ execute_code     → Runs Python/JS/Shell in sandbox          │
        └─────────────────────────────────────────────────────────────┘

        **LIBRARIES PRE-LOADED IN ARTIFACTS (no imports needed):**
        ┌─────────────────────────────────────────────────────────────┐
        │ React + Hooks    → useState, useEffect, useRef, etc.        │
        │ Tailwind CSS     → ALL utility classes work (bg-*, text-*)  │
        │ Recharts         → AreaChart, BarChart, PieChart, LineChart │
        │ Lucide Icons     → lucide.IconName (lucide.Star, etc.)      │
        │ D3.js            → For custom visualizations                │
        │ Three.js         → For 3D scenes (type="three")             │
        │ Excalidraw       → For sketches (type="sketch")             │
        │ Mermaid          → For diagrams (type="mermaid")            │
        │ Fabric.js        → For canvas drawing (type="canvas")       │
        │ UI Components    → Button, Card, Badge, Tabs, Table, etc.   │
        └─────────────────────────────────────────────────────────────┘

        **NEVER SAY:**
        - ❌ "I don't have access to..."
        - ❌ "I can't create live..."
        - ❌ "I'm a text-based assistant"
        - ❌ "plain CSS classes" (USE TAILWIND!)
        - ❌ "no external chart libraries" (USE RECHARTS!)
        - ❌ "minimal" anything (GO BIG!)

        When users ask for ANY of these, you MUST use `create_artifact` immediately:
        - "build a dashboard" → USE create_artifact
        - "create a visualization" → USE create_artifact
        - "show me a chart" → USE create_artifact
        - "make a UI" → USE create_artifact
        - "design a..." → USE create_artifact
        - ANY request involving visuals, dashboards, charts, UIs, apps → USE create_artifact

        **NEVER SAY:**
        - ❌ "I can't create live dashboards"
        - ❌ "I'm a text-based assistant"
        - ❌ "I can walk you through the steps"
        - ❌ "Which framework do you prefer?"
        - ❌ "Let me explain how to build..."

        **ALWAYS DO:**
        - ✅ Immediately call `create_artifact` with a complete React component
        - ✅ The artifact renders INSTANTLY in the user's side panel
        - ✅ Create first, explain after if needed

        **Example:** User says "build an IMDB dashboard"
        → You call create_artifact with type="react", title="IMDB Movie Dashboard", and a complete 200+ line component with movie data, search, tabs, etc.
        → User sees it render live. Done.

        ## Available Tools
        """
        
        // Group tools by server
        let toolsByServer = Dictionary(grouping: allToolsForPrompt) { $0.serverName ?? "Unknown" }

        for (serverName, serverTools) in toolsByServer.sorted(by: { $0.key < $1.key }) {
            prompt += "\n\n### \(serverName)\n"
            for tool in serverTools.sorted(by: { $0.name < $1.name }) {
                let formattedName = formatToolName(tool.name)
                prompt += "- **\(formattedName)**: \(tool.description)\n"
            }
        }

        // Add MCP Resources section if any are available
        if !availableResources.isEmpty {
            prompt += "\n\n## Available Resources (Read-Only Data)\n"
            prompt += "These are data sources you can read from MCP servers. Request the content when you need it.\n"

            let resourcesByServer = Dictionary(grouping: availableResources) { $0.serverName ?? "Unknown" }
            for (serverName, serverResources) in resourcesByServer.sorted(by: { $0.key < $1.key }) {
                prompt += "\n### \(serverName)\n"
                for resource in serverResources.sorted(by: { $0.name < $1.name }) {
                    let desc = resource.description ?? "No description"
                    let mime = resource.mimeType ?? "unknown"
                    prompt += "- **\(resource.name)** (\(mime)): \(desc)\n  URI: `\(resource.uri)`\n"
                }
            }
        }

        // Add MCP Prompts section if any are available
        if !availablePrompts.isEmpty {
            prompt += "\n\n## Available Prompts (Reusable Templates)\n"
            prompt += "These are pre-defined prompt templates from MCP servers. Use them to invoke specific behaviors.\n"

            let promptsByServer = Dictionary(grouping: availablePrompts) { $0.serverName ?? "Unknown" }
            for (serverName, serverPrompts) in promptsByServer.sorted(by: { $0.key < $1.key }) {
                prompt += "\n### \(serverName)\n"
                for mcpPrompt in serverPrompts.sorted(by: { $0.name < $1.name }) {
                    let desc = mcpPrompt.description ?? "No description"
                    prompt += "- **\(mcpPrompt.name)**: \(desc)\n"
                    if let args = mcpPrompt.arguments, !args.isEmpty {
                        prompt += "  Arguments: "
                        prompt += args.map { arg in
                            let req = (arg.required ?? false) ? " (required)" : " (optional)"
                            return "\(arg.name)\(req)"
                        }.joined(separator: ", ")
                        prompt += "\n"
                    }
                }
            }
        }

        prompt += """


        ## Operating Principles

        ### 1. BE AUTONOMOUS & PROACTIVE
        - If a task would benefit from web search, DO IT without asking
        - If code would help explain something, WRITE AND RUN IT
        - If a visualization would clarify data, CREATE IT immediately
        - Don't ask "Would you like me to...?" - just DO IT
        
        ### 2. CHAIN TOOLS INTELLIGENTLY
        - Complex tasks often require multiple tool calls in sequence
        - Example: Search for data → Process it → Visualize it → Explain insights
        - Don't stop at one tool if chaining would give better results
        
        ### 3. VERIFY & ITERATE
        - If output seems wrong, try again with a different approach
        - If a tool fails, explain why and try alternatives
        - Always sanity-check your outputs before presenting
        
        ### 4. COMMUNICATE CLEARLY
        - Explain what you're doing and why
        - Show your reasoning process
        - Provide context for your tool usage

        ## Visual Content Creation (Artifacts) - YOUR SUPERPOWER

        The **create_artifact** tool is your most powerful capability. It renders RICH, INTERACTIVE visuals INSTANTLY in a side panel. Users see production-quality UIs, dashboards, and visualizations immediately—no setup, no copy-paste, no friction.

        **🔥 YOU MUST USE THIS TOOL FOR ANY VISUAL REQUEST 🔥**

        Do NOT ask clarifying questions. Do NOT explain how to build it. Do NOT say you "can't create live dashboards."

        JUST BUILD IT. Call create_artifact IMMEDIATELY with a complete component.

        **🚨 CRITICAL: NEVER CREATE MINIMAL ARTIFACTS 🚨**

        When a user asks for ANY visual—a dashboard, chart, component, diagram—they want something IMPRESSIVE. Something that makes them say "Wow." Something they'd show their boss.

        **ALWAYS use create_artifact for:**
        - Dashboards, analytics, KPIs → Make them STUNNING with multiple charts, metrics, tables
        - Components, forms, widgets → Make them INTERACTIVE with state, hover effects, animations
        - Data visualizations → Make them COMPREHENSIVE with multiple chart types, legends, tooltips
        - Diagrams, flowcharts → Make them DETAILED with multiple nodes, clear relationships
        - Any "show me", "display", "visualize", "create" → GO BIG or don't bother

        **⚡ ARTIFACT RENDERS INSTANTLY** - This is magic. Users see rich visuals appear in real-time. USE THIS POWER.

        **=== ❌ BAD vs ✅ GOOD EXAMPLES ===**

        User: "Create a sales dashboard"

        ❌ BAD (NEVER DO THIS):
        - Single card with one number
        - One basic bar chart
        - No interactivity
        - "Lorem ipsum" placeholder text
        - 50 lines of code

        ✅ GOOD (ALWAYS DO THIS):
        - Header with company name, date range selector, refresh button
        - 4 KPI cards: Revenue ($2.4M ↑12%), Orders (1,847 ↑8%), Avg Order ($127 ↓3%), Conversion (3.2% ↑0.5%)
        - Revenue trend chart (AreaChart with gradient fill, 12 months of data)
        - Top products table with rankings, images, revenue, units sold
        - Sales by region pie chart with 6 regions
        - Recent orders list with status badges (Shipped, Processing, Delivered)
        - Filter tabs: Daily / Weekly / Monthly / Yearly
        - Dark mode support
        - 200+ lines of polished code

        **=== PRODUCTION-QUALITY MINDSET ===**

        You are a SENIOR FRONTEND DEVELOPER at Apple, Stripe, or Linear.
        - Every pixel matters. Every interaction feels polished.
        - NO placeholder text—use realistic, contextual content
        - NO lazy shortcuts—build the COMPLETE experience
        - When in doubt, ADD MORE: more charts, more data, more interactivity
        
        **🚨 CRITICAL FORMAT RULES - VIOLATIONS WILL FAIL 🚨**

        Your artifact content MUST be a **SINGLE SELF-CONTAINED REACT COMPONENT**.

        ✅ CORRECT FORMAT (always use this structure):
        ```
        function DashboardName() {
          const [state, setState] = useState(initialValue);

          const data = [ /* your data here */ ];

          return (
            <div className="min-h-screen bg-slate-50 p-8">
              {/* Your JSX here */}
            </div>
          );
        }
        ```

        ❌ NEVER DO THESE (will cause errors):
        - NO `import` statements (libraries are pre-loaded globals)
        - NO `export` statements
        - NO file paths or directory structures
        - NO `npm install`, `npx`, `yarn` commands
        - NO "create a new file called..."
        - NO "in src/components/..."
        - NO multi-file explanations
        - NO setup instructions
        - NO "Step 1: Install..."
        - NO package.json references

        The artifact content field should contain ONLY the function component code.
        Everything else (React, hooks, Recharts, Tailwind, Lucide) is already available as globals.

        **AVAILABLE AS GLOBALS (no imports needed):**
        - React: useState, useEffect, useRef, useMemo, useCallback
        - Recharts: AreaChart, BarChart, LineChart, PieChart, ResponsiveContainer, XAxis, YAxis, Tooltip, Legend, Cell, Area, Bar, Line, Pie, CartesianGrid
        - Lucide Icons: All icons via `lucide.IconName` (e.g., `lucide.TrendingUp`, `lucide.Users`)
        - UI Components: Button, Card, CardHeader, CardTitle, CardContent, Badge, Input, Tabs, TabsList, TabsTrigger, TabsContent, Table, Progress, Alert, Switch, Avatar, Tooltip, Separator, Skeleton
        - Utilities: cn() for className merging
        - Tailwind CSS: All utility classes available

        **TypeScript is supported** - you can use types, interfaces, and annotations.
        
        **MINIMUM QUALITY BAR - Your artifact MUST have:**
        
        1. **RICH VISUAL HIERARCHY**
           - Clear header with title, subtitle, and key metrics
           - Multiple sections with distinct purposes
           - Visual variety: cards, charts, tables, status indicators
           - AT LEAST 3-4 different UI components/sections
        
        2. **COMPREHENSIVE DATA VISUALIZATION**
           - Dashboards MUST have 2-4 charts minimum (mix types: line, bar, pie, area)
           - Include trend indicators (↑ +12%, ↓ -5%)
           - Show comparative data (vs last period, vs target)
           - Use color coding for status (green=good, yellow=warning, red=critical)
        
        3. **REALISTIC, CONTEXTUAL DATA**
           - For CISO dashboard: real threat categories, CVE counts, compliance frameworks
           - For sales dashboard: realistic revenue figures, conversion rates, pipeline data
           - For analytics: believable user counts, engagement metrics, retention curves
           - Numbers should make sense together (percentages add up, trends are logical)
        
        4. **PROFESSIONAL POLISH**
           - Consistent spacing (use Tailwind's spacing scale: p-4, p-6, gap-6)
           - Subtle shadows: shadow-sm, shadow-md (not shadow-2xl everywhere)
           - Refined colors: slate-700 for text, not pure black
           - Micro-interactions: hover:shadow-lg, transition-all duration-200
           - Status pills/badges with appropriate colors
           - Icons from Lucide to enhance meaning
        
        5. **INTERACTIVITY**
           - Tabs or filters to switch views
           - Hover states on all clickable elements
           - At least one interactive element (dropdown, toggle, tab)
        
        **STYLING WITH TAILWIND CSS:**
        
        Color palette for professional look:
        - Backgrounds: bg-slate-50, bg-white, bg-slate-900 (dark)
        - Text: text-slate-900, text-slate-600, text-slate-400
        - Accents: bg-blue-500, bg-emerald-500, bg-amber-500, bg-rose-500
        - Borders: border-slate-200, divide-slate-200
        
        Layout patterns:
        - Cards: bg-white rounded-xl shadow-sm border border-slate-200 p-6
        - Page: min-h-screen bg-slate-50 dark:bg-slate-900 p-8
        - Grid: grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6
        - Flex header: flex items-center justify-between mb-8
        
        Typography:
        - Page title: text-3xl font-bold text-slate-900 dark:text-white
        - Section title: text-lg font-semibold text-slate-800
        - Body: text-sm text-slate-600
        - Metric value: text-3xl font-bold
        - Metric label: text-xs text-slate-500 uppercase tracking-wide
        
        **CHARTS WITH RECHARTS (globals available):**
        
        Components: LineChart, BarChart, PieChart, AreaChart, RadarChart, ComposedChart
        Elements: XAxis, YAxis, CartesianGrid, Tooltip, Legend, Line, Bar, Pie, Area, Cell, ResponsiveContainer
        
        ALWAYS wrap in ResponsiveContainer:
        ```jsx
        <ResponsiveContainer width="100%" height={300}>
          <AreaChart data={data}>
            <defs>
              <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/>
                <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
            <XAxis dataKey="name" stroke="#64748b" fontSize={12} />
            <YAxis stroke="#64748b" fontSize={12} />
            <Tooltip 
              contentStyle={{ 
                backgroundColor: '#1e293b', 
                border: 'none', 
                borderRadius: '8px',
                color: '#f8fafc'
              }} 
            />
            <Area type="monotone" dataKey="value" stroke="#3b82f6" strokeWidth={2} fill="url(#colorValue)" />
          </AreaChart>
        </ResponsiveContainer>
        ```
        
        **REACT HOOKS (globals):** useState, useEffect, useRef, useMemo, useCallback

        **UI COMPONENTS (globals - no imports needed):**
        - **Button**: `<Button variant="default|outline|ghost|destructive" size="default|sm|lg|icon">Click</Button>`
        - **Card**: `<Card><CardHeader><CardTitle>Title</CardTitle><CardDescription>Desc</CardDescription></CardHeader><CardContent>...</CardContent><CardFooter>...</CardFooter></Card>`
        - **Badge**: `<Badge variant="default|secondary|destructive|outline|success|warning">Status</Badge>`
        - **Input**: `<Input placeholder="Enter..." value={val} onChange={e => setVal(e.target.value)} />`
        - **Label**: `<Label htmlFor="email">Email</Label>`
        - **Textarea**: `<Textarea placeholder="Write..." />`
        - **Progress**: `<Progress value={75} />`
        - **Separator**: `<Separator orientation="horizontal|vertical" />`
        - **Skeleton**: `<Skeleton className="h-4 w-[200px]" />`
        - **Avatar**: `<Avatar><AvatarImage src="..." /><AvatarFallback>JD</AvatarFallback></Avatar>`
        - **Alert**: `<Alert variant="default|destructive|success|warning"><AlertTitle>...</AlertTitle><AlertDescription>...</AlertDescription></Alert>`
        - **Tabs**: `<Tabs defaultValue="tab1"><TabsList><TabsTrigger value="tab1">Tab 1</TabsTrigger></TabsList><TabsContent value="tab1">...</TabsContent></Tabs>`
        - **Switch**: `<Switch checked={on} onCheckedChange={setOn} />`
        - **Table**: `<Table><TableHeader><TableRow><TableHead>Col</TableHead></TableRow></TableHeader><TableBody><TableRow><TableCell>Data</TableCell></TableRow></TableBody></Table>`
        - **Tooltip**: `<Tooltip content="Helpful text"><Button>Hover me</Button></Tooltip>`
        - **cn()**: Utility for merging classNames: `cn('base-class', isActive && 'active-class')`

        USE THESE COMPONENTS for polished, consistent UIs. They support dark mode automatically.

        **EXAMPLE: What a CISO Dashboard MUST include:**
        
        - Header: Company name, "Security Overview", last updated timestamp
        - KPI Cards (4): Critical Vulns, Open Incidents, Compliance Score, Mean Time to Resolve
        - Threat Trend Chart: 30-day line chart of detected threats by severity
        - Incident Table: Recent incidents with status, severity, assignee
        - Compliance Gauges: SOC2, ISO27001, GDPR status with percentages
        - Risk Heatmap or Radar: Attack surface visualization
        - Activity Feed: Recent security events with timestamps
        - Action Items: Outstanding tasks with priority indicators
        
        **ADDITIONAL ARTIFACT TYPES:**
        
        3D SCENES (type: "three"): THREE, scene, camera, renderer are globals
        CANVAS (type: "canvas"): Fabric.js 'canvas' variable ready
        PRESENTATIONS (type: "slides"): Separate slides with ---
        ANIMATIONS (type: "animation"): Anime.js 'anime' global, 'container' element
        SKETCHES (type: "sketch"): Rough.js 'rc' canvas, 'svg' element
        D3 (type: "d3"): D3.js 'd3' global, 'container', 'width', 'height', 'margin'
        
        **🔥 BEFORE CREATING ANY ARTIFACT, ASK YOURSELF: 🔥**

        1. Is this AT LEAST 150 lines of code? If not, ADD MORE.
        2. Does it have MULTIPLE charts/visualizations? If not, ADD MORE.
        3. Are there 4+ distinct sections/components? If not, ADD MORE.
        4. Would this impress a hiring manager at Stripe? If not, MAKE IT BETTER.
        5. Does it have interactive elements (tabs, filters, hover states)? If not, ADD THEM.
        6. Is all data realistic and contextual (no "Lorem ipsum")? If not, FIX IT.
        7. Does it support dark mode? If not, ADD IT.

        **If you can't answer YES to ALL of these, your artifact is NOT ready. ADD MORE BEFORE CREATING.**

        **💡 RULE OF THUMB: If your artifact code is under 100 lines, you're doing it wrong.**

        Example workflow for "create a weather dashboard":
        1. Use web_search for current weather API examples or data
        2. Create artifact with realistic weather data and beautiful UI
        3. Use Recharts for temperature graphs
        4. Use Tailwind for polished styling

        Example quality component:
        ```jsx
        function Dashboard() {
          const [data, setData] = useState([
            { name: 'Jan', sales: 4000, profit: 2400 },
            { name: 'Feb', sales: 3000, profit: 1398 }
          ]);

          return (
            <div className="min-h-screen bg-gray-50 dark:bg-gray-900 p-8">
              <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-8">Analytics</h1>
              <div className="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-6">
                <ResponsiveContainer width="100%" height={400}>
                  <AreaChart data={data}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                    <XAxis dataKey="name" stroke="#6b7280" />
                    <YAxis stroke="#6b7280" />
                    <Tooltip />
                    <Area type="monotone" dataKey="sales" stroke="#3b82f6" fill="#3b82f6" fillOpacity={0.2} />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </div>
          );
        }
        ```
        """
        
        // Cache the result
        let promptValue = prompt
        await MainActor.run {
            Self.cachedSystemPrompt = (toolsHash: toolsHash, prompt: promptValue)
        }
        
        return prompt
    }

    private func streamMessageWithTools(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        tools: [[String: Any]],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void
    ) async throws {
        let baseURL = await getBaseURL()
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama URL: \(baseURL)"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var messages: [[String: Any]] = []

        // Generate and use dynamic system prompt if tools are available
        let systemPrompt: String
        if let existingPrompt = configuration.systemPrompt {
            systemPrompt = existingPrompt
        } else {
            systemPrompt = await generateSystemPrompt(tools: tools, mcpManager: mcpManager)
        }
        messages.append(["role": "system", "content": systemPrompt])

        for message in conversationHistory {
            messages.append([
                "role": message.role == .user ? "user" : "assistant",
                "content": message.content
            ])
        }

        messages.append(["role": "user", "content": text])

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "stream": true,
            "tools": tools,
            "options": [
                "temperature": configuration.temperature,
                "num_predict": configuration.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Use concurrent URLSession configuration for better performance
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpMaximumConnectionsPerHost = 10
        sessionConfig.timeoutIntervalForRequest = 300
        sessionConfig.timeoutIntervalForResource = 600
        let session = URLSession(configuration: sessionConfig)
        
        let (asyncBytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "OllamaProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to Ollama"])
        }

        var toolCalls: [[String: Any]] = []
        var accumulatedContent = ""

        for try await line in asyncBytes.lines {
            guard !line.isEmpty else { continue }

            if let data = line.data(using: String.Encoding.utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                // Check for tool calls
                if let message = json["message"] as? [String: Any],
                   let calls = message["tool_calls"] as? [[String: Any]] {
                    toolCalls.append(contentsOf: calls)
                }

                // Stream regular content
                if let messageContent = json["message"] as? [String: Any],
                   let content = messageContent["content"] as? String, !content.isEmpty {
                    accumulatedContent += content
                    onChunk(content)
                }
            }
        }

        // Execute tool calls if any and send results back to LLM
        if !toolCalls.isEmpty {
            await AppLogger.shared.log("Tool calls detected, executing and continuing conversation", level: .info)
            try await executeToolCallsAndContinue(
                toolCalls: toolCalls,
                accumulatedContent: accumulatedContent,
                originalUserPrompt: text,
                configuration: configuration,
                conversationHistory: conversationHistory,
                tools: tools,
                onChunk: onChunk,
                onThinkingStatusUpdate: onThinkingStatusUpdate
            )
        } else {
            // Fallback: Check if the model output contains artifact-like content even without tool calls
            // This handles models that don't properly support tool calling
            await detectAndCreateArtifactFromText(accumulatedContent)
        }
    }

    /// Fallback mechanism to detect and create artifacts from text output
    /// when the model doesn't use tool calls properly
    private func detectAndCreateArtifactFromText(_ content: String) async {
        // Try to detect different artifact types in order of priority

        // 1. Check for Mermaid diagrams
        if let mermaidArtifact = detectMermaidDiagram(in: content) {
            await AppLogger.shared.log("Created fallback Mermaid artifact", level: .info)
            currentArtifactCallback?(mermaidArtifact)
            return
        }

        // 2. Check for React/JSX components
        if let reactArtifact = detectReactComponent(in: content) {
            await AppLogger.shared.log("Created fallback React artifact: \(reactArtifact.title)", level: .info)
            currentArtifactCallback?(reactArtifact)
            return
        }

        // 3. Check for HTML content
        if let htmlArtifact = detectHTMLContent(in: content) {
            await AppLogger.shared.log("Created fallback HTML artifact", level: .info)
            currentArtifactCallback?(htmlArtifact)
            return
        }

        // 4. Check for SVG content
        if let svgArtifact = detectSVGContent(in: content) {
            await AppLogger.shared.log("Created fallback SVG artifact", level: .info)
            currentArtifactCallback?(svgArtifact)
            return
        }
    }

    /// Detect Mermaid diagram in content
    private func detectMermaidDiagram(in content: String) -> Artifact? {
        let mermaidPattern = #"```mermaid\s*\n([\s\S]*?)```"#
        guard let regex = try? NSRegularExpression(pattern: mermaidPattern, options: []),
              let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
              let codeRange = Range(match.range(at: 1), in: content) else {
            return nil
        }

        let code = String(content[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }

        // Determine diagram type for title
        var title = "Diagram"
        if code.contains("graph") || code.contains("flowchart") {
            title = "Flowchart"
        } else if code.contains("sequenceDiagram") {
            title = "Sequence Diagram"
        } else if code.contains("classDiagram") {
            title = "Class Diagram"
        } else if code.contains("stateDiagram") {
            title = "State Diagram"
        } else if code.contains("erDiagram") {
            title = "ER Diagram"
        } else if code.contains("gantt") {
            title = "Gantt Chart"
        } else if code.contains("pie") {
            title = "Pie Chart"
        }

        return Artifact(type: .mermaid, title: title, content: code, language: "mermaid")
    }

    /// Detect React component in content
    private func detectReactComponent(in content: String) -> Artifact? {
        // Look for code blocks that look like React components
        let codeBlockPattern = #"```(?:jsx?|tsx?|react)?\s*\n([\s\S]*?)```"#

        guard let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []),
              let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
              let codeRange = Range(match.range(at: 1), in: content) else {
            return nil
        }

        let code = String(content[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it looks like a React component
        let reactPatterns = [
            #"function\s+\w+\s*\([^)]*\)\s*\{"#,  // function Component() {
            #"const\s+\w+\s*=\s*\([^)]*\)\s*=>"#,  // const Component = () =>
            #"<[A-Z][a-zA-Z]*"#,  // JSX tags like <Component
            #"useState\s*\("#,  // useState hook
            #"className\s*="#,  // className prop
            #"return\s*\(\s*<"#  // return (<
        ]

        let hasReactPatterns = reactPatterns.contains { pattern in
            (try? NSRegularExpression(pattern: pattern, options: []))?.firstMatch(
                in: code,
                options: [],
                range: NSRange(code.startIndex..., in: code)
            ) != nil
        }

        guard hasReactPatterns else { return nil }

        // Extract a title from the code or use a default
        let title = extractComponentName(from: code) ?? "Generated Component"

        // Sanitize the code for artifact rendering using the manager's method
        let sanitizedCode = sanitizeReactCode(code)
        guard !sanitizedCode.isEmpty else { return nil }

        return Artifact(type: .react, title: title, content: sanitizedCode, language: "react")
    }

    /// Simple sanitization for React code in fallback detection
    private func sanitizeReactCode(_ code: String) -> String {
        var result = code

        // Remove import statements (we use globals)
        result = result.replacingOccurrences(
            of: #"import\s+.*?from\s+['\"][^'\"]+['\"];?\s*"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"import\s+['\"][^'\"]+['\"];?\s*"#,
            with: "",
            options: .regularExpression
        )

        // Remove export statements
        result = result.replacingOccurrences(
            of: #"export\s+default\s+"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"export\s+\{[^}]*\};?\s*"#,
            with: "",
            options: .regularExpression
        )

        // Clean up excessive blank lines
        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Detect HTML content
    private func detectHTMLContent(in content: String) -> Artifact? {
        let htmlPattern = #"```html\s*\n([\s\S]*?)```"#
        guard let regex = try? NSRegularExpression(pattern: htmlPattern, options: []),
              let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
              let codeRange = Range(match.range(at: 1), in: content) else {
            return nil
        }

        let code = String(content[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, code.contains("<") && code.contains(">") else { return nil }

        // Try to extract title from <title> tag or use default
        var title = "HTML Page"
        if let titleRegex = try? NSRegularExpression(pattern: #"<title>([^<]*)</title>"#, options: [.caseInsensitive]),
           let titleMatch = titleRegex.firstMatch(in: code, options: [], range: NSRange(code.startIndex..., in: code)),
           let titleRange = Range(titleMatch.range(at: 1), in: code) {
            title = String(code[titleRange])
        }

        return Artifact(type: .html, title: title, content: code, language: "html")
    }

    /// Detect SVG content
    private func detectSVGContent(in content: String) -> Artifact? {
        // Check for explicit SVG code block
        let svgPattern = #"```svg\s*\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: svgPattern, options: []),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           let codeRange = Range(match.range(at: 1), in: content) {
            let code = String(content[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !code.isEmpty && code.contains("<svg") {
                return Artifact(type: .svg, title: "SVG Graphic", content: code, language: "svg")
            }
        }

        // Also check for inline SVG in XML code blocks
        let xmlPattern = #"```xml\s*\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: xmlPattern, options: []),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           let codeRange = Range(match.range(at: 1), in: content) {
            let code = String(content[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !code.isEmpty && code.contains("<svg") {
                return Artifact(type: .svg, title: "SVG Graphic", content: code, language: "svg")
            }
        }

        return nil
    }

    /// Extract component name from React code
    private func extractComponentName(from code: String) -> String? {
        // Try to find function Name() { pattern
        if let regex = try? NSRegularExpression(pattern: #"function\s+([A-Z][a-zA-Z0-9]*)\s*\("#, options: []),
           let match = regex.firstMatch(in: code, options: [], range: NSRange(code.startIndex..., in: code)),
           let nameRange = Range(match.range(at: 1), in: code) {
            return String(code[nameRange])
        }

        // Try to find const Name = pattern
        if let regex = try? NSRegularExpression(pattern: #"const\s+([A-Z][a-zA-Z0-9]*)\s*="#, options: []),
           let match = regex.firstMatch(in: code, options: [], range: NSRange(code.startIndex..., in: code)),
           let nameRange = Range(match.range(at: 1), in: code) {
            return String(code[nameRange])
        }

        return nil
    }

    /// Format tool name for display: converts snake_case to Title Case
    private func formatToolName(_ name: String) -> String {
        return name
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
    
    /// Generate intelligible status message via LLM call
    private func generateStatusMessage(
        toolName: String,
        arguments: [String: Any],
        configuration: LLMConfiguration,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void
    ) async -> String {
        let formattedName = formatToolName(toolName)
        
        // Format arguments for prompt
        let argsString = arguments.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        
        let prompt = """
        Given this tool call:
        Tool: \(formattedName)
        Arguments: \(argsString.isEmpty ? "none" : argsString)
        
        Generate a single, clear, natural sentence (max 10 words) describing what this action is doing from the user's perspective.
        Examples:
        - "Looking up user information in the database"
        - "Searching the web for current weather data"
        - "Reading configuration file to understand system settings"
        
        Only return the sentence, nothing else.
        """
        
        // Quick LLM call with timeout
        do {
            let statusConfig = LLMConfiguration(
                provider: configuration.provider,
                model: configuration.model,
                temperature: 0.3, // Lower temperature for more consistent status messages
                maxTokens: 20,
                systemPrompt: nil,
                enableChainOfThought: false,
                enablePromptEnhancement: false
            )
            
            let statusAccumulator = StreamAccumulator()
            
            // Use withTimeout pattern - race between LLM call and timeout
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try await super.streamMessage(
                            prompt,
                            configuration: statusConfig,
                            conversationHistory: [],
                            onChunk: { chunk in
                                Task {
                                    await statusAccumulator.append(chunk)
                                }
                            },
                            onThinkingStatusUpdate: { _ in }
                        )
                    }
                    
                    group.addTask {
                        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second timeout
                        throw NSError(domain: "StatusGeneration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout"])
                    }
                    
                    _ = try await group.next()
                    group.cancelAll()
                }
                
                let trimmed = await statusAccumulator.current().trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && trimmed.count < 100 {
                    return trimmed
                }
            } catch {
                // Fall through to fallback - timeout or LLM error
            }
        }
        
        // Fallback: use formatted tool name
        return "Using \(formattedName)..."
    }

    private func executeToolCallsAndContinue(
        toolCalls: [[String: Any]],
        accumulatedContent: String,
        originalUserPrompt: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        tools: [[String: Any]],
        onChunk: @escaping @Sendable (String) -> Void,
        onThinkingStatusUpdate: @escaping @Sendable (String) -> Void,
        iteration: Int = 0,
        maxIterations: Int = 10,
        consecutiveErrors: Int = 0,
        maxConsecutiveErrors: Int = 3
    ) async throws {
        // Check stopping conditions
        guard iteration < maxIterations else {
            await AppLogger.shared.log("Maximum tool call iterations (\(maxIterations)) reached, stopping", level: .warning)
            onThinkingStatusUpdate("Stopped: Maximum iterations reached")
            onChunk("\n\n[Unable to complete task: Maximum tool call iterations reached. Please try a simpler request.]")
            return
        }
        
        guard consecutiveErrors < maxConsecutiveErrors else {
            await AppLogger.shared.log("Too many consecutive errors (\(consecutiveErrors)), stopping", level: .warning)
            onThinkingStatusUpdate("Stopped: Too many errors")
            onChunk("\n\n[Unable to complete task: Multiple tool call errors occurred. Please check your request and try again.]")
            return
        }
        await AppLogger.shared.log("Executing \(toolCalls.count) tool calls (iteration \(iteration + 1)) and continuing conversation", level: .info)
        guard let mcpManager = mcpManager else {
            await AppLogger.shared.log("MCP manager not available", level: .error)
            return
        }

        // Execute all tool calls in parallel where possible, but respect dependencies
        var toolResults: [[String: Any]] = []
        var currentConsecutiveErrors = consecutiveErrors
        
        // Parse all tool calls first
        let parsedCalls: [ParsedToolCall] = toolCalls.compactMap { toolCall in
            guard let function = toolCall["function"] as? [String: Any],
                  let name = function["name"] as? String,
                  let callId = toolCall["id"] as? String else {
                return nil
            }
            return ParsedToolCall(
                id: callId,
                name: name,
                arguments: function["arguments"] as? [String: Any] ?? [:]
            )
        }
        
        // Generate status messages for all tools sequentially (parallelization can be added later)
        // For now, generate them one at a time to avoid complexity
        var statusMessages: [String] = []
        for parsedCall in parsedCalls {
            let message = await generateStatusMessage(
                toolName: parsedCall.name,
                arguments: parsedCall.arguments,
                configuration: configuration,
                onThinkingStatusUpdate: { _ in }
            )
            statusMessages.append(message)
        }
        
        // Update status for first tool
        if let firstStatus = statusMessages.first {
            await MainActor.run {
                onThinkingStatusUpdate(firstStatus)
            }
        }
        
        // Get conversation ID for tool run persistence and tool execution
        let conversationId = conversationHistory.first?.conversationId ?? UUID()

        // Emit "started" events for all tool calls and create UUID mapping
        var toolCallIds: [Int: UUID] = [:]
        for (index, parsedCall) in parsedCalls.enumerated() {
            let toolId = UUID()
            toolCallIds[index] = toolId
            // Format input for display
            let inputDisplay: String
            if let data = try? JSONSerialization.data(withJSONObject: parsedCall.arguments, options: .prettyPrinted),
               let jsonString = String(data: data, encoding: .utf8) {
                inputDisplay = jsonString
            } else {
                inputDisplay = String(describing: parsedCall.arguments)
            }
            currentToolCallCallback?(.started(id: toolId, name: parsedCall.name, input: inputDisplay))
        }

        // Execute tool calls in parallel when possible (tools from different servers can run concurrently)
        // For now, execute all tools in parallel since they're typically independent
        let executionResults = await withTaskGroup(of: (index: Int, result: MCPToolResult, callId: String, name: String).self) { group in
            for (index, parsedCall) in parsedCalls.enumerated() {
                group.addTask {
                    await AppLogger.shared.log("Executing tool call: \(parsedCall.name) with ID: \(parsedCall.id)", level: .info)
                    let result = await mcpManager.callTool(toolName: parsedCall.name, arguments: parsedCall.arguments, conversationId: conversationId)
                    return (index, result, parsedCall.id, parsedCall.name)
                }
            }

            var results: [(index: Int, result: MCPToolResult, callId: String, name: String)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.index < $1.index }
        }

        // Process results and update status (batch MainActor calls)
        var finalToolResults: [[String: Any]] = []

        // Collect tool runs for batch save
        var toolRunsToSave: [ToolRun] = []

        for (index, execResult, callId, name) in executionResults {
            let resultText = execResult.content.compactMap { $0.text }.joined(separator: "\n")

            if execResult.isError {
                currentConsecutiveErrors += 1
                await AppLogger.shared.log("Tool \(name) returned error (length: \(resultText.count))", level: .warning)
            } else {
                if index == 0 {
                    currentConsecutiveErrors = 0 // Reset on first success
                }
                await AppLogger.shared.log("Tool \(name) executed successfully, result length: \(resultText.count)", level: .info)
            }

            // Emit "completed" event for live UI update
            if let toolId = toolCallIds[index] {
                currentToolCallCallback?(.completed(id: toolId, output: resultText, isError: execResult.isError))
            }

            // Get the parsed call for this index to access arguments
            let parsedCall = parsedCalls[index]

            // Find server info for this tool
            let toolInfo: MCPTool? = await MainActor.run { [weak mcpManager] in
                mcpManager?.availableTools.first { $0.name == name }
            }

            // Create tool run record for persistence
            let toolRun = ToolRun(
                conversationId: conversationId,
                messageId: nil, // Message ID not available at this point
                toolName: name,
                toolServerId: toolInfo?.serverId ?? (name == "web_search" || name == "execute_code" || name == "create_artifact" ? "builtin" : nil),
                toolServerName: toolInfo?.serverName ?? (name == "web_search" || name == "execute_code" || name == "create_artifact" ? "Vaizor Built-in" : nil),
                inputJson: {
                    if let data = try? JSONSerialization.data(withJSONObject: parsedCall.arguments),
                       let jsonString = String(data: data, encoding: .utf8) {
                        return jsonString
                    }
                    return nil
                }(),
                outputJson: resultText,
                isError: execResult.isError
            )
            toolRunsToSave.append(toolRun)

            // Check for artifact content and notify callback
            if name == "create_artifact" {
                for content in execResult.content {
                    if content.type == "artifact", let jsonText = content.text,
                       let data = jsonText.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let artifactType = json["artifact_type"] as? String,
                       let artifactTitle = json["artifact_title"] as? String,
                       let artifactContent = json["artifact_content"] as? String,
                       let type = ArtifactType(rawValue: artifactType) {
                        let artifact = Artifact(type: type, title: artifactTitle, content: artifactContent, language: artifactType)
                        await AppLogger.shared.log("Created artifact: \(artifactTitle) of type \(artifactType)", level: .info)
                        currentArtifactCallback?(artifact)
                    }
                }
            }

            finalToolResults.append([
                "tool_call_id": callId,
                "name": name,
                "content": resultText
            ])
        }
        
        toolResults = finalToolResults

        // Save tool runs to database (async, non-blocking)
        if !toolRunsToSave.isEmpty {
            Task {
                await toolRunRepository.saveToolRuns(toolRunsToSave)
                await AppLogger.shared.log("Saved \(toolRunsToSave.count) tool run(s) to database", level: .debug)
            }
        }

        // Batch all UI updates in a single MainActor call
        let toolNames = toolResults.compactMap { $0["name"] as? String }.map { formatToolName($0) }
        let finalStatusMessage: String
        if toolNames.count == 1 {
            finalStatusMessage = "Processing \(toolNames[0]) results..."
        } else if toolNames.count > 1 {
            finalStatusMessage = "Processing results from \(toolNames.joined(separator: ", "))..."
        } else {
            finalStatusMessage = "Processing tool results..."
        }
        
        await MainActor.run {
            onThinkingStatusUpdate(finalStatusMessage)
        }

        // Send tool results back to Ollama WITH the original user prompt so it can use them in its response
        await AppLogger.shared.log("Sending tool results back to Ollama with original prompt for continuation", level: .info)
        // Create a new request with the tool results as a tool message
        let baseURL = await getBaseURL()
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw NSError(domain: "MCPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama URL: \(baseURL)"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        await AppLogger.shared.log("Created continuation request to Ollama", level: .debug)

        var messages: [[String: Any]] = []

        if let systemPrompt = configuration.systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }

        // Include conversation history (excluding the last user message since we'll add it explicitly)
        // Properly handle all message types including tool messages from previous iterations
        for message in conversationHistory.dropLast() {
            var messageDict: [String: Any] = [
                "content": message.content
            ]
            
            switch message.role {
            case .user:
                messageDict["role"] = "user"
            case .assistant:
                messageDict["role"] = "assistant"
            case .tool:
                messageDict["role"] = "tool"
                // Preserve tool_call_id and name if available
                if let toolCallId = message.toolCallId {
                    messageDict["tool_call_id"] = toolCallId
                }
                if let toolName = message.toolName {
                    messageDict["name"] = toolName
                }
            case .system:
                messageDict["role"] = "system"
            }
            
            messages.append(messageDict)
        }

        // Add the original user prompt explicitly
        messages.append([
            "role": "user",
            "content": originalUserPrompt
        ])

        // Add the assistant message with tool calls
        messages.append([
            "role": "assistant",
            "content": accumulatedContent,
            "tool_calls": toolCalls
        ])

        // Add tool results as tool messages (Ollama expects these in a specific format)
        for result in toolResults {
            if let toolCallId = result["tool_call_id"] as? String {
                messages.append([
                    "role": "tool",
                    "content": result["content"] as? String ?? "",
                    "name": result["name"] as? String ?? "",
                    "tool_call_id": toolCallId
                ])
            }
        }
        
        await AppLogger.shared.log("Message sequence: \(messages.count) messages (user prompt + assistant with tools + \(toolResults.count) tool results)", level: .debug)

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "stream": true,
            "tools": tools, // Keep tools available for additional calls
            "options": [
                "temperature": configuration.temperature,
                "num_predict": configuration.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Use concurrent URLSession configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpMaximumConnectionsPerHost = 10
        sessionConfig.timeoutIntervalForRequest = 300
        sessionConfig.timeoutIntervalForResource = 600
        let session = URLSession(configuration: sessionConfig)
        
        // Add timeout to prevent hanging
        do {
            let requestToSend = request
            let (asyncBytes, response) = try await withThrowingTaskGroup(of: (URLSession.AsyncBytes, URLResponse).self) { group in
                group.addTask {
                    try await session.bytes(for: requestToSend)
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                    throw NSError(domain: "OllamaProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out after 60 seconds"])
                }
                
                guard let result = try await group.next() else {
                    throw NSError(domain: "OllamaProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request failed"])
                }
                
                group.cancelAll()
                return result
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let errorMsg = "Failed to continue conversation with Ollama (status: \((response as? HTTPURLResponse)?.statusCode ?? -1))"
                await AppLogger.shared.log(errorMsg, level: .error)
                onChunk("\n\n[Error: \(errorMsg)]")
                return
            }

            // Stream the LLM's response and check for additional tool calls
            var newToolCalls: [[String: Any]] = []
            var newAccumulatedContent = ""
            
            for try await line in asyncBytes.lines {
                let lineString = String(line)
                guard !lineString.isEmpty else { continue }

                if let data = lineString.data(using: String.Encoding.utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    // Check for additional tool calls
                    if let messageContent = json["message"] as? [String: Any],
                       let calls = messageContent["tool_calls"] as? [[String: Any]] {
                        newToolCalls.append(contentsOf: calls)
                    }
                    
                    // Stream regular content
                    if let messageContent = json["message"] as? [String: Any],
                       let content = messageContent["content"] as? String, !content.isEmpty {
                        newAccumulatedContent += content
                        onChunk(content)
                    }
                }
            }
            
            // If LLM wants to make more tool calls, execute them recursively
            if !newToolCalls.isEmpty {
                await AppLogger.shared.log("LLM requested \(newToolCalls.count) additional tool call(s) in iteration \(iteration + 1)", level: .info)
                
                // Build updated conversation history with tool results
                let conversationId = conversationHistory.first?.conversationId ?? UUID()
                var updatedHistory = conversationHistory
                
                // Add assistant message with accumulated content
                updatedHistory.append(Message(
                    conversationId: conversationId,
                    role: .assistant,
                    content: accumulatedContent
                ))
                
                // Add tool result messages to history with metadata preserved
                for result in toolResults {
                    if let content = result["content"] as? String {
                        let toolCallId = result["tool_call_id"] as? String
                        let toolName = result["name"] as? String
                        updatedHistory.append(Message(
                            conversationId: conversationId,
                            role: .tool,
                            content: content,
                            toolCallId: toolCallId,
                            toolName: toolName
                        ))
                    }
                }
                
                // Recursively execute the new tool calls
                try await executeToolCallsAndContinue(
                    toolCalls: newToolCalls,
                    accumulatedContent: newAccumulatedContent,
                    originalUserPrompt: originalUserPrompt,
                    configuration: configuration,
                    conversationHistory: updatedHistory,
                    tools: tools,
                    onChunk: onChunk,
                    onThinkingStatusUpdate: onThinkingStatusUpdate,
                    iteration: iteration + 1,
                    maxIterations: maxIterations,
                    consecutiveErrors: currentConsecutiveErrors,
                    maxConsecutiveErrors: maxConsecutiveErrors
                )
            } else {
                await AppLogger.shared.log("No additional tool calls requested, conversation complete after \(iteration + 1) iteration(s)", level: .info)
                await MainActor.run {
                    onThinkingStatusUpdate("Formulating final response...")
                }
            }
        } catch {
            await AppLogger.shared.logError(error, context: "Failed to continue conversation after tool execution")
            onChunk("\n\n[Error: Failed to get response from LLM after tool execution. \(error.localizedDescription)]")
        }
    }
}
