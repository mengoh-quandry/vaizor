import SwiftUI
import WebKit

// MARK: - Browser Panel View

/// Main browser panel view with full browser chrome and AI integration
struct BrowserView: View {
    @ObservedObject var browserService: BrowserService
    let onClose: () -> Void
    let onSendToAI: ((NSImage?, PageContent?) -> Void)?

    @State private var urlText: String = ""
    @State private var isURLFieldFocused: Bool = false
    @State private var showTabsPopover: Bool = false
    @State private var showSecurityInfo: Bool = false
    @State private var contentOpacity: Double = 0
    @State private var headerOffset: CGFloat = -20
    @State private var panelWidth: CGFloat = 600

    init(
        browserService: BrowserService = .shared,
        onClose: @escaping () -> Void,
        onSendToAI: ((NSImage?, PageContent?) -> Void)? = nil
    ) {
        self.browserService = browserService
        self.onClose = onClose
        self.onSendToAI = onSendToAI
    }

    var body: some View {
        HStack(spacing: 0) {
            // Resize handle on left edge
            resizeHandle

            // Main panel content
            VStack(spacing: 0) {
                // Browser chrome header
                browserHeader
                    .offset(y: headerOffset)

                Divider()

                // Tab bar
                tabBar

                Divider()

                // Web content
                webContent
                    .opacity(contentOpacity)

                // Status bar
                statusBar
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 400, idealWidth: panelWidth, maxWidth: 1000)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                contentOpacity = 1
                headerOffset = 0
            }

            if let currentURL = browserService.currentURL {
                urlText = currentURL.absoluteString
            }
        }
        .onChange(of: browserService.currentURL) { _, newURL in
            if let url = newURL {
                urlText = url.absoluteString
            }
        }
        .alert("Security Warning", isPresented: .constant(browserService.securityWarning != nil)) {
            Button("OK") {
                browserService.securityWarning = nil
            }
        } message: {
            Text(browserService.securityWarning ?? "")
        }
        .sheet(item: $browserService.pendingConfirmation) { confirmation in
            ConfirmationSheet(
                confirmation: confirmation,
                onApprove: { browserService.approveConfirmation() },
                onDeny: { browserService.denyConfirmation() }
            )
        }
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1)
                    .padding(.vertical, 8),
                alignment: .leading
            )
    }

    // MARK: - Browser Header

    private var browserHeader: some View {
        HStack(spacing: 12) {
            // Navigation buttons
            HStack(spacing: 4) {
                Button {
                    browserService.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(browserService.canGoBack ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!browserService.canGoBack)
                .help("Go Back")

                Button {
                    browserService.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(browserService.canGoForward ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!browserService.canGoForward)
                .help("Go Forward")

                Button {
                    if browserService.isLoading {
                        browserService.stopLoading()
                    } else {
                        browserService.refresh()
                    }
                } label: {
                    Image(systemName: browserService.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help(browserService.isLoading ? "Stop Loading" : "Refresh")
            }

            // URL bar
            HStack(spacing: 8) {
                // Security indicator
                securityIndicator

                TextField("Enter URL or search...", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        Task {
                            await browserService.navigate(to: urlText)
                        }
                    }

                // Loading indicator
                if browserService.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isURLFieldFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )

            // Action buttons
            HStack(spacing: 8) {
                // Send to AI button
                Button {
                    sendToAI()
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ThemeColors.accent)
                }
                .buttonStyle(.plain)
                .help("Send page to AI for analysis")

                // Screenshot button
                Button {
                    takeScreenshot()
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Take screenshot")

                // Close button
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        contentOpacity = 0
                        headerOffset = -20
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onClose()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .help("Close browser (Esc)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - Security Indicator

    @ViewBuilder
    private var securityIndicator: some View {
        if let url = browserService.currentURL {
            Button {
                showSecurityInfo.toggle()
            } label: {
                Image(systemName: url.scheme == "https" ? "lock.fill" : "lock.open")
                    .font(.system(size: 11))
                    .foregroundStyle(url.scheme == "https" ? ThemeColors.success : ThemeColors.warning)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSecurityInfo) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: url.scheme == "https" ? "lock.fill" : "lock.open")
                            .foregroundStyle(url.scheme == "https" ? ThemeColors.success : ThemeColors.warning)
                        Text(url.scheme == "https" ? "Secure Connection" : "Not Secure")
                            .font(.system(size: 13, weight: .medium))
                    }

                    if let host = url.host {
                        Text(host)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Text(url.scheme == "https"
                        ? "Your connection to this site is encrypted."
                        : "Your connection to this site is not encrypted.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: 200)
                }
                .padding()
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(browserService.tabs.enumerated()), id: \.element.id) { index, tab in
                    TabItemView(
                        tab: tab,
                        isActive: index == browserService.activeTabIndex,
                        onSelect: { browserService.switchToTab(at: index) },
                        onClose: { browserService.closeTab(at: index) }
                    )
                }

                // New tab button
                Button {
                    browserService.createNewTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("New Tab")
                .padding(.leading, 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Web Content

    private var webContent: some View {
        ZStack {
            // WebView
            if let webView = browserService.currentWebView {
                BrowserWebViewRepresentable(webView: webView)
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)

                    Text("Enter a URL to get started")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)

                    // Quick links
                    HStack(spacing: 12) {
                        QuickLinkButton(title: "Google", url: "https://google.com") {
                            Task { await browserService.navigate(to: "https://google.com") }
                        }
                        QuickLinkButton(title: "GitHub", url: "https://github.com") {
                            Task { await browserService.navigate(to: "https://github.com") }
                        }
                        QuickLinkButton(title: "Stack Overflow", url: "https://stackoverflow.com") {
                            Task { await browserService.navigate(to: "https://stackoverflow.com") }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }

            // Error overlay
            if let error = browserService.error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(ThemeColors.warning)

                    Text("Page Load Error")
                        .font(.system(size: 15, weight: .medium))

                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)

                    Button("Try Again") {
                        browserService.error = nil
                        browserService.refresh()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(32)
                .background(.regularMaterial)
                .cornerRadius(12)
            }

            // Loading progress bar
            if browserService.isLoading {
                VStack {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(ThemeColors.accent)
                            .frame(width: geometry.size.width * browserService.loadProgress, height: 2)
                    }
                    .frame(height: 2)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            if let url = browserService.currentURL {
                Text(url.host ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Page info
            if let content = browserService.pageContent {
                HStack(spacing: 12) {
                    Label("\(content.links.count) links", systemImage: "link")
                    Label("\(content.images.count) images", systemImage: "photo")
                    Label("\(content.forms.count) forms", systemImage: "doc.text")
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Actions

    private func sendToAI() {
        Task {
            // Extract page content
            let content = await browserService.extractPageContent()

            // Take screenshot
            let screenshot = await browserService.takeScreenshot()

            // Call the callback
            onSendToAI?(screenshot, content)
        }
    }

    private func takeScreenshot() {
        Task {
            if let screenshot = await browserService.takeScreenshot() {
                // Copy to clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([screenshot])

                // Post notification for toast
                NotificationCenter.default.post(
                    name: .showUnderConstructionToast,
                    object: "Screenshot copied to clipboard"
                )
            }
        }
    }
}

// MARK: - Tab Item View

struct TabItemView: View {
    let tab: BrowserTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // Favicon
            if let favicon = tab.favicon {
                Image(nsImage: favicon)
                    .resizable()
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Title
            Text(tab.title)
                .font(.system(size: 11))
                .lineLimit(1)
                .frame(maxWidth: 120)

            // Loading indicator
            if tab.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }

            // Close button (visible on hover or active)
            if isHovered || isActive {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 14, height: 14)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.primary.opacity(0.08) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
        )
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Quick Link Button

struct QuickLinkButton: View {
    let title: String
    let url: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80, height: 60)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WebView Representable

struct BrowserWebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // WebView is managed externally by BrowserService
    }
}

// MARK: - Confirmation Sheet

struct ConfirmationSheet: View {
    let confirmation: BrowserActionConfirmation
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(ThemeColors.warning.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: actionIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(ThemeColors.warning)
            }

            // Title
            Text("Confirm Browser Action")
                .font(.system(size: 17, weight: .semibold))

            // Description
            VStack(spacing: 8) {
                Text("The AI wants to perform this action:")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(confirmation.action.rawValue.capitalized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ThemeColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ThemeColors.accent.opacity(0.15))
                        .cornerRadius(4)

                    Text(confirmation.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                .padding()
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
            }

            // Warning
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColors.warning)

                Text("Only approve actions you trust")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Deny") {
                    onDeny()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Approve") {
                    onApprove()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(width: 400)
    }

    private var actionIcon: String {
        switch confirmation.action {
        case .navigate: return "arrow.right.circle"
        case .click: return "cursorarrow.click"
        case .type: return "keyboard"
        case .submit: return "paperplane"
        case .download: return "arrow.down.circle"
        case .screenshot: return "camera"
        }
    }
}

// MARK: - Browser Button for Toolbar

struct BrowserToolbarButton: View {
    @ObservedObject var browserService: BrowserService = .shared
    @Binding var showBrowser: Bool

    var body: some View {
        Button {
            showBrowser.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundStyle(showBrowser ? ThemeColors.accent : .secondary)

                if browserService.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .buttonStyle(.plain)
        .help("AI Browser")
    }
}

// MARK: - Compact Browser Summary

struct BrowserSummaryView: View {
    @ObservedObject var browserService: BrowserService = .shared

    var body: some View {
        if let content = browserService.pageContent {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundStyle(ThemeColors.accent)

                    Text(content.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Spacer()
                }

                if let description = content.metadata.description {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Label("\(content.links.count) links", systemImage: "link")
                    Label("\(content.images.count) images", systemImage: "photo")
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(ThemeColors.darkSurface)
            .cornerRadius(8)
        }
    }
}

// MARK: - Preview

#Preview {
    HStack {
        Color.gray.opacity(0.1)
            .frame(width: 400)

        BrowserView(
            browserService: .shared,
            onClose: {},
            onSendToAI: { _, _ in }
        )
    }
    .frame(width: 1000, height: 700)
}
