import SwiftUI

// MARK: - Animated Background

/// A subtle animated background with floating shapes for empty states
struct AnimatedBackgroundView: View {
    @State private var animationPhase: Double = 0

    private let shapes: [FloatingShape] = (0..<12).map { _ in
        FloatingShape(
            size: CGFloat.random(in: 20...80),
            position: CGPoint(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1)
            ),
            opacity: Double.random(in: 0.02...0.06),
            speed: Double.random(in: 0.3...0.8)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(shapes.enumerated()), id: \.offset) { index, shape in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ThemeColors.accent.opacity(shape.opacity),
                                    ThemeColors.accent.opacity(shape.opacity * 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: shape.size, height: shape.size)
                        .blur(radius: shape.size * 0.3)
                        .position(
                            x: geometry.size.width * shape.position.x + sin(animationPhase * shape.speed + Double(index)) * 30,
                            y: geometry.size.height * shape.position.y + cos(animationPhase * shape.speed + Double(index)) * 30
                        )
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
    }
}

private struct FloatingShape {
    let size: CGFloat
    let position: CGPoint
    let opacity: Double
    let speed: Double
}

// MARK: - Gradient Background

/// A subtle animated gradient for welcome screens
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                ThemeColors.darkBase,
                ThemeColors.darkSurface.opacity(0.8),
                ThemeColors.accent.opacity(0.05),
                ThemeColors.darkBase
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Large Symbol Illustration

/// A large SF Symbol with gradient and optional animation
struct SymbolIllustration: View {
    let symbol: String
    let size: CGFloat
    var color: Color = ThemeColors.accent
    var secondarySymbol: String? = nil
    var animate: Bool = false

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: size * 1.8, height: size * 1.8)
                .blur(radius: size * 0.3)

            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.15),
                            color.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)

            // Main symbol
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(animate && isAnimating ? 1.05 : 1.0)
                .rotationEffect(animate && isAnimating ? .degrees(3) : .degrees(0))

            // Secondary symbol (optional, positioned to the side)
            if let secondary = secondarySymbol {
                Image(systemName: secondary)
                    .font(.system(size: size * 0.35, weight: .medium))
                    .foregroundStyle(color.opacity(0.6))
                    .offset(x: size * 0.5, y: -size * 0.4)
                    .scaleEffect(animate && isAnimating ? 1.1 : 1.0)
            }
        }
        .onAppear {
            if animate {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
}

// MARK: - Empty Conversation State

/// Shown when a conversation has no messages yet
struct EmptyConversationView: View {
    let conversationTitle: String
    let modelName: String
    let onSendPrompt: (String) -> Void

    private let tryPrompts = [
        ("lightbulb.fill", "Try asking about...", "What are the best practices for..."),
        ("at", "You can @mention files", "@file.swift to include code context"),
        ("slash.circle", "Use slash commands", "/help to see available commands"),
        ("doc.on.clipboard", "Share code snippets", "Paste code and ask questions")
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Symbol illustration
            SymbolIllustration(
                symbol: "bubble.left.and.text.bubble.right",
                size: 56,
                secondarySymbol: "sparkles",
                animate: true
            )

            // Title and model info
            VStack(spacing: 8) {
                Text(conversationTitle.isEmpty ? "New Conversation" : conversationTitle)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(ThemeColors.textPrimary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(ThemeColors.accent)
                        .frame(width: 6, height: 6)

                    Text(modelName.isEmpty ? "Ready to chat" : "Using \(modelName)")
                        .font(.system(size: 13))
                        .foregroundStyle(ThemeColors.textSecondary)
                }
            }

            // Helpful hints
            VStack(spacing: 12) {
                ForEach(Array(tryPrompts.enumerated()), id: \.offset) { index, prompt in
                    EmptyStateHintRow(
                        icon: prompt.0,
                        title: prompt.1,
                        subtitle: prompt.2,
                        delay: Double(index) * 0.1
                    )
                }
            }
            .frame(maxWidth: 380)

            // Keyboard shortcuts
            HStack(spacing: 20) {
                KeyboardShortcutHint(keys: ["Return"], label: "Send")
                KeyboardShortcutHint(keys: ["Shift", "Return"], label: "New line")
                KeyboardShortcutHint(keys: ["K"], label: "Commands", hasCommand: true)
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

struct EmptyStateHintRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let delay: Double

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ThemeColors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ThemeColors.textPrimary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(ThemeColors.textMuted)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ThemeColors.darkSurface.opacity(0.5))
        .cornerRadius(10)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                isVisible = true
            }
        }
    }
}

