import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Visual Effect View for macOS Vibrancy (Xcode-style sidebar)

/// NSVisualEffectView wrapper for true macOS vibrancy/translucency
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State

    init(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .followsWindowActiveState
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

extension Notification.Name {
    static let toggleSettings = Notification.Name("toggleSettings")
    static let openSettings = Notification.Name("openSettings")
    static let ingestProject = Notification.Name("ingestProject")
    static let newChat = Notification.Name("newChat")
    static let sendInitialMessage = Notification.Name("sendInitialMessage")
    static let memoriesExtracted = Notification.Name("memoriesExtracted")
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let zoomReset = Notification.Name("zoomReset")
    static let toggleChatSidebar = Notification.Name("toggleChatSidebar")
    static let scrollToTop = Notification.Name("scrollToTop")
    static let scrollToBottom = Notification.Name("scrollToBottom")
    static let chatFontZoomChanged = Notification.Name("chatFontZoomChanged")
    static let chatInputFontZoomChanged = Notification.Name("chatInputFontZoomChanged")
    static let chatListFontZoomChanged = Notification.Name("chatListFontZoomChanged")
    static let settingsFontZoomChanged = Notification.Name("settingsFontZoomChanged")
    static let exportConversation = Notification.Name("exportConversation")
    static let importConversation = Notification.Name("importConversation")
    static let selectConversation = Notification.Name("selectConversation")
    static let openArtifactInPanel = Notification.Name("openArtifactInPanel")
    static let toggleArtifactPanel = Notification.Name("toggleArtifactPanel")
    static let contextEnhanced = Notification.Name("contextEnhanced")
    static let toggleBrowserPanel = Notification.Name("toggleBrowserPanel")
    static let browserNavigate = Notification.Name("browserNavigate")
    static let showOnboarding = Notification.Name("showOnboarding")
}

@main
struct VaizorApp: App {
    @StateObject private var container = DependencyContainer()

    init() {
        // Initialize logging
        AppLogger.shared.log("Vaizor app starting", level: .info)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .withAdaptiveColors()
                .onAppear {
                    AppLogger.shared.log("ContentView appeared", level: .info)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {}
            
            CommandMenu("File") {
                Button("New Chat") {
                    NotificationCenter.default.post(name: .newChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Ingest Project...") {
                    NotificationCenter.default.post(name: .ingestProject, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("Export Conversation...") {
                    NotificationCenter.default.post(name: .exportConversation, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Import Conversation...") {
                    NotificationCenter.default.post(name: .importConversation, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Divider()

                Button("Close Window") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            
            // Standard Edit menu with pasteboard commands
            // Note: SwiftUI TextField requires explicit Edit menu for Cmd+C/V/X/Z to work
            CommandGroup(replacing: .pasteboard) {
                Button("Cut") {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x", modifiers: .command)
                
                Button("Copy") {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("c", modifiers: .command)
                
                Button("Paste") {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("v", modifiers: .command)
                
                Button("Select All") {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("a", modifiers: .command)
            }
            
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: .command)
                
                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            
            CommandMenu("View") {
                Button("Zoom In") {
                    NotificationCenter.default.post(name: .zoomIn, object: nil)
                }
                .keyboardShortcut("=", modifiers: .command)
                
                Button("Zoom Out") {
                    NotificationCenter.default.post(name: .zoomOut, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Actual Size") {
                    NotificationCenter.default.post(name: .zoomReset, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
                
                Divider()
                
                Button("Toggle Chat Sidebar") {
                    NotificationCenter.default.post(name: .toggleChatSidebar, object: nil)
                }
                .keyboardShortcut("1", modifiers: [.command, .control])
                
                Button("Toggle Settings Sidebar") {
                    NotificationCenter.default.post(name: .toggleSettings, object: nil)
                }
                .keyboardShortcut("2", modifiers: [.command, .control])
            }
            
            CommandMenu("Vaizor") {
                Button("About Vaizor") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Vaizor",
                        .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                        .version: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                        .credits: NSAttributedString(
                            string: "A premium AI client for macOS.\nSeamlessly connect with Claude, GPT, Gemini, and local LLMs.\n\nDeveloped by Quandry\n\n© 2024-2025 Quandry Labs. All rights reserved.",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 11),
                                .foregroundColor: NSColor.secondaryLabelColor
                            ]
                        )
                    ])
                }

                Divider()

                Button("Preferences...") {
                    NotificationCenter.default.post(name: .toggleSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandMenu("Window") {
                Button("Minimize") {
                    NSApplication.shared.keyWindow?.miniaturize(nil)
                }
                .keyboardShortcut("m", modifiers: .command)
                
                Button("Zoom") {
                    NSApplication.shared.keyWindow?.zoom(nil)
                }
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var container: DependencyContainer
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var conversationManager = ConversationManager()
    @State private var selectedFolderId: UUID? = nil
    @State private var selectedTag: String? = nil
    @State private var showFavoritesOnly: Bool = false
    @State private var showArchived: Bool = false
    @State private var selectedConversation: Conversation?
    @State private var splitConversation: Conversation?
    @State private var showSidebar = true
    @State private var settingsSidebarWidth: CGFloat = 600
    @AppStorage("sidebarPosition") private var sidebarPosition: SidebarPosition = .left
    @State private var selectedTab: SidebarTab = .chat
    @State private var selectedNavSection: SidebarNavItem = .chats
    @State private var showHelpSheet = false
    @State private var showImportConflictAlert = false
    @State private var showImportErrorAlert = false
    @State private var importErrorMessage = ""
    @State private var pendingImportURL: URL?
    @State private var showArtifactPanel = false
    @State private var showShareSheet = false
    @State private var showProjectSheet = false
    @State private var showProjectSettings = false
    @State private var projectForSettings: Project? = nil

    // Onboarding state
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @State private var showProjectIngestion = false

    // Adaptive colors for light/dark mode
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let screen = NSScreen.main ?? NSScreen.screens.first
            let viewportWidth = screen?.frame.width ?? 1920
            let minWindowWidth = max(viewportWidth * 0.3, 800) // 30% of viewport, minimum 800

            HStack(spacing: 0) {
                // Sidebar position logic - runs full height
                if sidebarPosition == .left && showSidebar {
                    sidebarWithTrafficLights
                        .frame(width: sidebarWidth(for: geometry.size.width))

                    // Tahoe-style: Subtle separator between sidebar and content
                    Rectangle()
                        .fill(colors.border)
                        .frame(width: 1)
                }

                // Main content area with header
                VStack(spacing: 0) {
                    // Main content header with drag area
                    mainContentHeader

                    // Content area (flexible, takes remaining space)
                    if splitConversation != nil {
                        HStack(spacing: 0) {
                            mainChatView(conversation: selectedConversation)
                                .frame(minWidth: 300, maxWidth: .infinity)
                            Divider()
                            splitChatView(conversation: splitConversation)
                                .frame(minWidth: 300, maxWidth: .infinity)
                        }
                    } else {
                        mainContent
                            .frame(minWidth: 400, maxWidth: .infinity)
                    }
                }
                .background(colors.background)

                // Right sidebar
                if sidebarPosition == .right && showSidebar {
                    // Tahoe-style: Subtle separator
                    Rectangle()
                        .fill(colors.border)
                        .frame(width: 1)

                    sidebarWithTrafficLights
                        .frame(width: sidebarWidth(for: geometry.size.width))
                }
            }
            .frame(minWidth: minWindowWidth, minHeight: 500)
            .ignoresSafeArea()
            .onAppear {
                setWindowConstraints(viewportWidth: viewportWidth)
                configureWindowAppearance()
            }
            .onChange(of: geometry.size) { _, _ in
                // Ensure window respects minimum size
                enforceMinimumSize(viewportWidth: viewportWidth)
            }
        }
        .onAppear {
            if selectedConversation == nil, let first = conversationManager.conversations.first {
                selectedConversation = first
            }
            // Show onboarding on first launch
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSettings)) { _ in
            showSettingsSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChat)) { _ in
            createNewChat()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleChatSidebar)) { _ in
            showSidebar.toggle()
            if showSidebar {
                selectedTab = .chat
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportConversation)) { _ in
            handleExportConversation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .importConversation)) { _ in
            handleImportConversation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectConversation)) { notification in
            if let conversationId = notification.userInfo?["conversationId"] as? UUID {
                if let conversation = conversationManager.conversations.first(where: { $0.id == conversationId }) {
                    selectedConversation = conversation
                    selectedTab = .chat
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleArtifactPanel)) { notification in
            // Keep button state in sync when toggled from ChatView
            if let isShown = notification.object as? Bool {
                showArtifactPanel = isShown
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showOnboarding)) { _ in
            // Allow re-showing onboarding from settings
            showOnboarding = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoriesExtracted)) { notification in
            // Handle auto-extracted memories from conversations
            if let userInfo = notification.userInfo,
               let projectId = userInfo["projectId"] as? UUID,
               let memories = userInfo["memories"] as? [MemoryEntry] {
                for memory in memories {
                    // Add memory with inactive status by default (user can review and activate)
                    var inactiveMemory = memory
                    inactiveMemory = MemoryEntry(
                        id: memory.id,
                        key: memory.key,
                        value: memory.value,
                        createdAt: memory.createdAt,
                        source: memory.source,
                        conversationId: memory.conversationId,
                        confidence: memory.confidence,
                        isActive: false  // Require user review before activating
                    )
                    container.projectManager.addMemoryEntry(
                        to: projectId,
                        key: inactiveMemory.key,
                        value: inactiveMemory.value,
                        source: inactiveMemory.source
                    )
                }
                AppLogger.shared.log("Added \(memories.count) auto-extracted memories to project (pending review)", level: .info)
            }
        }
        .alert("Conversation Already Imported", isPresented: $showImportConflictAlert) {
            Button("Import Again", role: .destructive) {
                guard let url = pendingImportURL else { return }
                Task {
                    do {
                        let importer = ConversationImporter()
                        let newId = try await importer.importConversation(from: url, allowDuplicate: true)
                        await conversationManager.reloadConversations()
                        selectedConversation = conversationManager.conversations.first { $0.id == newId }
                    } catch {
                        importErrorMessage = error.localizedDescription
                        showImportErrorAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This archive was imported before. Importing again will replace the previous imported conversation.")
        }
        .alert("Import Failed", isPresented: $showImportErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareConversationSheet(
                conversation: selectedConversation,
                onDismiss: { showShareSheet = false }
            )
        }
        .sheet(isPresented: $showProjectSheet) {
            ProjectTemplatePickerView { template in
                showProjectSheet = false
                // Create new conversation with the selected template
                let newConversation = conversationManager.createConversation(
                    title: template.name,
                    systemPrompt: template.systemPrompt
                )
                selectedConversation = newConversation
            }
            .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $showProjectSettings) {
            ProjectSettingsView(
                project: $projectForSettings,
                isPresented: $showProjectSettings,
                projectManager: container.projectManager
            )
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .frame(minWidth: 800, minHeight: 600)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showProjectIngestion) {
            ProjectIngestionView(isPresented: $showProjectIngestion)
                .environmentObject(container)
                .frame(minWidth: 700, minHeight: 550)
        }
        .onReceive(NotificationCenter.default.publisher(for: .ingestProject)) { _ in
            showProjectIngestion = true
        }
        .onChange(of: showOnboarding) { oldValue, newValue in
            // When onboarding is dismissed (showOnboarding becomes false),
            // ensure the completion flag is set to prevent re-showing
            if oldValue == true && newValue == false {
                // Double-check and set the completion flag
                if !hasCompletedOnboarding {
                    hasCompletedOnboarding = true
                }
            }
        }
    }

    private func setWindowConstraints(viewportWidth: CGFloat) {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.isMainWindow }) {
                let minWidth = max(viewportWidth * 0.3, 800)
                let minHeight: CGFloat = 500
                window.minSize = NSSize(width: minWidth, height: minHeight)
                
                // Ensure current size meets minimum
                let currentFrame = window.frame
                if currentFrame.width < minWidth || currentFrame.height < minHeight {
                    let newFrame = NSRect(
                        x: currentFrame.origin.x,
                        y: currentFrame.origin.y,
                        width: max(currentFrame.width, minWidth),
                        height: max(currentFrame.height, minHeight)
                    )
                    window.setFrame(newFrame, display: true, animate: false)
                }
            }
        }
    }
    
    private func enforceMinimumSize(viewportWidth: CGFloat) {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.isMainWindow }) {
                let minWidth = max(viewportWidth * 0.3, 800)
                let currentFrame = window.frame
                
                if currentFrame.width < minWidth {
                    let newFrame = NSRect(
                        x: currentFrame.origin.x,
                        y: currentFrame.origin.y,
                        width: minWidth,
                        height: currentFrame.height
                    )
                    window.setFrame(newFrame, display: true, animate: false)
                }
            }
        }
    }

    private func sidebarWidth(for windowWidth: CGFloat) -> CGFloat {
        // Simplified sidebar: fixed narrow width like LibreChat (260px)
        return min(max(220, windowWidth * 0.20), 280)
    }

    private func configureWindowAppearance() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                // Make titlebar blend with content
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)

                // Tahoe-style: Allow vibrancy/transparency to show through
                window.isOpaque = false
                window.backgroundColor = .clear

                // Configure traffic lights position
                if let closeButton = window.standardWindowButton(.closeButton) {
                    closeButton.superview?.frame.origin.y = 12
                }
            }
        }
    }

    // Sidebar with traffic lights space at top - Tahoe liquid glass style
    private var sidebarWithTrafficLights: some View {
        ZStack {
            // True macOS vibrancy using NSVisualEffectView (like Xcode's sidebar)
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                // Traffic lights area (macOS window controls)
                HStack {
                    Spacer()
                }
                .frame(height: 52)
                .background(
                    WindowDragArea()
                )

                // Actual sidebar content
                tabbedSidebar
            }
        }
    }

    // Main content header with conversation title and controls - balanced Tahoe style
    private var mainContentHeader: some View {
        HStack(spacing: 0) {
            // Left side: Toggle sidebar button (balanced with right side)
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 15, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Toggle sidebar (⌘⇧S)")
            }
            .frame(width: 80, alignment: .leading)

            Spacer()

            // Center: Conversation title
            Text(selectedConversation?.title ?? "New Chat")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Right side controls (balanced width with left side)
            HStack(spacing: 12) {
                // Share button
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Share conversation")

                // Artifact panel toggle
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showArtifactPanel.toggle()
                    }
                    NotificationCenter.default.post(
                        name: .toggleArtifactPanel,
                        object: showArtifactPanel
                    )
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 15, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(showArtifactPanel ? colors.accent : colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Toggle artifact panel (⌘⇧A)")
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(
            ZStack {
                // Tahoe-style: Subtle material background
                colors.background
                WindowDragArea()
            }
        )
    }

    // Tahoe-style sidebar colors using adaptive theme
    private var sidebarDarkBase: Color { colors.background }
    private var sidebarDarkSurface: Color { colors.surface }
    private var sidebarDarkBorder: Color { colors.border }
    private var sidebarTextPrimary: Color { colors.textPrimary }
    private var sidebarTextSecondary: Color { colors.textSecondary }
    private var sidebarAccent: Color { colors.accent }

    private var tabbedSidebar: some View {
        VStack(spacing: 0) {
            // Tab switcher (Chat/Code)
            sidebarTabSwitcher
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if selectedTab == .chat {
                // Chat tab content
                // Navigation items
                sidebarNavigation
                    .padding(.horizontal, 8)

                // Translucent divider that works with material
                Rectangle()
                    .fill(colors.divider)
                    .frame(height: 1)
                    .padding(.vertical, 8)

                // Recents section
                sidebarRecents
            } else {
                // Code tab content
                sidebarCodeContent
            }

            Spacer()

            // User profile at bottom
            sidebarUserProfile
        }
        // No opaque background - let material show through
        .sheet(isPresented: $showHelpSheet) {
            HelpSheetView()
        }
    }

    private var sidebarCodeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Code workspace header
            VStack(alignment: .leading, spacing: 4) {
                Text("Code Workspace")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(sidebarTextPrimary)
                Text("Execute and manage code snippets")
                    .font(.system(size: 11))
                    .foregroundStyle(sidebarTextSecondary)
            }
            .padding(.horizontal, 12)

            Rectangle()
                .fill(colors.divider)
                .frame(height: 1)

            // Quick actions
            VStack(spacing: 4) {
                codeActionButton(icon: "play.fill", title: "Run Last Code", subtitle: "Execute previous snippet")
                codeActionButton(icon: "doc.on.clipboard", title: "Paste & Run", subtitle: "Execute from clipboard")
                codeActionButton(icon: "folder", title: "Open Workspace", subtitle: "Load code workspace")
            }
            .padding(.horizontal, 8)

            Rectangle()
                .fill(colors.divider)
                .frame(height: 1)

            // Recent executions
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Executions")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(sidebarTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 12)

                VStack(spacing: 12) {
                    Image(systemName: "terminal")
                        .font(.system(size: 24))
                        .foregroundStyle(sidebarTextSecondary)
                    Text("No recent executions")
                        .font(.system(size: 12))
                        .foregroundStyle(sidebarTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .padding(.top, 8)
    }

    private func codeActionButton(icon: String, title: String, subtitle: String) -> some View {
        Button {
            // Action handler
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(sidebarAccent)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(sidebarTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(sidebarTextSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(colors.hoverBackground)
            )
        }
        .buttonStyle(.plain)
    }

    @State private var searchQuery = ""
    @State private var isChatsCollapsed = false
    @State private var showSettingsSheet = false
    @State private var showUserMenu = false
    @AppStorage("userName") private var userName: String = "User"
    @AppStorage("userEmail") private var userEmail: String = ""

    private var sidebarHeader: some View {
        HStack(spacing: 12) {
            // Compact logo
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "00976d"), Color(hex: "00976d").opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "sparkles")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
            }

            Text("Vaizor")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Spacer()

            // New chat button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    createNewChat()
                }
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help("New Chat (⌘N)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var sidebarSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            TextField("Search conversations...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchFilteredConversations: [Conversation] {
        let base = filteredConversations
        if searchQuery.isEmpty {
            return base
        }
        return base.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(searchQuery) ||
            conversation.summary.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private var simplifiedChatList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                // Collapsible section header
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isChatsCollapsed.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isChatsCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 12)

                        Text("Chats")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(searchFilteredConversations.count)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if !isChatsCollapsed {
                    ForEach(searchFilteredConversations) { conversation in
                        SimplifiedConversationRow(
                            conversation: conversation,
                            isSelected: selectedConversation?.id == conversation.id,
                            onSelect: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    selectedConversation = conversation
                                }
                                conversationManager.updateLastUsed(conversation.id)
                            },
                            onDelete: {
                                withAnimation {
                                    conversationManager.deleteConversation(conversation.id)
                                    if selectedConversation?.id == conversation.id {
                                        selectedConversation = nil
                                    }
                                }
                            },
                            onRename: { newTitle in
                                conversationManager.updateTitle(conversation.id, title: newTitle)
                            },
                            onArchive: {
                                conversationManager.archiveConversation(conversation.id, isArchived: !conversation.isArchived)
                            },
                            onToggleFavorite: {
                                conversationManager.toggleFavorite(conversation.id)
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var sidebarFooter: some View {
        HStack(spacing: 12) {
            // Filter toggles (compact)
            HStack(spacing: 4) {
                Button {
                    showArchived.toggle()
                    Task {
                        await conversationManager.reloadConversations(includeArchived: showArchived)
                    }
                } label: {
                    Image(systemName: showArchived ? "archivebox.fill" : "archivebox")
                        .font(.system(size: 12))
                        .foregroundStyle(showArchived ? Color(hex: "00976d") : .secondary)
                        .frame(width: 28, height: 28)
                        .background(showArchived ? Color(hex: "00976d").opacity(0.1) : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(showArchived ? "Show Active" : "Show Archived")

                Button {
                    showFavoritesOnly.toggle()
                } label: {
                    Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle(showFavoritesOnly ? .yellow : .secondary)
                        .frame(width: 28, height: 28)
                        .background(showFavoritesOnly ? Color.yellow.opacity(0.1) : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Favorites Only")
            }

            Spacer()

            // Settings button
            Button {
                showSettingsSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                    Text("Settings")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .sheet(isPresented: $showSettingsSheet) {
            ComprehensiveSettingsView()
                .environmentObject(container)
                .environmentObject(conversationManager)
                .frame(minWidth: 600, minHeight: 500)
        }
    }

    // MARK: - New Claude-style Sidebar Components

    private var sidebarTabSwitcher: some View {
        // Tahoe-style glass segmented control
        HStack(spacing: 2) {
            ForEach(SidebarTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(selectedTab == tab ? colors.textPrimary : colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            selectedTab == tab
                            ? RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            : nil
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
        )
    }

    private var sidebarNavigation: some View {
        VStack(spacing: 4) {
            // New chat button (special styling) - Tahoe style
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    createNewChat()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(sidebarAccent)
                    Text("New chat")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(sidebarTextPrimary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // Navigation items - Tahoe style with hierarchical symbols
            ForEach([SidebarNavItem.chats, .projects, .artifacts]) { item in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedNavSection = item
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(selectedNavSection == item ? sidebarAccent : sidebarTextSecondary)
                            .frame(width: 20)
                        Text(item.rawValue)
                            .font(.system(size: 13, weight: selectedNavSection == item ? .medium : .regular))
                            .foregroundStyle(selectedNavSection == item ? sidebarTextPrimary : sidebarTextSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedNavSection == item ? colors.selectedBackground : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sidebarRecents: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section header
            HStack {
                Text(sectionHeaderTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(sidebarTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            // Content based on selected section
            ScrollView {
                LazyVStack(spacing: 2) {
                    switch selectedNavSection {
                    case .chats, .newChat:
                        ForEach(searchFilteredConversations.prefix(20)) { conversation in
                            SidebarConversationRow(
                                conversation: conversation,
                                isSelected: selectedConversation?.id == conversation.id,
                                onSelect: {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        selectedConversation = conversation
                                    }
                                    conversationManager.updateLastUsed(conversation.id)
                                }
                            )
                        }
                    case .projects:
                        // Projects list
                        ProjectSidebarView(
                            projectManager: container.projectManager,
                            conversationManager: conversationManager,
                            showProjectSettings: $showProjectSettings,
                            projectForSettings: $projectForSettings
                        )
                        .environmentObject(container)
                    case .artifacts:
                        // Artifacts placeholder
                        VStack(spacing: 12) {
                            Image(systemName: "cube")
                                .font(.system(size: 32))
                                .foregroundStyle(sidebarTextSecondary)
                            Text("Artifacts")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(sidebarTextPrimary)
                            Text("View generated code, documents, and diagrams")
                                .font(.system(size: 12))
                                .foregroundStyle(sidebarTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private var sectionHeaderTitle: String {
        switch selectedNavSection {
        case .newChat, .chats:
            return "Recents"
        case .projects:
            return "Projects"
        case .artifacts:
            return "Artifacts"
        }
    }

    private var sidebarUserProfile: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(colors.divider)
                .frame(height: 1)

            Menu {
                Button {
                    showSettingsSheet = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }

                Divider()

                Menu("Language") {
                    Button("English (Default)") {
                        UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
                    }
                    Button("Spanish") {
                        UserDefaults.standard.set(["es"], forKey: "AppleLanguages")
                    }
                    Button("French") {
                        UserDefaults.standard.set(["fr"], forKey: "AppleLanguages")
                    }
                }

                Divider()

                Button {
                    showHelpSheet = true
                } label: {
                    Label("Get help", systemImage: "questionmark.circle")
                }

                Button {
                    // Open GitHub releases page or documentation
                    if let url = URL(string: "https://github.com/anthropics/claude-code/issues") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("View all plans", systemImage: "list.bullet")
                }

                Divider()

                Button(role: .destructive) {
                    // Clear session data and reset to welcome state
                    selectedConversation = nil
                    splitConversation = nil
                    // Could also clear sensitive cached data here
                } label: {
                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                HStack(spacing: 10) {
                    // User avatar
                    ZStack {
                        Circle()
                            .fill(sidebarAccent)
                            .frame(width: 32, height: 32)

                        Text(String(userName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(userName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(sidebarTextPrimary)
                        if !userEmail.isEmpty {
                            Text(userEmail)
                                .font(.system(size: 11))
                                .foregroundStyle(sidebarTextSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(sidebarTextSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showSettingsSheet) {
            ComprehensiveSettingsView()
                .environmentObject(container)
                .environmentObject(conversationManager)
                .frame(minWidth: 600, minHeight: 500)
        }
    }

    private var filteredConversations: [Conversation] {
        var filtered = conversationManager.conversations.filter { showArchived ? $0.isArchived : !$0.isArchived }
        
        if showFavoritesOnly {
            filtered = filtered.filter { $0.isFavorite }
        }
        
        if let folderId = selectedFolderId {
            filtered = filtered.filter { $0.folderId == folderId }
        } else {
            // Show conversations without folders when a folder is selected
            // Actually, show all when no folder selected
        }
        
        if let tag = selectedTag {
            filtered = filtered.filter { $0.tags.contains(tag) }
        }
        
        return filtered
    }
    
    private var chatListContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with logo
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "00976d"), Color(hex: "00976d").opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .shadow(color: Color(hex: "00976d").opacity(0.3), radius: 4, y: 2)

                        Image(systemName: "sparkles")
                            .foregroundColor(Color(hex: "eeeeee"))
                            .font(.system(size: 16, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                    }

                    Text("Vaizor")
                        .font(.system(size: 22, weight: .bold, design: .rounded))

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            createNewChat()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 32, height: 32)

                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("New Chat")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

                Divider()
                
                // Filters: Archive, Favorites, Folders, Tags
                VStack(spacing: 8) {
                    // Archive and Favorites toggles
                    HStack(spacing: 8) {
                        Button {
                            showArchived.toggle()
                            Task {
                                await conversationManager.reloadConversations(includeArchived: showArchived)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showArchived ? "archive.fill" : "archive")
                                    .font(.system(size: 11))
                                Text(showArchived ? "Active" : "Archived")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(showArchived ? Color(hex: "00976d") : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(showArchived ? 0.5 : 0.3))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            showFavoritesOnly.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                                    .font(.system(size: 11))
                                Text("Favorites")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(showFavoritesOnly ? .yellow : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(showFavoritesOnly ? 0.5 : 0.3))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    // Folders list
                    if !conversationManager.folders.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                Button {
                                    selectedFolderId = nil
                                } label: {
                                    Text("All")
                                        .font(.system(size: 10, weight: selectedFolderId == nil ? .semibold : .regular))
                                        .foregroundStyle(selectedFolderId == nil ? Color(hex: "00976d") : .secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(nsColor: .controlBackgroundColor).opacity(selectedFolderId == nil ? 0.5 : 0.3))
                                        .cornerRadius(5)
                                }
                                .buttonStyle(.plain)
                                
                                ForEach(conversationManager.folders) { folder in
                                    Button {
                                        selectedFolderId = selectedFolderId == folder.id ? nil : folder.id
                                    } label: {
                                        HStack(spacing: 4) {
                                            if let color = folder.color {
                                                Circle()
                                                    .fill(Color(hex: color))
                                                    .frame(width: 8, height: 8)
                                            }
                                            Text(folder.name)
                                                .font(.system(size: 10, weight: selectedFolderId == folder.id ? .semibold : .regular))
                                        }
                                        .foregroundStyle(selectedFolderId == folder.id ? Color(hex: "00976d") : .secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(nsColor: .controlBackgroundColor).opacity(selectedFolderId == folder.id ? 0.5 : 0.3))
                                        .cornerRadius(5)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }

                // Conversations list
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredConversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: selectedConversation?.id == conversation.id,
                                isSplit: splitConversation?.id == conversation.id,
                                onSelect: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedConversation = conversation
                                    }
                                    conversationManager.updateLastUsed(conversation.id)
                                },
                                onSplit: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if splitConversation?.id == conversation.id {
                                            splitConversation = nil
                                        } else {
                                            splitConversation = conversation
                                        }
                                    }
                                },
                                onRename: { newTitle in
                                    conversationManager.updateTitle(conversation.id, title: newTitle)
                                },
                                onDelete: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        conversationManager.deleteConversation(conversation.id)
                                        if selectedConversation?.id == conversation.id {
                                            selectedConversation = nil
                                        }
                                        if splitConversation?.id == conversation.id {
                                            splitConversation = nil
                                        }
                                    }
                                },
                                onArchive: {
                                    conversationManager.archiveConversation(conversation.id, isArchived: !conversation.isArchived)
                                },
                                onToggleFavorite: {
                                    conversationManager.toggleFavorite(conversation.id)
                                },
                                onAddTag: { tag in
                                    conversationManager.addTag(conversation.id, tag: tag)
                                },
                                onRemoveTag: { tag in
                                    conversationManager.removeTag(conversation.id, tag: tag)
                                }
                            )
                            .environmentObject(conversationManager)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
    }
    
    private var searchContent: some View {
        SearchView(conversationManager: conversationManager)
            .environmentObject(container)
    }
    
    private var settingsContent: some View {
        ComprehensiveSettingsView()
            .environmentObject(container)
            .environmentObject(conversationManager)
    }

    private var mainContent: some View {
        mainChatView(conversation: selectedConversation)
    }
    
    @ViewBuilder
    private func mainChatView(conversation: Conversation?) -> some View {
        VStack(spacing: 0) {
            // Chat content - each instance is independent
            if let conversation = conversation {
                ChatView(
                    conversationId: conversation.id
                )
                .id("main-\(conversation.id)")
                .environmentObject(container)
            } else {
                WelcomeView(
                    onNewChat: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            createNewChat()
                        }
                    },
                    onSendMessage: { message in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            createNewChatWithMessage(message)
                        }
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private func splitChatView(conversation: Conversation?) -> some View {
        VStack(spacing: 0) {
            // Minimal header for split view with close button
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        splitConversation = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Split View")

                Spacer()

                if let conversation = conversation {
                    Text(conversation.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))

            Divider()

            // Split chat content - independent instance with separate pipes
            if let conversation = conversation {
                ChatView(
                    conversationId: conversation.id
                )
                .id("split-\(conversation.id)")
                .environmentObject(container)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func createNewChat() {
        let newConversation = conversationManager.createConversation()
        selectedConversation = newConversation
    }

    private func createNewChatWithMessage(_ message: String) {
        let newConversation = conversationManager.createConversation()
        selectedConversation = newConversation
        // Send the initial message after a brief delay to let ChatView initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .sendInitialMessage, object: message)
        }
    }

    private func handleExportConversation() {
        guard let conversation = selectedConversation else {
            AppLogger.shared.log("No conversation selected for export", level: .warning)
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.zip]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(conversation.title).zip"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            do {
                let exporter = DatabaseConversationExporter()
                try await exporter.exportConversation(id: conversation.id, to: url)
            } catch {
                AppLogger.shared.logError(error, context: "Failed to export conversation \(conversation.id)")
            }
        }
    }

    private func handleImportConversation() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.zip]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            do {
                let importer = ConversationImporter()
                let newId = try await importer.importConversation(from: url)
                await conversationManager.reloadConversations()
                selectedConversation = conversationManager.conversations.first { $0.id == newId }
            } catch {
                let nsError = error as NSError
                if nsError.domain == "ConversationImporter",
                   nsError.code == 409 {
                    pendingImportURL = url
                    showImportConflictAlert = true
                    return
                }
                importErrorMessage = error.localizedDescription
                showImportErrorAlert = true
                AppLogger.shared.logError(error, context: "Failed to import conversation")
            }
        }
    }
}

enum SidebarTab: String, CaseIterable {
    case chat = "Chat"
    case code = "Code"
}

enum SidebarNavItem: String, CaseIterable, Identifiable {
    case newChat = "New chat"
    case chats = "Chats"
    case projects = "Projects"
    case artifacts = "Artifacts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .newChat: return "plus"
        case .chats: return "message"
        case .projects: return "folder"
        case .artifacts: return "cube"
        }
    }
}

enum SidebarPosition: String, Codable {
    case left
    case right
}

// MARK: - Date Formatting Helper
private func formatConversationDate(_ date: Date) -> String {
    let calendar = Calendar.current
    let now = Date()

    if calendar.isDateInToday(date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday"
    } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo < 7 {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Day name
        return formatter.string(from: date)
    } else {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let isSplit: Bool
    let onSelect: () -> Void
    let onSplit: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onArchive: () -> Void
    let onToggleFavorite: (() -> Void)?
    let onAddTag: ((String) -> Void)?
    let onRemoveTag: ((String) -> Void)?

    @EnvironmentObject private var conversationManager: ConversationManager
    @State private var isHovered = false
    @State private var showRenameDialog = false
    @State private var showTagInput = false
    @State private var newTag = ""
    @State private var scale: CGFloat = 1.0
    @State private var previewText: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            iconView

            conversationDetailsView
                .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered {
                hoverActionsView
            }
        }
        .padding(12)
        .background(
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.accentColor.opacity(0.15), radius: 4, y: 2)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.04))
                }
            }
        )
        .scaleEffect(scale)
        .contentShape(Rectangle())
        .contextMenu {
            contextMenuContent
        }
        .sheet(isPresented: $showRenameDialog) {
            RenameConversationView(conversation: conversation) { newTitle in
                onRename(newTitle)
            }
        }
        .alert("Add Tag", isPresented: $showTagInput) {
            TextField("Tag name", text: $newTag)
            Button("Add") {
                if !newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let onAddTag = onAddTag {
                    onAddTag(newTag.trimmingCharacters(in: .whitespacesAndNewlines))
                    newTag = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newTag = ""
            }
        } message: {
            Text("Enter a tag name")
        }
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovered = hovering
                scale = hovering ? 1.01 : 1.0
            }
        }
        .task {
            // Load preview if summary is empty
            if conversation.summary.isEmpty && previewText == nil {
                let preview = await conversationManager.conversationRepository.getLastMessagePreview(for: conversation.id)
                previewText = preview
            }
        }
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "00976d"), Color(hex: "00976d").opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
                .shadow(color: Color(hex: "00976d").opacity(0.2), radius: 3, y: 1)

            Image(systemName: "message.fill")
                .foregroundColor(Color(hex: "eeeeee"))
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
        }
        .padding(.top, 2)
    }

    private var conversationDetailsView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(conversation.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)

            if !conversation.summary.isEmpty {
                Text(conversation.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else if let preview = previewText, !preview.isEmpty {
                Text(preview)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(spacing: 6) {
                if conversation.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                }

                Text(formatConversationDate(conversation.lastUsedAt))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Text("•")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                Text("\(conversation.messageCount) msg")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                if !conversation.tags.isEmpty {
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 4) {
                        ForEach(conversation.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(3)
                        }
                        if conversation.tags.count > 2 {
                            Text("+\(conversation.tags.count - 2)")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private var hoverActionsView: some View {
        VStack(spacing: 8) {
            if let onToggleFavorite = onToggleFavorite {
                Button {
                    onToggleFavorite()
                } label: {
                    ZStack {
                        Circle()
                            .fill(conversation.isFavorite ? Color.yellow.opacity(0.15) : Color.secondary.opacity(0.1))
                            .frame(width: 28, height: 28)

                        Image(systemName: conversation.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(conversation.isFavorite ? .yellow : .secondary)
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .help(conversation.isFavorite ? "Remove from Favorites" : "Add to Favorites")
            }

            Button {
                onSplit()
            } label: {
                ZStack {
                    Circle()
                        .fill(isSplit ? Color(hex: "00976d").opacity(0.15) : Color.secondary.opacity(0.1))
                        .frame(width: 28, height: 28)

                    Image(systemName: isSplit ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                        .foregroundStyle(isSplit ? Color(hex: "00976d") : .secondary)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .help(isSplit ? "Close Split View" : "Open in Split View")

            Button {
                onArchive()
            } label: {
                ZStack {
                    Circle()
                        .fill(conversation.isArchived ? Color(hex: "00976d").opacity(0.15) : Color.secondary.opacity(0.1))
                        .frame(width: 28, height: 28)

                    Image(systemName: conversation.isArchived ? "archivebox.fill" : "archivebox")
                        .foregroundStyle(conversation.isArchived ? Color(hex: "00976d") : .secondary)
                        .font(.system(size: 12, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .buttonStyle(.plain)
            .help(conversation.isArchived ? "Unarchive" : "Archive")

            Button {
                onDelete()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 28, height: 28)

                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(.plain)
        }
        .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if let onToggleFavorite = onToggleFavorite {
            Button {
                onToggleFavorite()
            } label: {
                Label(conversation.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                      systemImage: conversation.isFavorite ? "star.fill" : "star")
            }
        }

        Divider()

        if onAddTag != nil {
            Menu("Add Tag") {
                Button("New Tag...") {
                    showTagInput = true
                }
            }
        }

        if !conversation.tags.isEmpty, let onRemoveTag = onRemoveTag {
            Menu("Remove Tag") {
                ForEach(conversation.tags, id: \.self) { tag in
                    Button(tag) {
                        onRemoveTag(tag)
                    }
                }
            }
        }

        Divider()

        Menu("Move to Folder") {
            Button("Uncategorized") {
                conversationManager.updateFolder(conversation.id, folderId: nil)
            }
            if !conversationManager.folders.isEmpty {
                Divider()
                ForEach(conversationManager.folders) { folder in
                    Button(folder.name) {
                        conversationManager.updateFolder(conversation.id, folderId: folder.id)
                    }
                }
            }
        }

        Divider()

        Button {
            showRenameDialog = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Divider()

        Button {
            onSplit()
        } label: {
            Label(isSplit ? "Close Split View" : "Open in Split View",
                  systemImage: isSplit ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
        }

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Sidebar Conversation Row (Claude style)

struct SidebarConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    // Adaptive colors for Xcode-style translucent sidebar
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Text(conversation.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? colors.textPrimary : colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                if isHovered {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.textMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? colors.sidebarItemSelected : (isHovered ? colors.sidebarItemHover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Simplified Conversation Row (Xcode-style translucent sidebar)

struct SimplifiedConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onArchive: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovered = false
    @State private var showRenameDialog = false
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Simple icon - using hierarchical SF Symbol
            Image(systemName: "message")
                .font(.system(size: 14))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? colors.accent : colors.textSecondary)
                .frame(width: 20)

            // Title and time
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(colors.textPrimary)

                Text(formatConversationDate(conversation.lastUsedAt))
                    .font(.system(size: 11))
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            // Favorite indicator - Apple's system yellow
            if conversation.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "ffd60a"))
            }

            // Delete button on hover
            if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(colors.textMuted)
                        .frame(width: 20, height: 20)
                        .background(colors.hoverBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? colors.sidebarItemSelected : (isHovered ? colors.sidebarItemHover : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                onToggleFavorite()
            } label: {
                Label(conversation.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                      systemImage: conversation.isFavorite ? "star.fill" : "star")
            }

            Divider()

            Button {
                showRenameDialog = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                onArchive()
            } label: {
                Label(conversation.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showRenameDialog) {
            RenameConversationView(conversation: conversation) { newTitle in
                onRename(newTitle)
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Help Sheet View
struct HelpSheetView: View {
    @Environment(\.dismiss) private var dismiss

    private let darkBase = Color(hex: "1c1d1f")
    private let darkSurface = Color(hex: "232426")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")
    private let accent = Color(hex: "00976d")

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Help & Resources")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Keyboard shortcuts section
                    helpSection(title: "Keyboard Shortcuts") {
                        VStack(spacing: 8) {
                            shortcutRow(keys: "N", label: "New chat")
                            shortcutRow(keys: ",", label: "Open settings")
                            shortcutRow(keys: "/", label: "Commands")
                            shortcutRow(keys: "\\", label: "Toggle sidebar")
                            shortcutRow(keys: "E", label: "Export conversation", modifiers: ["shift"])
                            shortcutRow(keys: "I", label: "Import conversation", modifiers: ["shift"])
                        }
                    }

                    // Quick tips section
                    helpSection(title: "Quick Tips") {
                        VStack(alignment: .leading, spacing: 12) {
                            tipRow(icon: "wand.and.stars", text: "Use @ to mention files or context")
                            tipRow(icon: "shield.fill", text: "Sensitive data is automatically redacted")
                            tipRow(icon: "bolt.fill", text: "Enable parallel mode to compare multiple models")
                            tipRow(icon: "cube", text: "Artifacts appear in the side panel for code and documents")
                        }
                    }

                    // Links section
                    helpSection(title: "Resources") {
                        VStack(spacing: 8) {
                            linkRow(title: "Report an Issue", url: "https://github.com/anthropics/claude-code/issues")
                            linkRow(title: "Documentation", url: "https://docs.anthropic.com")
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 500)
        .background(darkBase)
    }

    private func helpSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textPrimary)
            content()
        }
        .padding(16)
        .background(darkSurface)
        .cornerRadius(12)
    }

    private func shortcutRow(keys: String, label: String, modifiers: [String] = []) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(textSecondary)
            Spacer()
            HStack(spacing: 4) {
                Text("\u{2318}")
                    .font(.system(size: 12))
                ForEach(modifiers, id: \.self) { mod in
                    Text(mod == "shift" ? "\u{21E7}" : mod)
                        .font(.system(size: 12))
                }
                Text(keys)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(darkBase)
            .cornerRadius(4)
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(accent)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(textSecondary)
        }
    }

    private func linkRow(title: String, url: String) -> some View {
        Button {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(accent)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Window Drag Area for Custom Title Bar
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowDragNSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class WindowDragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Share Conversation Sheet

struct ShareConversationSheet: View {
    let conversation: Conversation?
    let onDismiss: () -> Void

    @State private var shareLink: String = ""
    @State private var isCopied = false

    private let darkBase = Color(hex: "1c1d1f")
    private let darkSurface = Color(hex: "232426")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")
    private let accent = Color(hex: "00976d")

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Share Conversation")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            if let conversation = conversation {
                VStack(spacing: 20) {
                    // Conversation info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(conversation.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(textPrimary)
                        Text("\(conversation.messageCount) messages")
                            .font(.system(size: 13))
                            .foregroundStyle(textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(darkSurface)
                    .cornerRadius(12)

                    // Share options
                    VStack(spacing: 12) {
                        shareOptionButton(
                            icon: "doc.on.doc",
                            title: "Copy as Text",
                            subtitle: "Copy conversation to clipboard"
                        ) {
                            copyAsText()
                        }

                        shareOptionButton(
                            icon: "square.and.arrow.down",
                            title: "Export Archive",
                            subtitle: "Save as .zip file"
                        ) {
                            exportArchive()
                        }

                        shareOptionButton(
                            icon: "doc.text",
                            title: "Export Markdown",
                            subtitle: "Save as .md file"
                        ) {
                            exportMarkdown()
                        }
                    }

                    if isCopied {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(accent)
                            Text("Copied to clipboard!")
                                .font(.system(size: 13))
                                .foregroundStyle(accent)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(20)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "message")
                        .font(.system(size: 40))
                        .foregroundStyle(textSecondary)
                    Text("No conversation selected")
                        .font(.system(size: 14))
                        .foregroundStyle(textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()
        }
        .frame(width: 400, height: 450)
        .background(darkBase)
    }

    private func shareOptionButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(textSecondary)
            }
            .padding(16)
            .background(darkSurface)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func copyAsText() {
        guard let conversation = conversation else { return }

        Task {
            let repository = ConversationRepository()
            let messages = await repository.loadMessages(for: conversation.id)

            var text = "Conversation: \(conversation.title)\n"
            text += "Date: \(DateFormatter.localizedString(from: conversation.lastUsedAt, dateStyle: .medium, timeStyle: .short))\n"
            text += "Messages: \(messages.count)\n"
            text += String(repeating: "-", count: 40) + "\n\n"

            for message in messages {
                let role = message.role == .user ? "You" : "Assistant"
                let timestamp = DateFormatter.localizedString(from: message.timestamp, dateStyle: .none, timeStyle: .short)
                text += "[\(timestamp)] \(role):\n\(message.content)\n\n"
            }

            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)

                withAnimation {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isCopied = false
                    }
                }
            }
        }
    }

    private func exportArchive() {
        guard let conversation = conversation else { return }
        NotificationCenter.default.post(name: .exportConversation, object: conversation.id)
        onDismiss()
    }

    private func exportMarkdown() {
        guard let conversation = conversation else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "\(conversation.title).md"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                let repository = ConversationRepository()
                let messages = await repository.loadMessages(for: conversation.id)

                var markdown = "# \(conversation.title)\n\n"
                markdown += "> Exported on \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))\n\n"
                markdown += "---\n\n"

                for message in messages {
                    let role = message.role == .user ? "**You**" : "**Assistant**"
                    let timestamp = DateFormatter.localizedString(from: message.timestamp, dateStyle: .none, timeStyle: .short)

                    markdown += "### \(role) *(\(timestamp))*\n\n"
                    markdown += "\(message.content)\n\n"
                    markdown += "---\n\n"
                }

                do {
                    try markdown.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    await AppLogger.shared.logError(error, context: "Failed to export markdown")
                }
            }
        }
        onDismiss()
    }
}
