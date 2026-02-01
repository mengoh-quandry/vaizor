import SwiftUI

// Dark theme colors for MCP views
private let mcpDarkBase = Color(hex: "1c1d1f")
private let mcpDarkSurface = Color(hex: "232426")
private let mcpDarkBorder = Color(hex: "2d2e30")
private let mcpTextPrimary = Color.white
private let mcpTextSecondary = Color(hex: "808080")
private let mcpAccent = Color(hex: "00976d")
private let mcpInfo = Color(hex: "5a9bd5")

struct MCPSettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @Environment(\.dismiss) var dismiss
    @State private var showAddServer = false
    @State private var showDiscoverServers = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                MCPIconManager.icon()
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text("MCP Servers")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(mcpTextPrimary)

                Spacer()

                Button {
                    showDiscoverServers = true
                } label: {
                    Label("Discover", systemImage: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(mcpAccent)

                Button {
                    showAddServer = true
                } label: {
                    Label("Add Server", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(mcpAccent)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(mcpTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(mcpDarkBase)

            Rectangle().fill(mcpDarkBorder).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Info box
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(mcpInfo)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model Context Protocol (MCP)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(mcpTextPrimary)

                            Text("MCP servers extend your AI's capabilities with tools, resources, and prompts. Add servers below to enable features like file system access, web search, database queries, and more.")
                                .font(.system(size: 12))
                                .foregroundStyle(mcpTextSecondary)
                        }
                    }
                    .padding()
                    .background(mcpInfo.opacity(0.12))
                    .cornerRadius(12)

                    // Server list
                    if container.mcpManager.availableServers.isEmpty {
                        VStack(spacing: 16) {
                            MCPIconManager.icon()
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text("No MCP Servers")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(mcpTextPrimary)

                            Text("Add your first MCP server to extend Ollama's capabilities")
                                .font(.system(size: 13))
                                .foregroundStyle(mcpTextSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 300)

                            Button {
                                showAddServer = true
                            } label: {
                                Label("Add MCP Server", systemImage: "plus")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(mcpAccent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(container.mcpManager.availableServers) { server in
                                MCPServerRow(server: server)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(mcpDarkBase)
        }
        .frame(minWidth: 650, idealWidth: 750, maxWidth: 900, minHeight: 500, idealHeight: 600, maxHeight: 800)
        .background(mcpDarkBase)
        .sheet(isPresented: $showAddServer) {
            AddMCPServerView()
                .environmentObject(container)
        }
        .sheet(isPresented: $showDiscoverServers) {
            MCPDiscoveryView()
                .environmentObject(container)
        }
    }
}

struct MCPServerRow: View {
    let server: MCPServer
    @EnvironmentObject var container: DependencyContainer
    @State private var showDetails = false
    @State private var showEdit = false
    @State private var isTestingConnection = false
    @State private var connectionStatus: String = ""
    @State private var connectionSuccess: Bool?
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Error display
            if let error = container.mcpManager.serverErrors[server.id] {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        container.mcpManager.clearError(for: server.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color(hex: "d4a017").opacity(0.12))
                .cornerRadius(6)
            }

            // Toast notification
            if showToast {
                ToastView(message: toastMessage, isPresented: $showToast)
                    .padding(.bottom, 4)
            }

            HStack(alignment: .center, spacing: 12) {
                // Status indicator and name
                HStack(spacing: 8) {
                    Circle()
                        .fill(isRunning ? mcpAccent : (container.mcpManager.serverErrors[server.id] != nil ? Color(hex: "d4a017") : mcpTextSecondary))
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name)
                            .font(.headline)
                            .lineLimit(1)

                        if !server.description.isEmpty {
                            Text(server.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Enable/Disable toggle - prominently displayed
                MCPPowerButton(
                    isEnabled: isRunning,
                    onToggle: { enabled in
                        if enabled {
                            Task {
                                do {
                                    AppLogger.shared.log("User toggled MCP server \(server.name) ON", level: .info)
                                    try await container.mcpManager.startServer(server)
                                    // State will update automatically via @Published (errors cleared on success)
                                } catch {
                                    AppLogger.shared.logError(error, context: "User failed to start MCP server \(server.name)")
                                    // Error is stored in serverErrors and state is cleaned up automatically
                                }
                            }
                        } else {
                            AppLogger.shared.log("User toggled MCP server \(server.name) OFF", level: .info)
                            container.mcpManager.stopServer(server)
                            // State will update automatically via @Published
                        }
                    }
                )
                .help(isRunning ? "Disable Server" : "Enable Server")

                // Action menu for edit/delete
                Menu {
                    Button {
                        NotificationCenter.default.post(
                            name: .showUnderConstructionToast,
                            object: "Edit Server"
                        )
                        // Keep the sheet for now, but show toast
                        showEdit = true
                    } label: {
                        Label("Edit Server", systemImage: "pencil")
                    }

                    Button {
                        showDetails.toggle()
                    } label: {
                        Label(showDetails ? "Hide Details" : "Show Details", systemImage: showDetails ? "chevron.up" : "chevron.down")
                    }

                    Divider()

                    Button(role: .destructive) {
                        container.mcpManager.removeServer(server)
                    } label: {
                        Label("Delete Server", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Server Options")
            }

            if showDetails {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    DetailRow(label: "Command", value: server.command)

                    if !server.args.isEmpty {
                        DetailRow(label: "Arguments", value: server.args.joined(separator: " "))
                    }

                    DetailRow(label: "Status", value: isRunning ? "Running" : "Stopped")

                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            testConnection()
                        } label: {
                            HStack(spacing: 6) {
                                if isTestingConnection {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                } else {
                                    Image(systemName: "network")
                                }
                                Text("Test Connection")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTestingConnection)

                        if let success = connectionSuccess {
                            HStack(spacing: 4) {
                                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(success ? .green : .red)
                                    .font(.caption)

                                Text(connectionStatus)
                                    .font(.caption2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(14)
        .background(mcpDarkSurface)
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showEdit) {
            EditMCPServerView(server: server)
                .environmentObject(container)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showUnderConstructionToast)) { notification in
            if let featureName = notification.object as? String {
                toastMessage = "\(featureName) is under construction"
                withAnimation {
                    showToast = true
                }
            }
        }
    }

    private var isRunning: Bool {
        container.mcpManager.enabledServers.contains(server.id)
    }

    private func testConnection() {
        isTestingConnection = true
        connectionSuccess = nil
        connectionStatus = ""

        Task {
            let (success, message) = await container.mcpManager.testConnection(server)
            await MainActor.run {
                isTestingConnection = false
                connectionSuccess = success
                connectionStatus = message
                
                // Auto-enable server if test connection succeeds
                if success && !container.mcpManager.enabledServers.contains(server.id) {
                    Task {
                        do {
                            AppLogger.shared.log("Auto-enabling MCP server \(server.name) after successful test connection", level: .info)
                            try await container.mcpManager.startServer(server)
                            // State updates automatically via @Published enabledServers
                        } catch {
                            AppLogger.shared.logError(error, context: "Failed to auto-enable MCP server \(server.name) after test")
                        }
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label + ":")
                .foregroundStyle(.secondary)
                .font(.caption)
                .fontWeight(.medium)

            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AddMCPServerView: View {
    @EnvironmentObject var container: DependencyContainer
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var command = ""
    @State private var args = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(mcpAccent)

                Text("Add MCP Server")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(mcpTextPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(mcpTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(mcpDarkBase)

            Rectangle().fill(mcpDarkBorder).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MCPFormField(label: "Server Name", placeholder: "e.g., filesystem, weather, database", text: $name)
                    MCPFormField(label: "Description (Optional)", placeholder: "Brief description of what this server does", text: $description)
                    MCPFormField(label: "Command", placeholder: "e.g., npx, node, python3", text: $command, hint: "The executable to run (must be in PATH or use full path)")
                    MCPFormField(label: "Arguments (Optional)", placeholder: "e.g., -m mcp_server_name", text: $args, hint: "Space-separated arguments to pass to the command")

                    // Example
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Example Configuration")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(mcpTextPrimary)

                        VStack(alignment: .leading, spacing: 4) {
                            ExampleField(label: "Name", value: "filesystem")
                            ExampleField(label: "Description", value: "Access and manage local files")
                            ExampleField(label: "Command", value: "npx")
                            ExampleField(label: "Arguments", value: "-y @modelcontextprotocol/server-filesystem /Users/username/Documents")
                        }
                        .padding(12)
                        .background(mcpDarkSurface)
                        .cornerRadius(8)
                    }

                    if showError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color(hex: "d4a017"))
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundStyle(mcpTextPrimary)
                        }
                        .padding(8)
                        .background(Color(hex: "d4a017").opacity(0.12))
                        .cornerRadius(8)
                    }

                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .foregroundStyle(mcpTextSecondary)

                        Spacer()

                        Button {
                            addServer()
                        } label: {
                            Text("Add Server")
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(mcpAccent)
                        .disabled(name.isEmpty || command.isEmpty)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(mcpDarkBase)
        }
        .frame(minWidth: 550, idealWidth: 650, maxWidth: 800, minHeight: 550, idealHeight: 650, maxHeight: 750)
        .background(mcpDarkBase)
    }

    private func addServer() {
        guard !name.isEmpty, !command.isEmpty else {
            errorMessage = "Name and command are required"
            showError = true
            return
        }

        let arguments = args.isEmpty ? [] : args.split(separator: " ").map(String.init)

        let server = MCPServer(
            id: UUID().uuidString,
            name: name,
            description: description,
            command: command,
            args: arguments,
            path: URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path)
        )

        container.mcpManager.addServer(server)
        dismiss()
    }
}

struct ExampleField: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.system(size: 11))
                .foregroundStyle(mcpTextSecondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(mcpTextPrimary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - MCP Form Field

struct MCPFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var hint: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(mcpTextPrimary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(10)
                .background(mcpDarkSurface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(mcpDarkBorder, lineWidth: 1)
                )

            if let hint = hint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(mcpTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct EditMCPServerView: View {
    @EnvironmentObject var container: DependencyContainer
    @Environment(\.dismiss) var dismiss

    let server: MCPServer

    @State private var name: String
    @State private var description: String
    @State private var command: String
    @State private var args: String

    init(server: MCPServer) {
        self.server = server
        _name = State(initialValue: server.name)
        _description = State(initialValue: server.description)
        _command = State(initialValue: server.command)
        _args = State(initialValue: server.args.joined(separator: " "))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(mcpAccent)

                Text("Edit MCP Server")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(mcpTextPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(mcpTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(mcpDarkBase)

            Rectangle().fill(mcpDarkBorder).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MCPFormField(label: "Server Name", placeholder: "e.g., filesystem, weather, database", text: $name)
                    MCPFormField(label: "Description (Optional)", placeholder: "Brief description of what this server does", text: $description)
                    MCPFormField(label: "Command", placeholder: "e.g., npx, node, python3", text: $command)
                    MCPFormField(label: "Arguments (Optional)", placeholder: "e.g., -m mcp_server_name", text: $args)

                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .foregroundStyle(mcpTextSecondary)

                        Spacer()

                        Button {
                            saveChanges()
                        } label: {
                            Text("Save Changes")
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(mcpAccent)
                        .disabled(name.isEmpty || command.isEmpty)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(mcpDarkBase)
        }
        .frame(minWidth: 550, idealWidth: 650, maxWidth: 800, minHeight: 450, idealHeight: 550, maxHeight: 700)
        .background(mcpDarkBase)
    }

    private func saveChanges() {
        let arguments = args.isEmpty ? [] : args.split(separator: " ").map(String.init)

        let updatedServer = MCPServer(
            id: server.id,
            name: name,
            description: description,
            command: command,
            args: arguments,
            path: server.path
        )

        container.mcpManager.updateServer(updatedServer)
        dismiss()
    }
}
