import SwiftUI

// MARK: - Extension Manager View

/// Browse, install, and manage MCP Extensions
struct ExtensionManagerView: View {
    @ObservedObject private var registry = ExtensionRegistry.shared
    @ObservedObject private var installer = ExtensionInstaller.shared
    @State private var selectedTab: ExtensionTab = .browse
    @State private var selectedExtension: MCPExtension?
    @State private var showPermissionReview: MCPExtension?
    @State private var showRuntimeWarning: ExtensionRuntime?

    // Dark theme colors - Using ThemeColors
    private let darkBase = ThemeColors.darkBase
    private let darkSurface = ThemeColors.darkSurface
    private let darkBorder = ThemeColors.darkBorder
    private let textPrimary = ThemeColors.textPrimary
    private let textSecondary = ThemeColors.textSecondary
    private let accent = ThemeColors.accent

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()
                .background(darkBorder)

            // Tab bar
            tabBar

            Divider()
                .background(darkBorder)

            // Content
            Group {
                switch selectedTab {
                case .browse:
                    browseView
                case .installed:
                    installedView
                case .updates:
                    updatesView
                }
            }
        }
        .background(darkBase)
        .sheet(item: $showPermissionReview) { ext in
            PermissionReviewSheet(extension_: ext, onConfirm: {
                Task { try? await installer.install(ext) }
                showPermissionReview = nil
            }, onCancel: {
                showPermissionReview = nil
            })
        }
        .alert("Runtime Required", isPresented: .init(
            get: { showRuntimeWarning != nil },
            set: { if !$0 { showRuntimeWarning = nil } }
        )) {
            Button("OK") { showRuntimeWarning = nil }
        } message: {
            if let runtime = showRuntimeWarning {
                Text("\(runtime.displayName) is required to install this extension. Please install \(runtime.displayName) first.")
            }
        }
        .onAppear {
            Task { await registry.refreshRegistry() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accent.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
            }

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text("Extensions")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(textPrimary)

                Text("Discover and install MCP server extensions")
                    .font(.system(size: 12))
                    .foregroundStyle(textSecondary)
            }

            Spacer()

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(textSecondary)

                TextField("Search extensions...", text: $registry.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 150)

                if !registry.searchQuery.isEmpty {
                    Button {
                        registry.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(darkSurface)
            .cornerRadius(6)

            // Refresh
            Button {
                Task { await registry.refreshRegistry() }
            } label: {
                Image(systemName: registry.isLoading ? "arrow.clockwise" : "arrow.clockwise")
                    .font(.system(size: 14))
                    .rotationEffect(.degrees(registry.isLoading ? 360 : 0))
                    .animation(registry.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: registry.isLoading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(textSecondary)
            .disabled(registry.isLoading)
        }
        .padding(16)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ExtensionTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))

                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))

                        if tab == .updates && updatesCount > 0 {
                            Text("\(updatesCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accent)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? accent.opacity(0.15) : Color.clear)
                    .foregroundStyle(selectedTab == tab ? accent : textSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Category filter
            Menu {
                Button("All Categories") {
                    registry.selectedCategory = nil
                }

                Divider()

                ForEach(ExtensionCategory.allCases, id: \.self) { category in
                    Button {
                        registry.selectedCategory = category
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                            if registry.selectedCategory == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: registry.selectedCategory?.icon ?? "square.grid.2x2")
                    Text(registry.selectedCategory?.displayName ?? "All")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(darkSurface)
                .foregroundStyle(textSecondary)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .background(darkBase)
    }

    private var updatesCount: Int {
        registry.installedExtensions.filter { installed in
            registry.hasUpdate(installed.id)
        }.count
    }

    // MARK: - Browse View

    private var browseView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Check if search has no results
                if !registry.searchQuery.isEmpty && registry.filteredExtensions.isEmpty {
                    EmptyBrowseStateView(
                        searchQuery: registry.searchQuery,
                        onClearSearch: { registry.searchQuery = "" }
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    // Featured section (if available)
                    if let featured = registry.featuredExtensions, registry.searchQuery.isEmpty {
                        featuredSection(featured)
                    }

                    // Extensions grid
                    extensionsGrid
                }
            }
            .padding(16)
        }
    }

    private func featuredSection(_ featured: FeaturedExtensions) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(featured.featured) { ext in
                        FeaturedExtensionCard(
                            extension_: ext,
                            isInstalled: registry.isInstalled(ext.id),
                            onInstall: { installExtension(ext) }
                        )
                    }
                }
            }
        }
    }

    private var extensionsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            if registry.selectedCategory != nil {
                // Single category
                ForEach(registry.filteredExtensions) { ext in
                    ExtensionCard(
                        extension_: ext,
                        isInstalled: registry.isInstalled(ext.id),
                        hasUpdate: registry.hasUpdate(ext.id),
                        onInstall: { installExtension(ext) },
                        onUninstall: { uninstallExtension(ext.id) },
                        onUpdate: { updateExtension(ext.id) }
                    )
                }
            } else {
                // Grouped by category
                ForEach(ExtensionCategory.allCases, id: \.self) { category in
                    let extensions = registry.extensionsByCategory[category] ?? []
                    if !extensions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(accent)
                                Text(category.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(textPrimary)

                                Spacer()

                                Text("\(extensions.count)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(textSecondary)
                            }

                            ForEach(extensions) { ext in
                                ExtensionCard(
                                    extension_: ext,
                                    isInstalled: registry.isInstalled(ext.id),
                                    hasUpdate: registry.hasUpdate(ext.id),
                                    onInstall: { installExtension(ext) },
                                    onUninstall: { uninstallExtension(ext.id) },
                                    onUpdate: { updateExtension(ext.id) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Installed View

    private var installedView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if registry.installedExtensions.isEmpty {
                    emptyInstalledView
                } else {
                    ForEach(registry.installedExtensions, id: \.id) { installed in
                        InstalledExtensionRow(
                            installed: installed,
                            hasUpdate: registry.hasUpdate(installed.id),
                            onToggle: { enabled in
                                registry.setEnabled(installed.id, enabled: enabled)
                            },
                            onUninstall: { uninstallExtension(installed.id) },
                            onUpdate: { updateExtension(installed.id) }
                        )
                    }
                }
            }
            .padding(16)
        }
    }

    private var emptyInstalledView: some View {
        VStack(spacing: 24) {
            // Illustration
            ExtensionEmptyStateIllustration()

            VStack(spacing: 10) {
                Text("No Extensions Installed")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(textPrimary)

                Text("Extensions add powerful capabilities\nto your AI conversations")
                    .font(.system(size: 13))
                    .foregroundStyle(textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Benefits list
            VStack(spacing: 12) {
                ExtensionBenefitRow(
                    icon: "bolt.fill",
                    title: "More Tools",
                    description: "Access files, databases, APIs",
                    color: accent
                )
                ExtensionBenefitRow(
                    icon: "cpu",
                    title: "Local Processing",
                    description: "Run computations on your machine",
                    color: Color(hex: "5a9bd5")
                )
                ExtensionBenefitRow(
                    icon: "shield.fill",
                    title: "Privacy First",
                    description: "Your data stays on your device",
                    color: Color(hex: "9b59b6")
                )
            }
            .padding(.horizontal, 32)

            Button {
                selectedTab = .browse
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                    Text("Discover Extensions")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accent)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Updates View

    private var updatesView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let updatableExtensions = registry.installedExtensions.filter { registry.hasUpdate($0.id) }

                if updatableExtensions.isEmpty {
                    emptyUpdatesView
                } else {
                    // Update all button
                    HStack {
                        Spacer()
                        Button {
                            Task {
                                for ext in updatableExtensions {
                                    try? await installer.update(ext.id)
                                }
                            }
                        } label: {
                            Label("Update All", systemImage: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .disabled(installer.isInstalling)
                    }

                    ForEach(updatableExtensions, id: \.id) { installed in
                        UpdateExtensionRow(
                            installed: installed,
                            availableVersion: registry.availableExtensions.first(where: { $0.id == installed.id })?.version ?? "",
                            onUpdate: { updateExtension(installed.id) }
                        )
                    }
                }
            }
            .padding(16)
        }
    }

    private var emptyUpdatesView: some View {
        VStack(spacing: 20) {
            // Success illustration
            ZStack {
                Circle()
                    .fill(accent.opacity(0.1))
                    .frame(width: 80, height: 80)

                Circle()
                    .stroke(accent.opacity(0.2), lineWidth: 2)
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 8) {
                Text("All Extensions Up to Date")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(textPrimary)

                Text("Your extensions are running the latest versions")
                    .font(.system(size: 13))
                    .foregroundStyle(textSecondary)
            }

            // Last checked info
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))

                Text("Last checked just now")
                    .font(.system(size: 11))
            }
            .foregroundStyle(textSecondary.opacity(0.7))
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

    private func installExtension(_ ext: MCPExtension) {
        // Check runtime availability
        if ext.serverConfig.runtime != .binary && !installer.isRuntimeAvailable(ext.serverConfig.runtime) {
            showRuntimeWarning = ext.serverConfig.runtime
            return
        }

        // Show permission review
        showPermissionReview = ext
    }

    private func uninstallExtension(_ id: String) {
        Task {
            try? await installer.uninstall(id)
        }
    }

    private func updateExtension(_ id: String) {
        Task {
            try? await installer.update(id)
        }
    }
}

// MARK: - Tab Enum

enum ExtensionTab: String, CaseIterable {
    case browse = "Browse"
    case installed = "Installed"
    case updates = "Updates"

    var icon: String {
        switch self {
        case .browse: return "square.grid.2x2"
        case .installed: return "checkmark.circle"
        case .updates: return "arrow.clockwise"
        }
    }
}

// MARK: - Extension Card

struct ExtensionCard: View {
    let extension_: MCPExtension
    let isInstalled: Bool
    let hasUpdate: Bool
    let onInstall: () -> Void
    let onUninstall: () -> Void
    let onUpdate: () -> Void

    private let darkSurface = ThemeColors.darkSurface
    private let darkBorder = ThemeColors.darkBorder
    private let textPrimary = Color.white
    private let textSecondary = ThemeColors.textSecondary
    private let accent = ThemeColors.accent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(extension_.category.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: extension_.icon ?? extension_.category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(extension_.category.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(extension_.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(textPrimary)

                    Text("v\(extension_.version)")
                        .font(.system(size: 10))
                        .foregroundStyle(textSecondary)

                    // Runtime badge
                    Text(extension_.serverConfig.runtime.displayName)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(darkBorder)
                        .foregroundStyle(textSecondary)
                        .cornerRadius(4)
                }

                Text(extension_.description)
                    .font(.system(size: 12))
                    .foregroundStyle(textSecondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text("by \(extension_.author)")
                        .font(.system(size: 10))
                        .foregroundStyle(textSecondary)

                    if let tags = extension_.tags?.prefix(2) {
                        ForEach(Array(tags), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(darkBorder)
                                .foregroundStyle(textSecondary)
                                .cornerRadius(2)
                        }
                    }
                }
            }

            Spacer()

            // Actions
            if isInstalled {
                if hasUpdate {
                    Button {
                        onUpdate()
                    } label: {
                        Label("Update", systemImage: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .controlSize(.small)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(accent)

                        Button {
                            onUninstall()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(textSecondary)
                    }
                }
            } else {
                Button {
                    onInstall()
                } label: {
                    Label("Install", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(darkSurface)
        .cornerRadius(10)
    }
}

// MARK: - Featured Extension Card

struct FeaturedExtensionCard: View {
    let extension_: MCPExtension
    let isInstalled: Bool
    let onInstall: () -> Void

    private let darkSurface = ThemeColors.darkSurface
    private let textPrimary = Color.white
    private let textSecondary = ThemeColors.textSecondary
    private let accent = ThemeColors.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(extension_.category.color.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: extension_.icon ?? extension_.category.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(extension_.category.color)
                }

                Spacer()

                if isInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accent)
                }
            }

            Text(extension_.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textPrimary)
                .lineLimit(1)

            Text(extension_.description)
                .font(.system(size: 11))
                .foregroundStyle(textSecondary)
                .lineLimit(2)

            Spacer()

            if !isInstalled {
                Button {
                    onInstall()
                } label: {
                    Text("Install")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 180, height: 160)
        .background(darkSurface)
        .cornerRadius(10)
    }
}

// MARK: - Installed Extension Row

struct InstalledExtensionRow: View {
    let installed: InstalledExtension
    let hasUpdate: Bool
    let onToggle: (Bool) -> Void
    let onUninstall: () -> Void
    let onUpdate: () -> Void

    @State private var isEnabled: Bool

    init(installed: InstalledExtension, hasUpdate: Bool, onToggle: @escaping (Bool) -> Void, onUninstall: @escaping () -> Void, onUpdate: @escaping () -> Void) {
        self.installed = installed
        self.hasUpdate = hasUpdate
        self.onToggle = onToggle
        self.onUninstall = onUninstall
        self.onUpdate = onUpdate
        _isEnabled = State(initialValue: installed.isEnabled)
    }

    private let darkSurface = ThemeColors.darkSurface
    private let darkBorder = ThemeColors.darkBorder
    private let textPrimary = Color.white
    private let textSecondary = ThemeColors.textSecondary
    private let accent = ThemeColors.accent

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(installed.extension_.category.color.opacity(isEnabled ? 0.15 : 0.05))
                    .frame(width: 44, height: 44)

                Image(systemName: installed.extension_.icon ?? installed.extension_.category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isEnabled ? installed.extension_.category.color : textSecondary)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(installed.extension_.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isEnabled ? textPrimary : textSecondary)

                    Text("v\(installed.installedVersion)")
                        .font(.system(size: 10))
                        .foregroundStyle(textSecondary)

                    if hasUpdate {
                        Text("Update available")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accent.opacity(0.2))
                            .foregroundStyle(accent)
                            .cornerRadius(4)
                    }
                }

                Text("Installed \(installed.installDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary)
            }

            Spacer()

            // Enable/Disable toggle
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(accent)
                .onChange(of: isEnabled) { _, newValue in
                    onToggle(newValue)
                }

            // Menu
            Menu {
                if hasUpdate {
                    Button {
                        onUpdate()
                    } label: {
                        Label("Update", systemImage: "arrow.clockwise")
                    }
                }

                Button(role: .destructive) {
                    onUninstall()
                } label: {
                    Label("Uninstall", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(darkSurface)
        .cornerRadius(10)
    }
}

// MARK: - Update Extension Row

struct UpdateExtensionRow: View {
    let installed: InstalledExtension
    let availableVersion: String
    let onUpdate: () -> Void

    private let darkSurface = ThemeColors.darkSurface
    private let textPrimary = Color.white
    private let textSecondary = ThemeColors.textSecondary
    private let accent = ThemeColors.accent

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(installed.extension_.category.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: installed.extension_.icon ?? installed.extension_.category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(installed.extension_.category.color)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(installed.extension_.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(textPrimary)

                HStack(spacing: 4) {
                    Text("v\(installed.installedVersion)")
                        .font(.system(size: 11))
                        .foregroundStyle(textSecondary)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundStyle(accent)

                    Text("v\(availableVersion)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accent)
                }
            }

            Spacer()

            Button {
                onUpdate()
            } label: {
                Label("Update", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .controlSize(.small)
        }
        .padding(12)
        .background(darkSurface)
        .cornerRadius(10)
    }
}

// MARK: - Permission Review Sheet

struct PermissionReviewSheet: View {
    let extension_: MCPExtension
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let darkBase = ThemeColors.darkBase
    private let darkSurface = ThemeColors.darkSurface
    private let textPrimary = Color.white
    private let textSecondary = ThemeColors.textSecondary
    private let accent = ThemeColors.accent

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Review Permissions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(textPrimary)

                Spacer()

                Button {
                    dismiss()
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Extension info
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(extension_.category.color.opacity(0.15))
                                .frame(width: 48, height: 48)

                            Image(systemName: extension_.icon ?? extension_.category.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(extension_.category.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(extension_.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(textPrimary)

                            Text("by \(extension_.author)")
                                .font(.system(size: 12))
                                .foregroundStyle(textSecondary)
                        }
                    }

                    Divider()

                    // Permissions
                    Text("This extension requests the following permissions:")
                        .font(.system(size: 13))
                        .foregroundStyle(textSecondary)

                    ForEach(extension_.permissions.indices, id: \.self) { index in
                        PermissionRow(permission: extension_.permissions[index])
                    }

                    // Warning for high risk
                    let hasHighRisk = extension_.permissions.contains { $0.riskLevel == .high }
                    if hasHighRisk {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)

                            Text("This extension requests elevated permissions. Only install if you trust the author.")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                    onCancel()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    dismiss()
                    onConfirm()
                } label: {
                    Label("Install", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }
            .padding()
        }
        .frame(width: 450, height: 500)
        .background(darkBase)
    }
}

struct PermissionRow: View {
    let permission: ExtensionPermission

    private let darkSurface = ThemeColors.darkSurface
    private let textPrimary = Color.white
    private let textSecondary = ThemeColors.textSecondary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: permission.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: permission.riskLevel.color))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(permission.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(textPrimary)

                Text(permission.description)
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary)
            }

            Spacer()

            // Risk indicator
            Text(permission.riskLevel.rawValue.capitalized)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: permission.riskLevel.color).opacity(0.15))
                .foregroundStyle(Color(hex: permission.riskLevel.color))
                .cornerRadius(4)
        }
        .padding(10)
        .background(darkSurface)
        .cornerRadius(8)
    }
}

// MARK: - Category Color Extension

extension ExtensionCategory {
    var color: Color {
        switch self {
        case .productivity: return Color(hex: "5a9bd5")
        case .development: return Color(hex: "9b59b6")
        case .data: return Color(hex: "e67e22")
        case .communication: return Color(hex: "3498db")
        case .media: return Color(hex: "e91e63")
        case .utilities: return Color(hex: "00976d")
        case .ai: return Color(hex: "8e44ad")
        case .security: return Color(hex: "c0392b")
        case .other: return Color(hex: "808080")
        }
    }
}

// MARK: - Extension Empty State Illustration

struct ExtensionEmptyStateIllustration: View {
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0

    private let accent = ThemeColors.accent

    var body: some View {
        ZStack {
            // Background pulse
            Circle()
                .fill(accent.opacity(0.05))
                .frame(width: 120, height: 120)
                .scaleEffect(pulseScale)

            // Orbiting puzzle pieces
            ForEach(0..<4, id: \.self) { index in
                Image(systemName: "puzzlepiece.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(accent.opacity(0.4))
                    .offset(
                        x: cos(Double(index) * .pi / 2 + (isAnimating ? .pi * 2 : 0)) * 40,
                        y: sin(Double(index) * .pi / 2 + (isAnimating ? .pi * 2 : 0)) * 40
                    )
            }

            // Center icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.2),
                                accent.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(accent)
            }
        }
        .frame(width: 140, height: 140)
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }
}

// MARK: - Extension Benefit Row

struct ExtensionBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    private let darkSurface = ThemeColors.darkSurface
    private let textPrimary = Color.white
    private let textSecondary = ThemeColors.textSecondary

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(textPrimary)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(darkSurface)
        )
    }
}

