import SwiftUI

struct MCPSettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @Environment(\.dismiss) var dismiss
    @State private var showAddServer = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(.blue)

                Text("MCP Servers")
                    .font(.headline)

                Spacer()

                Button {
                    showAddServer = true
                } label: {
                    Label("Add Server", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Info box
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model Context Protocol (MCP)")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("MCP servers extend your AI's capabilities with tools, resources, and prompts. Add servers below to enable features like file system access, web search, database queries, and more.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    // Server list
                    if container.mcpManager.availableServers.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)

                            Text("No MCP Servers")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text("Add your first MCP server to extend Ollama's capabilities")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 300)

                            Button {
                                showAddServer = true
                            } label: {
                                Label("Add MCP Server", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
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
        }
        .frame(width: 700, height: 500)
        .sheet(isPresented: $showAddServer) {
            AddMCPServerView()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isRunning ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)

                        Text(server.name)
                            .font(.headline)
                    }

                    if !server.description.isEmpty {
                        Text(server.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        showDetails.toggle()
                    } label: {
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showEdit = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Edit Server")

                    Toggle("", isOn: Binding(
                        get: { container.mcpManager.enabledServers.contains(server.id) },
                        set: { enabled in
                            if enabled {
                                Task {
                                    try? await container.mcpManager.startServer(server)
                                }
                            } else {
                                container.mcpManager.stopServer(server)
                            }
                        }
                    ))

                    Button {
                        container.mcpManager.removeServer(server)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showDetails {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(label: "Command", value: server.command)

                    if !server.args.isEmpty {
                        DetailRow(label: "Arguments", value: server.args.joined(separator: " "))
                    }

                    DetailRow(label: "Status", value: isRunning ? "Running" : "Stopped")

                    HStack {
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

                                Text(connectionStatus)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .font(.caption)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .sheet(isPresented: $showEdit) {
            EditMCPServerView(server: server)
                .environmentObject(container)
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
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .textSelection(.enabled)
        }
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
                    .foregroundStyle(.blue)

                Text("Add MCP Server")
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server Name")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("e.g., filesystem, weather, database", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("Brief description of what this server does", text: $description)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Command")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("e.g., npx, node, python3", text: $command)
                            .textFieldStyle(.roundedBorder)

                        Text("The executable to run (must be in PATH or use full path)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Arguments (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("e.g., -m mcp_server_name", text: $args)
                            .textFieldStyle(.roundedBorder)

                        Text("Space-separated arguments to pass to the command")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Example
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Example Configuration")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 4) {
                            ExampleField(label: "Name", value: "filesystem")
                            ExampleField(label: "Description", value: "Access and manage local files")
                            ExampleField(label: "Command", value: "npx")
                            ExampleField(label: "Arguments", value: "-y @modelcontextprotocol/server-filesystem /Users/username/Documents")
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }

                    if showError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(errorMessage)
                                .font(.caption)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Add Server") {
                            addServer()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(name.isEmpty || command.isEmpty)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 600, height: 600)
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
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.caption)
                .textSelection(.enabled)
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
                    .foregroundStyle(.blue)

                Text("Edit MCP Server")
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server Name")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("e.g., filesystem, weather, database", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("Brief description of what this server does", text: $description)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Command")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("e.g., npx, node, python3", text: $command)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Arguments (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("e.g., -m mcp_server_name", text: $args)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Save Changes") {
                            saveChanges()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(name.isEmpty || command.isEmpty)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 600, height: 500)
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