struct KeyboardShortcutHint: View {
    let keys: [String]
    let label: String
    var hasCommand: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                if hasCommand {
                    Text("\u{2318}")
                        .font(.system(size: 10))
                }
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
            }
            .foregroundStyle(ThemeColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(ThemeColors.darkSurface)
            .cornerRadius(4)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(ThemeColors.textMuted)
        }
    }
}

// MARK: - Empty Project State

/// Shown when no projects exist in the sidebar
struct EmptyProjectsView: View {
    let onCreateProject: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 20) {
            // Illustration
            SymbolIllustration(
                symbol: "folder.badge.plus",
                size: 44,
                color: ThemeColors.accent
            )

            VStack(spacing: 8) {
                Text("Organize your work")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ThemeColors.textPrimary)

                Text("Projects group related conversations\nwith shared context and memory")
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button(action: onCreateProject) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))

                    Text("Create your first project")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ThemeColors.accent)
                )
                .scaleEffect(isHovered ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }
}

// MARK: - Empty Search Results

/// Shown when a search returns no results
struct EmptySearchResultsView: View {
    let searchQuery: String
    let onClearSearch: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Illustration
            ZStack {
                Circle()
                    .fill(ThemeColors.darkSurface)
                    .frame(width: 72, height: 72)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(ThemeColors.textMuted)

                // "X" overlay
                Circle()
                    .stroke(ThemeColors.textMuted.opacity(0.3), lineWidth: 2)
                    .frame(width: 72, height: 72)

                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ThemeColors.textMuted)
                    .offset(x: 20, y: 20)
            }

            VStack(spacing: 8) {
                Text("No results found")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ThemeColors.textPrimary)

                Text("Nothing matches \"\(searchQuery)\"")
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColors.textSecondary)
            }

            // Suggestions
            VStack(alignment: .leading, spacing: 8) {
                Text("Try:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ThemeColors.textMuted)

                VStack(alignment: .leading, spacing: 4) {
                    SearchSuggestionRow(text: "Using different keywords")
                    SearchSuggestionRow(text: "Checking for typos")
                    SearchSuggestionRow(text: "Using fewer search terms")
                }
            }
            .padding(12)
            .background(ThemeColors.darkSurface.opacity(0.5))
            .cornerRadius(8)

            Button(action: onClearSearch) {
                Text("Clear search")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ThemeColors.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }
}

struct SearchSuggestionRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ThemeColors.textMuted)
                .frame(width: 4, height: 4)

            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(ThemeColors.textSecondary)
        }
    }
}

// MARK: - Empty Extensions State (Discover)

/// Shown in the Extensions browse tab when no extensions match
struct DiscoverExtensionsView: View {
    let onBrowseCategory: (ExtensionCategory) -> Void

    private let featuredCategories: [(ExtensionCategory, String)] = [
        (.productivity, "Boost your workflow"),
        (.development, "Code smarter"),
        (.data, "Connect your data"),
        (.ai, "Enhance AI capabilities")
    ]

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                SymbolIllustration(
                    symbol: "puzzlepiece.extension.fill",
                    size: 48,
                    color: ThemeColors.accent,
                    secondarySymbol: "sparkle",
                    animate: true
                )

