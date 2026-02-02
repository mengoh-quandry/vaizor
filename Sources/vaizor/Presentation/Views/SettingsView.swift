import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @Environment(\.dismiss) var dismiss

    @State private var anthropicKey: String = ""
    @State private var openaiKey: String = ""
    @State private var geminiKey: String = ""
    @State private var customKey: String = ""
    @State private var showMCPSettings = false
    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.blue)

                Text("Settings")
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
                VStack(alignment: .leading, spacing: 24) {
                    // API Keys Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("API Keys")
                            .font(.title2)
                            .fontWeight(.semibold)

                        // Anthropic
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Anthropic Claude", systemImage: "sparkles")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            SecureField("Enter API key", text: $anthropicKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: anthropicKey) { _, newValue in
                                    container.apiKeys[.anthropic] = newValue
                                }
                        }

                        // OpenAI
                        VStack(alignment: .leading, spacing: 8) {
                            Label("OpenAI", systemImage: "brain")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            SecureField("Enter API key", text: $openaiKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: openaiKey) { _, newValue in
                                    container.apiKeys[.openai] = newValue
                                }
                        }

                        // Google Gemini
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Google Gemini", systemImage: "globe")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            SecureField("Enter API key", text: $geminiKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: geminiKey) { _, newValue in
                                    container.apiKeys[.gemini] = newValue
                                }
                        }

                        // Custom Provider
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Custom Provider", systemImage: "server.rack")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            SecureField("Enter API key", text: $customKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: customKey) { _, newValue in
                                    container.apiKeys[.custom] = newValue
                                }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)

                    // Ollama Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ollama Settings")
                            .font(.title2)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Default Model", systemImage: "circle.grid.3x3.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Menu {
                                ForEach(container.availableModels, id: \.self) { model in
                                    Button {
                                        defaultOllamaModel = model
                                    } label: {
                                        HStack {
                                            Text(model)
                                            if model == defaultOllamaModel {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(defaultOllamaModel.isEmpty ? "Select a model" : defaultOllamaModel)
                                        .foregroundStyle(defaultOllamaModel.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Text("Ollama runs locally and doesn't require an API key")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)

                    // MCP Servers Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("MCP Servers")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Spacer()

                            Button {
                                showMCPSettings = true
                            } label: {
                                Label("Manage Servers", systemImage: "gearshape")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if container.mcpManager.availableServers.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)

                                Text("No MCP servers configured")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text("Add MCP servers to extend Ollama's capabilities")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)

                                Button {
                                    showMCPSettings = true
                                } label: {
                                    Label("Add MCP Server", systemImage: "plus")
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(container.mcpManager.availableServers.prefix(3)) { server in
                                    HStack {
                                        Circle()
                                            .fill(container.mcpManager.enabledServers.contains(server.id) ? Color.green : Color.gray)
                                            .frame(width: 8, height: 8)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(server.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)

                                            if !server.description.isEmpty {
                                                Text(server.description)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }

                                if container.mcpManager.availableServers.count > 3 {
                                    Text("+ \(container.mcpManager.availableServers.count - 3) more")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)

                    // About Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.title2)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Version")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("1.0.0")
                            }

                            Divider()

                            HStack {
                                Text("Provider")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Vaizor")
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                }
                .padding(20)
            }
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showMCPSettings) {
            MCPSettingsView()
                .environmentObject(container)
        }
        .onAppear {
            // Load saved keys
            anthropicKey = container.apiKeys[.anthropic] ?? ""
            openaiKey = container.apiKeys[.openai] ?? ""
            geminiKey = container.apiKeys[.gemini] ?? ""
            customKey = container.apiKeys[.custom] ?? ""

            // Load Ollama models
            if container.currentProvider == .ollama {
                Task {
                    await container.loadModelsForCurrentProvider()
                }
            }
        }
    }
}
