import SwiftUI

// Reuse dark theme colors
private let discoverDarkBase = Color(hex: "1c1d1f")
private let discoverDarkSurface = Color(hex: "232426")
private let discoverDarkBorder = Color(hex: "2d2e30")
private let discoverTextPrimary = Color.white
private let discoverTextSecondary = Color(hex: "808080")
private let discoverAccent = Color(hex: "00976d")
private let discoverInfo = Color(hex: "5a9bd5")

struct MCPDiscoveryView: View {
    @EnvironmentObject var container: DependencyContainer
    @Environment(\.dismiss) var dismiss

    @State private var discoveredServers: [DiscoveredServer] = []
    @State private var selectedServers: Set<String> = []
    @State private var isScanning = true
    @State private var expandedGroups: Set<String> = []
    @State private var isImporting = false

    private let discoveryService = MCPDiscoveryService()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Rectangle().fill(discoverDarkBorder).frame(height: 1)

            // Content
            if isScanning {
                scanningView
            } else if discoveredServers.isEmpty {
                emptyStateView
            } else {
                serverListView
            }

            Rectangle().fill(discoverDarkBorder).frame(height: 1)

            // Footer
            footerView
        }
        .frame(width: 550, height: 500)
        .background(discoverDarkBase)
        .task {
            await scanForServers()
            // Auto-expand all groups after scan completes
            await MainActor.run {
                for group in discoveredServers.groupedBySource() {
                    expandedGroups.insert(group.id)
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(discoverAccent)

            Text("Discover MCP Servers")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(discoverTextPrimary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(discoverTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(discoverDarkBase)
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(discoverAccent)

            Text("Scanning for MCP servers...")
                .font(.system(size: 14))
                .foregroundStyle(discoverTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(discoverTextSecondary.opacity(0.5))

            Text("No MCP Servers Found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(discoverTextPrimary)

            Text("We scanned Claude Desktop, Cursor, VS Code, and Claude Code but didn't find any configured MCP servers.")
                .font(.system(size: 13))
                .foregroundStyle(discoverTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)

            Button {
                Task { await scanForServers() }
            } label: {
                Label("Scan Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .tint(discoverAccent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Server List

    private var serverListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary bar
            HStack {
                Text("Found \(discoveredServers.count) server\(discoveredServers.count == 1 ? "" : "s") from \(groupedServers.count) source\(groupedServers.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundStyle(discoverTextSecondary)

                Spacer()

                Button("Select All") {
                    selectAll()
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(discoverAccent)

                Text("·")
                    .foregroundStyle(discoverTextSecondary)

                Button("Select None") {
                    selectedServers.removeAll()
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(discoverAccent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(discoverDarkSurface)

            Rectangle().fill(discoverDarkBorder).frame(height: 1)

            // Grouped server list
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedServers) { group in
                        Section {
                            ForEach(group.servers) { server in
                                serverRow(server)
                                if server.id != group.servers.last?.id {
                                    Rectangle().fill(discoverDarkBorder.opacity(0.5)).frame(height: 1)
                                        .padding(.leading, 48)
                                }
                            }
                        } header: {
                            groupHeader(group)
                        }
                    }
                }
            }
        }
    }

    private func groupHeader(_ group: DiscoveredServerGroup) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedGroups.contains(group.id) {
                    expandedGroups.remove(group.id)
                } else {
                    expandedGroups.insert(group.id)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: expandedGroups.contains(group.id) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(discoverTextSecondary)
                    .frame(width: 12)

                Image(systemName: group.source.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(discoverAccent)

                Text(group.source.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(discoverTextPrimary)

                Text("(\(group.servers.count))")
                    .font(.system(size: 12))
                    .foregroundStyle(discoverTextSecondary)

                if group.importableCount < group.servers.count {
                    Text("\(group.servers.count - group.importableCount) already added")
                        .font(.system(size: 11))
                        .foregroundStyle(discoverTextSecondary.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(discoverDarkBorder)
                        .cornerRadius(4)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(discoverDarkSurface)
        }
        .buttonStyle(.plain)
    }

    private func serverRow(_ server: DiscoveredServer) -> some View {
        let isSelected = selectedServers.contains(server.id)
        let isDisabled = server.isAlreadyImported

        return Button {
            if !isDisabled {
                if isSelected {
                    selectedServers.remove(server.id)
                } else {
                    selectedServers.insert(server.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundStyle(isDisabled ? discoverTextSecondary.opacity(0.3) : (isSelected ? discoverAccent : discoverTextSecondary))
                    .frame(width: 20)

                // Runtime icon
                Image(systemName: server.runtime.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isDisabled ? discoverTextSecondary.opacity(0.5) : discoverInfo)
                    .frame(width: 20)

                // Server info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(server.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isDisabled ? discoverTextSecondary.opacity(0.5) : discoverTextPrimary)

                        if server.isAlreadyImported {
                            Text("Already added")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(discoverTextSecondary.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(discoverDarkBorder)
                                .cornerRadius(4)
                        }

                        if server.securityWarning != nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                                .help(server.securityWarning ?? "Security warning")
                        }
                    }

                    Text(server.runtime.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(isDisabled ? discoverTextSecondary.opacity(0.3) : discoverTextSecondary)
                }

                Spacer()

                // Environment indicator
                if let env = server.env, !env.isEmpty {
                    Image(systemName: "gearshape.2")
                        .font(.system(size: 11))
                        .foregroundStyle(discoverTextSecondary.opacity(0.6))
                        .help("\(env.count) environment variable\(env.count == 1 ? "" : "s")")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected && !isDisabled ? discoverAccent.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if !discoveredServers.isEmpty {
                let importableSelected = selectedServers.filter { id in
                    discoveredServers.first { $0.id == id }?.isAlreadyImported == false
                }.count

                Text("\(importableSelected) selected")
                    .font(.system(size: 12))
                    .foregroundStyle(discoverTextSecondary)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Button {
                Task { await importSelectedServers() }
            } label: {
                if isImporting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                } else {
                    Text("Import Selected")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(discoverAccent)
            .disabled(selectedServers.isEmpty || isImporting)
        }
        .padding()
        .background(discoverDarkBase)
    }

    // MARK: - Computed Properties

    private var groupedServers: [DiscoveredServerGroup] {
        let groups = discoveredServers.groupedBySource()
        // Filter servers based on expansion state - do NOT mutate state here
        return groups.map { group in
            // Show servers only if group is expanded (all groups start expanded by default via onAppear)
            let isExpanded = expandedGroups.contains(group.id)
            if isExpanded {
                return group
            } else {
                return DiscoveredServerGroup(source: group.source, servers: [], isExpanded: false)
            }
        }
    }

    // MARK: - Actions

    private func scanForServers() async {
        isScanning = true
        let existing = container.mcpManager.availableServers
        discoveredServers = await discoveryService.discoverServers(existingServers: existing)
        isScanning = false
    }

    private func selectAll() {
        for server in discoveredServers where !server.isAlreadyImported {
            selectedServers.insert(server.id)
        }
    }

    private func importSelectedServers() async {
        isImporting = true

        let serversToImport = discoveredServers.filter { selectedServers.contains($0.id) && !$0.isAlreadyImported }

        for discovered in serversToImport {
            let mcpServer = discoveryService.importServer(discovered)
            container.mcpManager.addServer(mcpServer)
        }

        isImporting = false
        dismiss()
    }
}

#Preview {
    MCPDiscoveryView()
        .environmentObject(DependencyContainer())
}