                Text("Discover Extensions")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ThemeColors.textPrimary)

                Text("Extend Vaizor with powerful MCP servers")
                    .font(.system(size: 13))
                    .foregroundStyle(ThemeColors.textSecondary)
            }

            // Category quick links
            VStack(spacing: 12) {
                Text("Browse by category")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ThemeColors.textMuted)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(featuredCategories, id: \.0) { category, tagline in
                        CategoryQuickLink(
                            category: category,
                            tagline: tagline,
                            onTap: { onBrowseCategory(category) }
                        )
                    }
                }
            }
            .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct CategoryQuickLink: View {
    let category: ExtensionCategory
    let tagline: String
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(category.color)

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(ThemeColors.textMuted)
                        .opacity(isHovered ? 1 : 0)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ThemeColors.textPrimary)

                    Text(tagline)
                        .font(.system(size: 10))
                        .foregroundStyle(ThemeColors.textMuted)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? ThemeColors.hoverBackground : ThemeColors.darkSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ThemeColors.darkBorder, lineWidth: 1)
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

// MARK: - Loading States

/// A skeleton placeholder for loading conversations
struct ConversationSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar skeleton
            Circle()
                .fill(skeletonGradient)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 6) {
                // Title skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 140, height: 12)

                // Subtitle skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 200, height: 10)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private var skeletonGradient: LinearGradient {
        LinearGradient(
            colors: [
                ThemeColors.skeletonBase,
                isAnimating ? ThemeColors.skeletonHighlight : ThemeColors.skeletonBase,
                ThemeColors.skeletonBase
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// Loading state with message for connecting to services
struct ConnectingStateView: View {
    let serviceName: String
    let statusMessage: String
    var showProgress: Bool = true

    @State private var dotCount = 0

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(ThemeColors.accent.opacity(0.1))
                    .frame(width: 60, height: 60)

                if showProgress {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(ThemeColors.accent)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 24))
                        .foregroundStyle(ThemeColors.accent)
                }
            }

            VStack(spacing: 4) {
                Text("Connecting to \(serviceName)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ThemeColors.textPrimary)

                Text(statusMessage + String(repeating: ".", count: dotCount))
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColors.textSecondary)
                    .frame(width: 200, alignment: .center)
            }
        }
        .padding(24)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

/// Browser loading state
struct BrowserLoadingView: View {
    let url: String
    let progress: Double

    var body: some View {
        VStack(spacing: 16) {
            // Globe icon with loading ring
            ZStack {
                Circle()
                    .stroke(ThemeColors.darkBorder, lineWidth: 3)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ThemeColors.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "globe")
                    .font(.system(size: 22))
                    .foregroundStyle(ThemeColors.accent)
            }

            VStack(spacing: 6) {
                Text("Loading page...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ThemeColors.textPrimary)

                Text(url)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ThemeColors.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 280)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ThemeColors.darkBorder)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(ThemeColors.accent)
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(width: 200, height: 4)
        }
        .padding(32)
    }
}

// MARK: - Error State

/// A friendly error state with retry option
struct ErrorStateView: View {
    let title: String
    let message: String
    let icon: String
    let retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(ThemeColors.error.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(ThemeColors.error)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ThemeColors.textPrimary)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            if let retry = retryAction {
                Button(action: retry) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))

                        Text("Try again")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(ThemeColors.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ThemeColors.accent, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
    }
}

// MARK: - Previews

#Preview("Empty Conversation") {
    EmptyConversationView(
        conversationTitle: "New Chat",
        modelName: "GPT-4o",
        onSendPrompt: { _ in }
    )
    .frame(width: 600, height: 500)
    .background(ThemeColors.darkBase)
}

#Preview("Empty Projects") {
    EmptyProjectsView(onCreateProject: {})
        .frame(width: 280)
        .background(ThemeColors.darkBase)
}

#Preview("Empty Search") {
    EmptySearchResultsView(
        searchQuery: "nonexistent",
        onClearSearch: {}
    )
    .frame(width: 350)
    .background(ThemeColors.darkBase)
}

#Preview("Discover Extensions") {
    DiscoverExtensionsView(onBrowseCategory: { _ in })
        .frame(width: 500, height: 500)
        .background(ThemeColors.darkBase)
}

#Preview("Loading States") {
    VStack(spacing: 40) {
        ConnectingStateView(
            serviceName: "MCP Server",
            statusMessage: "Initializing"
        )

        BrowserLoadingView(
            url: "https://example.com/page",
            progress: 0.65
        )
    }
    .frame(width: 400, height: 500)
    .background(ThemeColors.darkBase)
}

