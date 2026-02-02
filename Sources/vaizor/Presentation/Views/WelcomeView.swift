import SwiftUI
import AppKit

struct WelcomeView: View {
    let onNewChat: () -> Void
    let onSendMessage: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var messageText: String = ""
    @State private var hoveredSuggestionIndex: Int? = nil
    @State private var showContent = false
    @FocusState private var isInputFocused: Bool

    // Adaptive colors helper
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    private let suggestions: [(icon: String, title: String, subtitle: String, prompt: String, color: Color)] = [
        ("lightbulb.max.fill", "Brainstorm ideas", "Generate creative concepts and explore possibilities", "Help me brainstorm ideas for ", ThemeColors.warning),
        ("doc.richtext", "Write content", "Draft emails, articles, documentation, or code", "Help me write ", ThemeColors.info),
        ("brain.head.profile", "Explain concepts", "Get clear explanations and in-depth analysis", "Explain ", ThemeColors.codeAccent),
        ("wrench.and.screwdriver.fill", "Debug code", "Find issues and optimize your code", "Help me debug this code: ", ThemeColors.error),
        ("chart.line.uptrend.xyaxis", "Analyze data", "Understand patterns and derive insights", "Analyze this data: ", ThemeColors.accent),
        ("translate", "Translate text", "Convert between languages accurately", "Translate this to ", ThemeColors.info)
    ]

    private let quickActions: [(icon: String, title: String, action: QuickAction)] = [
        ("plus.message", "New Chat", .newChat),
        ("folder", "Open Project", .openProject),
        ("puzzlepiece.extension", "Extensions", .browseExtensions)
    ]

    enum QuickAction {
        case newChat, openProject, browseExtensions
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated background
                colors.background.ignoresSafeArea()
                AnimatedBackgroundView()

                // Main content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: max(40, geometry.size.height * 0.08))

                        // Hero section
                        heroSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)

                        Spacer()
                            .frame(height: 40)