// MARK: - Empty Browse State

struct EmptyBrowseStateView: View {
    let searchQuery: String
    let onClearSearch: () -> Void

    private let darkSurface = ThemeColors.darkSurface
    private let textPrimary = Color.white
    private let textSecondary = ThemeColors.textSecondary
    private let accent = ThemeColors.accent

    var body: some View {
        VStack(spacing: 24) {
            // Search illustration
            ZStack {
                Circle()
                    .fill(darkSurface)
                    .frame(width: 80, height: 80)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(textSecondary.opacity(0.6))

                Image(systemName: "questionmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(textSecondary)
                    .offset(x: 18, y: 18)
            }

            VStack(spacing: 8) {
                Text("No extensions found")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(textPrimary)

                Text("No results for \"\(searchQuery)\"")
                    .font(.system(size: 13))
                    .foregroundStyle(textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Suggestions:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textSecondary.opacity(0.8))

                VStack(alignment: .leading, spacing: 4) {
                    SuggestionBullet(text: "Try different keywords")
                    SuggestionBullet(text: "Check the spelling")
                    SuggestionBullet(text: "Browse by category instead")
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(darkSurface)
            )

            Button(action: onClearSearch) {
                Text("Clear search")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 320)
        .padding(.vertical, 40)
    }
}

struct SuggestionBullet: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ThemeColors.textSecondary.opacity(0.5))
                .frame(width: 4, height: 4)

            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(ThemeColors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    ExtensionManagerView()
        .frame(width: 800, height: 600)
}

#Preview("Empty Installed") {
    VStack {
        ExtensionEmptyStateIllustration()
    }
    .frame(width: 300, height: 300)
    .background(ThemeColors.darkBase)
}