// MARK: - Chat Empty State Illustration

struct ChatEmptyStateIllustration: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(ThemeColors.accent.opacity(0.06))
                .frame(width: 100, height: 100)
                .blur(radius: 20)

            // Orbiting chat bubbles
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index == 0 ? "bubble.left.fill" : (index == 1 ? "bubble.right.fill" : "sparkle"))
                    .font(.system(size: index == 2 ? 10 : 14))
                    .foregroundStyle(ThemeColors.accent.opacity(0.3 + Double(index) * 0.1))
                    .offset(
                        x: cos(Double(index) * 2.1 + (isAnimating ? .pi * 2 : 0)) * 35,
                        y: sin(Double(index) * 2.1 + (isAnimating ? .pi * 2 : 0)) * 35
                    )
            }

            // Main icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ThemeColors.accent.opacity(0.18),
                                ThemeColors.accent.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ThemeColors.accent, ThemeColors.accentLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(isAnimating ? 1.03 : 1.0)
        }
        .frame(width: 120, height: 120)
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Chat Hint Row

struct ChatHintRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    @State private var isVisible = false

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
                    .foregroundStyle(ThemeColors.textPrimary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(ThemeColors.textMuted)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ThemeColors.darkSurface.opacity(0.6))
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Empty State Keyboard Hint

struct EmptyStateKeyboardHint: View {
    let keys: [String]
    let label: String
    var hasCommand: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 2) {
                if hasCommand {
                    Text("\u{2318}")
                        .font(.system(size: 10))
                }
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
            }
            .foregroundStyle(ThemeColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(ThemeColors.darkSurface)
            .cornerRadius(4)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(ThemeColors.textMuted)
        }
    }
}

// MARK: - Artifact Empty State Illustration

struct ArtifactEmptyStateIllustration: View {
    @State private var isAnimating = false
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(ThemeColors.codeAccent.opacity(0.06))
                .frame(width: 90, height: 90)
                .blur(radius: 15)

            // Floating shapes around the cube
            ForEach(0..<4, id: \.self) { index in
                floatingShape(for: index)
            }

            // Main cube icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                ThemeColors.codeAccent.opacity(0.15),
                                ThemeColors.codeAccent.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "cube.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ThemeColors.codeAccent, ThemeColors.codeAccent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .offset(y: floatOffset)
        }
        .frame(width: 100, height: 100)
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                floatOffset = -5
            }
        }
    }

    @ViewBuilder
    private func floatingShape(for index: Int) -> some View {
        let icons = ["rectangle.fill", "circle.fill", "triangle.fill", "diamond.fill"]
        let angle: Double = Double(index) * .pi / 2 + .pi / 4 + (isAnimating ? .pi * 2 : 0)
        let opacity: Double = 0.25 + Double(index) * 0.05

        Image(systemName: icons[index])
            .font(.system(size: 10))
            .foregroundStyle(ThemeColors.codeAccent.opacity(opacity))
            .offset(
                x: cos(angle) * 32,
                y: sin(angle) * 32
            )
    }
}

// MARK: - Artifact Example Row

struct ArtifactExampleRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(ThemeColors.codeAccent.opacity(0.7))
                .frame(width: 20)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(ThemeColors.textMuted)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Previews

#Preview("Error State") {
    ErrorStateView(
        title: "Connection failed",
        message: "Unable to reach the server. Please check your internet connection.",
        icon: "wifi.exclamationmark",
        retryAction: {}
    )
    .frame(width: 350)
    .background(ThemeColors.darkBase)
}

#Preview("Chat Empty State") {
    VStack(spacing: 24) {
        ChatEmptyStateIllustration()

        VStack(spacing: 10) {
            ChatHintRow(
                icon: "lightbulb.fill",
                title: "Ask anything",
                subtitle: "Questions, ideas, code help",
                color: ThemeColors.warning
            )
            ChatHintRow(
                icon: "at",
                title: "Mention files with @",
                subtitle: "@filename.swift to include context",
                color: ThemeColors.info
            )
        }
        .frame(maxWidth: 350)
    }
    .padding(40)
    .background(ThemeColors.darkBase)
}