                        // Suggestion cards
                        suggestionGrid(width: geometry.size.width)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 30)

                        Spacer()
                            .frame(height: 32)

                        // Quick actions
                        quickActionsBar
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)

                        Spacer()
                            .frame(height: max(40, geometry.size.height * 0.05))
                    }
                    .frame(minHeight: geometry.size.height - 140) // Account for input bar
                }

                // Fixed input bar at bottom
                VStack {
                    Spacer()

                    VStack(spacing: 0) {
                        // Chat input bar
                        chatInputBar
                            .frame(maxWidth: 720)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)

                        // Keyboard shortcuts hint
                        shortcutsHint
                            .padding(.bottom, 16)
                    }
                    .background(
                        LinearGradient(
                            colors: [
                                colors.background.opacity(0),
                                colors.background.opacity(0.9),
                                colors.background
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 140)
                        .offset(y: -40)
                        .allowsHitTesting(false)
                    )
                }
            }
        }
        .onAppear {
            isInputFocused = true
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                showContent = true
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 20) {
            // Animated logo with app icon
            ZStack {
                // Outer glow
                Circle()
                    .fill(colors.accent.opacity(0.08))
                    .frame(width: 120, height: 120)
                    .blur(radius: 25)

                // App icon
                if let iconImage = loadAppIcon() {
                    Image(nsImage: iconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .cornerRadius(18)
                        .shadow(color: colors.accent.opacity(0.3), radius: 12, y: 4)
                } else {
                    // Fallback animated icon
                    ZStack {
                        // Inner circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colors.accent.opacity(0.2),
                                        colors.accent.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        // Stylized V logo
                        Image(systemName: "v.circle.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [colors.accent, colors.accentLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }

            // Headline
            VStack(spacing: 8) {
                Text("What can I help you with?")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(colors.textPrimary)

                Text("Ask anything, create content, analyze data, or write code")
                    .font(.system(size: 15))
                    .foregroundStyle(colors.textSecondary)
            }
        }
        .animation(.easeOut(duration: 0.8), value: showContent)
    }

    private func loadAppIcon() -> NSImage? {
        // Try to load from bundle resources
        if let iconPath = Bundle.main.path(forResource: "Vaizor", ofType: "png"),
           let image = NSImage(contentsOfFile: iconPath) {
            return image
        }

        // Try the icns file
        if let icnsPath = Bundle.main.path(forResource: "Vaizor", ofType: "icns"),
           let image = NSImage(contentsOfFile: icnsPath) {
            return image
        }

        // Try app icon from bundle
        if let appIconName = Bundle.main.infoDictionary?["CFBundleIconFile"] as? String {
            let iconName = appIconName.hasSuffix(".icns") ? String(appIconName.dropLast(5)) : appIconName
            if let iconPath = Bundle.main.path(forResource: iconName, ofType: "icns"),
               let image = NSImage(contentsOfFile: iconPath) {
                return image
            }
        }

        return NSApp.applicationIconImage
    }

    // MARK: - Suggestion Grid

    @ViewBuilder
    private func suggestionGrid(width: CGFloat) -> some View {
        let columns = width > 700 ? 3 : (width > 500 ? 2 : 1)
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)

        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(Array(suggestions.enumerated()), id: \.element.title) { index, suggestion in
                EnhancedSuggestionCard(
                    icon: suggestion.icon,
                    title: suggestion.title,
                    subtitle: suggestion.subtitle,
                    accentColor: suggestion.color,
                    isHovered: hoveredSuggestionIndex == index,
                    onTap: {
                        messageText = suggestion.prompt
                        isInputFocused = true
                    },
                    onHover: { isHovered in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredSuggestionIndex = isHovered ? index : nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 900)
    }

    // MARK: - Quick Actions

    private var quickActionsBar: some View {
        HStack(spacing: 16) {
            ForEach(quickActions, id: \.title) { action in
                QuickActionButton(
                    icon: action.icon,
                    title: action.title,
                    action: {
                        handleQuickAction(action.action)
                    }
                )
            }
        }
    }

    private func handleQuickAction(_ action: QuickAction) {
        switch action {
        case .newChat:
            onNewChat()
        case .openProject:
            NotificationCenter.default.post(name: .showProjectPanel, object: nil)
        case .browseExtensions:
            NotificationCenter.default.post(name: .openSettings, object: "extensions")
        }
    }

    // MARK: - Chat Input Bar

    private var chatInputBar: some View {
        HStack(spacing: 0) {
            // Attachment button
            Button {
                NotificationCenter.default.post(
                    name: .showUnderConstructionToast,
                    object: "Attachments"
                )
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(colors.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 14)

            // Text field
            TextField("Message Vaizor...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(colors.textPrimary)
                .focused($isInputFocused)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .onSubmit {
                    sendMessage()
                }

            // Send button
            Button {
                sendMessage()
            } label: {
                ZStack {
                    Circle()
                        .fill(messageText.isEmpty ? colors.border : colors.accent)
                        .frame(width: 32, height: 32)

                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(messageText.isEmpty ? colors.textMuted : .white)
                }
            }
            .buttonStyle(.plain)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.trailing, 8)
        }
        .background(colors.surface)
        .cornerRadius(26)
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(
                    isInputFocused ? colors.accent.opacity(0.5) : colors.border,
                    lineWidth: isInputFocused ? 1.5 : 1
                )
        )
        .shadow(color: colors.shadowMedium, radius: colorScheme == .light ? 12 : 8, y: 4)
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSendMessage(trimmed)
        messageText = ""
    }

    // MARK: - Shortcuts Hint

    private var shortcutsHint: some View {
        HStack(spacing: 20) {
            ShortcutPill(keys: ["\u{2318}", "N"], label: "New chat")
            ShortcutPill(keys: ["\u{2318}", ","], label: "Settings")
            ShortcutPill(keys: ["/"], label: "Commands")
            ShortcutPill(keys: ["@"], label: "Mention")
        }
    }
}

// MARK: - Enhanced Suggestion Card

struct EnhancedSuggestionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let isHovered: Bool
    let onTap: () -> Void
    let onHover: (Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Icon with colored background
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(isHovered ? 0.2 : 0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(accentColor)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(colors.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                // Arrow indicator
                HStack {
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(accentColor)
                        .opacity(isHovered ? 1 : 0)
                        .offset(x: isHovered ? 0 : -8)
                }
            }
            .padding(14)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isHovered ? colors.hoverBackground : colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isHovered ? accentColor.opacity(0.3) : colors.border,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: isHovered ? accentColor.opacity(colorScheme == .light ? 0.15 : 0.1) : (colorScheme == .light ? colors.shadowLight : .clear),
                radius: colorScheme == .light ? 10 : 8,
                y: colorScheme == .light ? 3 : 4
            )
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))

                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isHovered ? colors.accent : colors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isHovered ? colors.accent.opacity(0.1) : colors.surface)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isHovered ? colors.accent.opacity(0.3) : colors.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Shortcut Pill

struct ShortcutPill: View {
    let keys: [String]
    let label: String

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 10, weight: .medium, design: key.count > 1 ? .default : .monospaced))
                }
            }
            .foregroundStyle(colors.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(colors.surface)
            .cornerRadius(5)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(colors.textMuted)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showProjectPanel = Notification.Name("showProjectPanel")
}

// MARK: - Preview

#Preview {
    WelcomeView(onNewChat: {}, onSendMessage: { _ in })
        .frame(width: 900, height: 700)
}
