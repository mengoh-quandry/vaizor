import SwiftUI
import AppKit

struct ThinkingIndicator: View {
    let status: String
    let provider: LLMProvider?

    init(status: String, provider: LLMProvider? = nil) {
        self.status = status
        self.provider = provider
    }

    @State private var glowPhase: Double = 0
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    private var thinkingColor: Color { colors.accent }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Avatar with pulse animation - using Vaizor icon
            avatarWithGlow

            VStack(alignment: .leading, spacing: 8) {
                // Premium animated typing bubble
                typingBubble

                // Status text with smooth transition
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .contentTransition(.numericText())
                    .animation(VaizorAnimations.quickBounce, value: status)
            }

            Spacer(minLength: 60)
        }
        // Appear animation
        .scaleEffect(hasAppeared || reduceMotion ? 1.0 : 0.95)
        .opacity(hasAppeared || reduceMotion ? 1.0 : 0)
        .offset(y: hasAppeared || reduceMotion ? 0 : 8)
        .onAppear {
            guard !reduceMotion else {
                hasAppeared = true
                return
            }
            withAnimation(VaizorAnimations.messageAppear) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Avatar with Animated Glow Ring

    private var avatarWithGlow: some View {
        // Tahoe-style: Refined avatar with subtle pulse
        ZStack {
            // Animated glow ring - more subtle
            if !reduceMotion {
                Circle()
                    .stroke(thinkingColor.opacity(0.25), lineWidth: 1.5)
                    .scaleEffect(1 + glowPhase * 0.12)
                    .opacity(1 - glowPhase)
                    .frame(width: 34, height: 34)
            }

            // Main avatar circle - cleaner gradient
            Circle()
                .fill(thinkingColor.opacity(0.18))
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(colors.border, lineWidth: 0.5)
                )

            // Icon - use provider icon if available, fallback to sparkles
            if let provider = provider {
                ProviderIconManager.icon(for: provider)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
            } else if let vaizorImage = loadVaizorIcon() {
                Image(nsImage: vaizorImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(thinkingColor)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.pulse)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                glowPhase = 1.0
            }
        }
    }

    // MARK: - Premium Typing Bubble

    private var typingBubble: some View {
        ZStack {
            // Subtle glow background
            if !reduceMotion {
                Capsule()
                    .fill(thinkingColor.opacity(0.15))
                    .blur(radius: 10)
                    .frame(width: 60, height: 32)
                    .opacity(0.5 + glowPhase * 0.3)
            }

            // Dots container
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    AnimatedTypingDot(
                        index: index,
                        color: thinkingColor
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(colors.surface)
                    .overlay(
                        Capsule()
                            .stroke(
                                thinkingColor.opacity(reduceMotion ? 0.2 : 0.3),
                                lineWidth: 1
                            )
                            .shadow(
                                color: thinkingColor.opacity(reduceMotion ? 0 : 0.2),
                                radius: 4
                            )
                    )
            )
        }
    }

    private func loadVaizorIcon() -> NSImage? {
        // Try Bundle resource loading first
        if let bundlePath = Bundle.main.path(forResource: "Vaizor", ofType: "png", inDirectory: "Resources/Icons") ??
                            Bundle.main.path(forResource: "Vaizor", ofType: "png") {
            return NSImage(contentsOfFile: bundlePath)
        }

        // Try direct file paths (for development)
        let fileManager = FileManager.default
        let possiblePaths = [
            Bundle.main.bundlePath + "/../../Resources/Icons/Vaizor.png",
            Bundle.main.bundlePath + "/Resources/Icons/Vaizor.png",
            Bundle.main.resourcePath.map { $0 + "/Resources/Icons/Vaizor.png" },
            Bundle.main.resourcePath.map { $0 + "/../../Resources/Icons/Vaizor.png" },
            "/Users/marcus/Downloads/vaizor/Resources/Icons/Vaizor.png"
        ].compactMap { $0 }

        for path in possiblePaths {
            guard fileManager.fileExists(atPath: path) else { continue }
            if let image = NSImage(contentsOfFile: path), image.isValid {
                return image
            }
        }

        return nil
    }
}

// MARK: - Animated Typing Dot

/// Individual typing dot with staggered bounce animation
struct AnimatedTypingDot: View {
    let index: Int
    let color: Color

    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.0 : 0.5)
            .offset(y: isAnimating ? -5 : 3)
            .opacity(isAnimating ? 1.0 : 0.3)
            .shadow(
                color: color.opacity(isAnimating ? 0.6 : 0.1),
                radius: isAnimating ? 4 : 1
            )
            .onAppear {
                guard !reduceMotion else {
                    isAnimating = true
                    return
                }

                // Staggered bounce animation - feels alive, not mechanical
                withAnimation(
                    .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.15)
                ) {
                    isAnimating = true
                }
            }
    }
}

/// Subtle indicator shown when context was enhanced for local models
struct ContextEnhancementIndicator: View {
    let details: String?
    @State private var isExpanded: Bool = false
    @State private var opacity: Double = 1.0

