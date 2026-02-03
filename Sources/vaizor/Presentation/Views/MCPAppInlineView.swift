import SwiftUI

// MARK: - Inline MCP App View (for embedding in messages)

/// Compact view for displaying MCP Apps inline within chat messages
struct MCPAppInlineView: View {
    let appContent: MCPAppContent
    let onExpand: () -> Void
    let onClose: () -> Void

    @State private var isLoading = true
    @State private var error: String?
    @State private var isExpanded = false
    @ObservedObject private var appManager = MCPAppManager.shared

    private let darkSurface = ThemeColors.darkSurface
    private let darkBorder = ThemeColors.darkBorder
    private let accent = ThemeColors.accent
    private let textSecondary = ThemeColors.textSecondary

    var body: some View {
        VStack(spacing: 0) {
            // Compact header
            header

            // Content (collapsed or expanded)
            if isExpanded {
                Divider()
                    .background(darkBorder)

                MCPAppWebView(
                    content: appContent,
                    isLoading: $isLoading,
                    error: $error,
                    contentHeight: .constant(300),
                    onAction: handleAction
                )
                .frame(height: 250)
            }
        }
        .background(darkSurface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(darkBorder, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            // MCP App indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)

                MCPIconManager.icon()
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }

            // Title
            VStack(alignment: .leading, spacing: 1) {
                Text(appContent.title ?? "MCP App")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("from \(appContent.serverName)")
                    .font(.system(size: 9))
                    .foregroundStyle(textSecondary)
            }

            Spacer()

            // Security badge
            HStack(spacing: 3) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 8))

                Text("Sandboxed")
                    .font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(accent.opacity(0.1))
            .cornerRadius(3)

            // Expand/Collapse toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(textSecondary)
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)

            // Open in panel button
            Button {
                onExpand()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(textSecondary)
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help("Open in panel")

            // Close button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(textSecondary)
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func handleAction(_ action: MCPAppAction) async -> MCPAppResponse {
        return await appManager.handleAction(action, from: appContent.id)
    }
}

// MARK: - MCP App Panel Wrapper

/// Full panel view for MCP Apps (shown in artifact panel area)
struct MCPAppPanelWrapper: View {
    let appContent: MCPAppContent
    let onClose: () -> Void

    @ObservedObject private var appManager = MCPAppManager.shared

    var body: some View {
        MCPAppView(
            appContent: appContent,
            displayMode: .panel,
            onAction: { action in
                await appManager.handleAction(action, from: appContent.id)
            },
            onClose: onClose
        )
    }
}

// MARK: - MCP App Floating Window

/// Opens MCP App in a floating window
struct MCPAppFloatingWindow: View {
    let appContent: MCPAppContent

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appManager = MCPAppManager.shared

    var body: some View {
        MCPAppView(
            appContent: appContent,
            displayMode: .floating,
            onAction: { action in
                await appManager.handleAction(action, from: appContent.id)
            },
            onClose: { dismiss() }
        )
        .frame(minWidth: 450, idealWidth: 600, minHeight: 400, idealHeight: 500)
    }
}

// MARK: - Active MCP Apps List View

/// Shows all currently active MCP Apps
struct ActiveMCPAppsView: View {
    @ObservedObject private var appManager = MCPAppManager.shared
    @State private var selectedAppId: UUID?

    private let darkBase = ThemeColors.darkBase
    private let darkSurface = ThemeColors.darkSurface
    private let accent = ThemeColors.accent
    private let textSecondary = ThemeColors.textSecondary

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "apps.iphone")
                    .foregroundStyle(accent)

                Text("Active MCP Apps")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Text("\(appManager.activeApps.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accent)
                    .cornerRadius(10)
            }
            .padding(12)

            Divider()

            if appManager.activeApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "apps.iphone")
                        .font(.system(size: 32))
                        .foregroundStyle(textSecondary.opacity(0.5))

                    Text("No active apps")
                        .font(.system(size: 13))
                        .foregroundStyle(textSecondary)

                    Text("MCP servers can display interactive apps here")
                        .font(.system(size: 11))
                        .foregroundStyle(textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(appManager.activeApps.values), id: \.id) { app in
                            AppListRow(
                                app: app,
                                isSelected: selectedAppId == app.id,
                                onSelect: { selectedAppId = app.id },
                                onClose: { appManager.unregisterApp(app.id) }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(darkBase)
    }
}

struct AppListRow: View {
    let app: MCPAppContent
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    private let darkSurface = ThemeColors.darkSurface
    private let accent = ThemeColors.accent
    private let textSecondary = ThemeColors.textSecondary

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 10) {
                // Status indicator
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)

                // App info
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.title ?? "MCP App")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)

                    Text(app.serverName)
                        .font(.system(size: 10))
                        .foregroundStyle(textSecondary)
                }

                Spacer()

                // Display mode badge
                Text(app.metadata?.displayMode?.rawValue ?? "panel")
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .foregroundStyle(textSecondary)
                    .cornerRadius(4)

                // Close button
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(isSelected ? accent.opacity(0.15) : darkSurface)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        MCPAppInlineView(
            appContent: MCPAppContent(
                serverId: "demo-server",
                serverName: "Demo MCP Server",
                html: "<h1>Demo App</h1><p>Interactive content here</p>",
                title: "Interactive Demo"
            ),
            onExpand: {},
            onClose: {}
        )
        .frame(width: 400)

        ActiveMCPAppsView()
            .frame(width: 300, height: 300)
    }
    .padding()
    .background(ThemeColors.darkBase)
}
