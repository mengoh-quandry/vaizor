import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Notification.Name {
    static let toggleSettings = Notification.Name("toggleSettings")
    static let newChat = Notification.Name("newChat")
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
                .onAppear {
                    AppLogger.shared.log("ContentView appeared", level: .info)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            
            CommandMenu("File") {
                Button("New Chat") {
                    NotificationCenter.default.post(name: .newChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

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
            
            CommandMenu("Edit") {
                Button("Undo") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: .command)
                
                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                
                Divider()
                
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
            
            CommandMenu("Settings") {
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
    @State private var selectedTab: SidebarTab = .chats
    @State private var showImportConflictAlert = false
    @State private var showImportErrorAlert = false
    @State private var importErrorMessage = ""
    @State private var pendingImportURL: URL?

    var body: some View {
        GeometryReader { geometry in
            let screen = NSScreen.main ?? NSScreen.screens.first
            let viewportWidth = screen?.frame.width ?? 1920
            let minWindowWidth = max(viewportWidth * 0.3, 800) // 30% of viewport, minimum 800
            
            HStack(spacing: 0) {
                // Sidebar position logic
                if sidebarPosition == .left && showSidebar {
                    tabbedSidebar
                        .frame(width: sidebarWidth(for: geometry.size.width))
                    Divider()
                    // 5% padding between sidebar and main content
                    Color.clear.frame(width: geometry.size.width * 0.05)
                }

                // Main content area (flexible, takes remaining space)
                if splitConversation != nil {
                    // Split view - each takes 50% of available space
                    HStack(spacing: 0) {
                        mainChatView(conversation: selectedConversation)
                            .frame(minWidth: 300, maxWidth: .infinity)
                        
                        Divider()
                        
                        splitChatView(conversation: splitConversation)
                            .frame(minWidth: 300, maxWidth: .infinity)
                    }
                } else {
                    // Single view
                    mainContent
                        .frame(minWidth: 400, maxWidth: .infinity)
                }

                // Right sidebar - Settings (flexible width, min 550, max 50% of available)
                if sidebarPosition == .right && showSidebar {
                    // 5% padding between main content and sidebar
                    Color.clear.frame(width: geometry.size.width * 0.05)
                    Divider()
                    tabbedSidebar
                        .frame(width: sidebarWidth(for: geometry.size.width))
                }
            }
            .frame(minWidth: minWindowWidth, minHeight: 500)
            .onAppear {
                setWindowConstraints(viewportWidth: viewportWidth)
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSettings)) { _ in
            if !showSidebar {
                showSidebar = true
            }
            selectedTab = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChat)) { _ in
            createNewChat()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleChatSidebar)) { _ in
            showSidebar.toggle()
            if showSidebar {
                selectedTab = .chats
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
                    selectedTab = .chats
                }
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
        switch selectedTab {
        case .settings:
            // Settings tab: 35% width (35/60 split with 5% padding), min 480px, max 650px
            return max(min(windowWidth * 0.35, 650), 480)
        case .search:
            // Search tab: similar to chats but slightly wider for results
            return min(max(280, windowWidth * 0.25), windowWidth * 0.35)
        case .chats:
            // Chats tab: keep narrower width (22-32%)
            return min(max(240, windowWidth * 0.22), windowWidth * 0.32)
        }
    }

    private var tabbedSidebar: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = .chats
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 14))
                            .symbolRenderingMode(.hierarchical)
                        Text("Chats")
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedTab == .chats ? .primary : .secondary)
                    .background(
                        ZStack {
                            if selectedTab == .chats {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.15))
                                    .shadow(color: Color.accentColor.opacity(0.2), radius: 4, y: 2)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = .search
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .symbolRenderingMode(.hierarchical)
                        Text("Search")
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedTab == .search ? .primary : .secondary)
                    .background(
                        ZStack {
                            if selectedTab == .search {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.15))
                                    .shadow(color: Color.accentColor.opacity(0.2), radius: 4, y: 2)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = .settings
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .symbolRenderingMode(.hierarchical)
                        Text("Settings")
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedTab == .settings ? .primary : .secondary)
                    .background(
                        ZStack {
                            if selectedTab == .settings {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.15))
                                    .shadow(color: Color.accentColor.opacity(0.2), radius: 4, y: 2)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .chats:
                    chatListContent
                case .search:
                    searchContent
                case .settings:
                    settingsContent
                }
            }
        }
        .background(.thinMaterial)
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
            .onChange(of: selectedConversation?.id) { _, newId in
                // When a conversation is selected from search, switch to chats tab
                if newId != nil && selectedTab == .search {
                    selectedTab = .chats
                }
            }
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
            // Toolbar with modern styling
            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showSidebar.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(showSidebar ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.06))
                            .frame(width: 32, height: 32)

                        Image(systemName: sidebarPosition == .left ? "sidebar.left" : "sidebar.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(showSidebar ? .primary : .secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .buttonStyle(.plain)
                .help(showSidebar ? "Hide Sidebar" : "Show Sidebar")

                Spacer()

                if let conversation = conversation {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)

                            Text(conversation.title)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.04))
                        )
                        
                        // Per-conversation model selector
                        ConversationModelSelector(
                            conversation: conversation,
                            conversationManager: conversationManager,
                            container: container
                        )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)

            Divider()

            // Chat content - each instance is independent
            if let conversation = conversation {
                ChatView(
                    conversationId: conversation.id,
                    conversationManager: conversationManager
                )
                .id("main-\(conversation.id)")
                .environmentObject(container)
            } else {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "00976d").opacity(0.2), Color(hex: "00976d").opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: "message")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Color(hex: "00976d"))
                            .symbolRenderingMode(.hierarchical)
                    }

                    VStack(spacing: 8) {
                        Text("No Chat Selected")
                            .font(.system(size: 22, weight: .bold, design: .rounded))

                        Text("Create a new chat to get started")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            createNewChat()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("New Chat")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    @ViewBuilder
    private func splitChatView(conversation: Conversation?) -> some View {
        VStack(spacing: 0) {
            // Toolbar for split view with modern styling
            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        splitConversation = nil
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 32, height: 32)

                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                }
                .buttonStyle(.plain)
                .help("Close Split View")

                Spacer()

                if let conversation = conversation {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.split.2x1.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)

                        Text(conversation.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.04))
                    )
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)

            Divider()

            // Split chat content - independent instance with separate pipes
            if let conversation = conversation {
                ChatView(
                    conversationId: conversation.id,
                    conversationManager: conversationManager
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
                let exporter = ConversationExporter()
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

enum SidebarTab {
    case chats
    case search
    case settings
}

enum SidebarPosition: String, Codable {
    case left
    case right
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
            }

            HStack(spacing: 6) {
                if conversation.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                }

                Text(conversation.lastUsedAt, style: .relative)
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

                    Image(systemName: conversation.isArchived ? "archive.fill" : "archive")
                        .foregroundStyle(conversation.isArchived ? Color(hex: "00976d") : .secondary)
                        .font(.system(size: 12, weight: .medium))
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