    private let enhancementColor = Color(hex: "6366f1") // Indigo

    var body: some View {
        HStack(spacing: 8) {
            // Icon with subtle glow
            ZStack {
                Circle()
                    .fill(enhancementColor.opacity(0.15))
                    .frame(width: 20, height: 20)

                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(enhancementColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Context Enhanced")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                if isExpanded, let details = details {
                    Text(details)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()

            if details != nil {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(enhancementColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(enhancementColor.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(opacity)
        .onAppear {
            // Auto-fade after a few seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.easeOut(duration: 1.0)) {
                    opacity = 0.6
                }
            }
        }
        .accessibilityLabel("Context enhanced for more accurate response")
    }
}

/// Compact inline indicator for context enhancement
struct ContextEnhancementBadge: View {
    let hasFreshData: Bool

    private let enhancementColor = Color(hex: "6366f1") // Indigo

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: hasFreshData ? "arrow.triangle.2.circlepath" : "clock")
                .font(.system(size: 9))

            Text(hasFreshData ? "Fresh data" : "Time-aware")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(enhancementColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(enhancementColor.opacity(0.1))
        )
        .accessibilityLabel(hasFreshData ? "Response includes fresh data from web search" : "Response is time-aware")
    }
}

struct LoadingIndicator: View {
    @State private var rotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14))
                .foregroundStyle(colors.textSecondary)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(
                        Animation.linear(duration: 1.0)
                            .repeatForever(autoreverses: false)
                    ) {
                        rotation = 360
                    }
                }

            Text("Loading...")
                .font(.caption)
                .foregroundStyle(colors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(colors.surface)
        .cornerRadius(12)
        .accessibilityLabel("Loading content")
    }
}

// MARK: - Skeleton UI Components

/// Shimmer effect modifier for skeleton loading states
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if !reduceMotion {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                colors.skeletonHighlight.opacity(0.4),
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                        .onAppear {
                            withAnimation(
                                Animation.linear(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                            ) {
                                phase = 1
                            }
                        }
                    }
                }
            )
            .mask(content)
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

/// A skeleton line placeholder for text content
struct SkeletonLine: View {
    let width: CGFloat
    let height: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    init(width: CGFloat = .infinity, height: CGFloat = 14) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(colors.skeletonBase)
            .frame(maxWidth: width == .infinity ? .infinity : width, minHeight: height, maxHeight: height)
            .shimmer()
    }
}

/// Skeleton view for a message bubble during loading
struct MessageSkeleton: View {
    let isUser: Bool
    let animationIndex: Int

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    init(isUser: Bool, animationIndex: Int = 0) {
        self.isUser = isUser
        self.animationIndex = animationIndex
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if isUser {
                Spacer(minLength: 60)
            }

            // Avatar skeleton
            if !isUser {
                Circle()
                    .fill(colors.skeletonBase)
                    .frame(width: 32, height: 32)
                    .shimmer()
            }

            // Content skeleton
            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonLine(width: isUser ? 200 : 280)
                    if !isUser {
                        SkeletonLine(width: 240)
                        SkeletonLine(width: 180)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isUser ? colors.userBubble : colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isUser ? colors.userBubbleBorder : Color.clear, lineWidth: 1)
                )

                // Timestamp skeleton
                SkeletonLine(width: 50, height: 10)
                    .padding(.horizontal, 4)
            }

            // User avatar skeleton
            if isUser {
                Circle()
                    .fill(colors.skeletonBase)
                    .frame(width: 32, height: 32)
                    .shimmer()
            }

            if !isUser {
                Spacer(minLength: 60)
            }
        }
        // Appear animation for skeleton
        .scaleEffect(hasAppeared || reduceMotion ? 1.0 : 0.95)
        .opacity(hasAppeared || reduceMotion ? 1.0 : 0)
        .offset(y: hasAppeared || reduceMotion ? 0 : 6)
        .onAppear {
            guard !reduceMotion else {
                hasAppeared = true
                return
            }
            let delay = VaizorAnimations.staggerDelay(for: animationIndex)
            withAnimation(VaizorAnimations.messageAppear.delay(delay)) {
                hasAppeared = true
            }
        }
        .accessibilityLabel("Loading message")
        .accessibilityHidden(true)
    }
}

/// Multiple skeleton messages for loading state
struct MessageListSkeleton: View {
    let count: Int

    init(count: Int = 3) {
        self.count = count
    }

    var body: some View {
        VStack(spacing: 20) {
            ForEach(0..<count, id: \.self) { index in
                MessageSkeleton(isUser: index % 2 == 0, animationIndex: index)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

/// Skeleton for code block loading
struct CodeBlockSkeleton: View {
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                SkeletonLine(width: 80, height: 20)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(colors.codeBlockHeaderBackground)

            // Code lines
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLine(width: 200)
                SkeletonLine(width: 280)
                SkeletonLine(width: 160)
                SkeletonLine(width: 240)
            }
            .padding(12)
            .background(colors.codeBlockBackground)
        }
        .cornerRadius(10)
    }
}
