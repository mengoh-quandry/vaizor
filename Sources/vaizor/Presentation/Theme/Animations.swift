import SwiftUI

// MARK: - Premium Animation Constants

/// Centralized animation timing and spring configurations for consistent premium feel
enum VaizorAnimations {
    // MARK: - Spring Configurations

    /// Standard spring for message appearances
    static let messageAppear = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// Quick bounce for interactive elements
    static let quickBounce = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Subtle spring for hover states
    static let subtleSpring = Animation.spring(response: 0.25, dampingFraction: 0.85)

    /// Panel slide animation
    static let panelSlide = Animation.spring(response: 0.35, dampingFraction: 0.82)

    /// Button press feedback
    static let buttonPress = Animation.spring(response: 0.2, dampingFraction: 0.65)

    // MARK: - Easing Animations

    /// Smooth fade for content transitions
    static let smoothFade = Animation.easeInOut(duration: 0.2)

    /// Background color transitions
    static let colorTransition = Animation.easeInOut(duration: 0.15)

    /// Content crossfade
    static let contentCrossfade = Animation.easeInOut(duration: 0.25)

    /// Scroll behavior
    static let smoothScroll = Animation.easeInOut(duration: 0.3)

    // MARK: - Stagger Delays

    /// Base delay between staggered items (in seconds)
    static let staggerBaseDelay: Double = 0.05

    /// Maximum stagger delay cap
    static let staggerMaxDelay: Double = 0.3

    /// Calculate stagger delay for an item at given index
    static func staggerDelay(for index: Int, base: Double = staggerBaseDelay) -> Double {
        min(Double(index) * base, staggerMaxDelay)
    }
}

// MARK: - Message Appear Animation Modifier

/// Applies premium appear animation to message bubbles
struct MessageAppearModifier: ViewModifier {
    let isAnimated: Bool
    let index: Int

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(hasAppeared || reduceMotion ? 1.0 : 0.95)
            .opacity(hasAppeared || reduceMotion ? 1.0 : 0)
            .offset(y: hasAppeared || reduceMotion ? 0 : 8)
            .onAppear {
                guard isAnimated && !reduceMotion else {
                    hasAppeared = true
                    return
                }

                let delay = VaizorAnimations.staggerDelay(for: index)
                withAnimation(VaizorAnimations.messageAppear.delay(delay)) {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    /// Applies premium message appear animation with stagger support
    func messageAppearAnimation(isAnimated: Bool = true, index: Int = 0) -> some View {
        modifier(MessageAppearModifier(isAnimated: isAnimated, index: index))
    }
}

// MARK: - Button Press Style

/// Premium button style with scale-down press effect
struct PremiumButtonStyle: ButtonStyle {
    let scaleAmount: CGFloat

    init(scaleAmount: CGFloat = 0.97) {
        self.scaleAmount = scaleAmount
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scaleAmount : 1.0)
            .animation(VaizorAnimations.buttonPress, value: configuration.isPressed)
    }
}

extension View {
    /// Applies premium press effect to a view
    func premiumPressEffect(scale: CGFloat = 0.97) -> some View {
        self.buttonStyle(PremiumButtonStyle(scaleAmount: scale))
    }
}

// MARK: - Hover Lift Effect Modifier

/// Adds subtle lift effect (shadow increase) on hover
struct HoverLiftModifier: ViewModifier {
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let baseRadius: CGFloat
    let hoverRadius: CGFloat
    let baseY: CGFloat
    let hoverY: CGFloat

    init(baseRadius: CGFloat = 2, hoverRadius: CGFloat = 8, baseY: CGFloat = 1, hoverY: CGFloat = 4) {
        self.baseRadius = baseRadius
        self.hoverRadius = hoverRadius
        self.baseY = baseY
        self.hoverY = hoverY
    }

    func body(content: Content) -> some View {
        content
            .shadow(
                color: Color.black.opacity(isHovered ? 0.15 : 0.08),
                radius: isHovered ? hoverRadius : baseRadius,
                y: isHovered ? hoverY : baseY
            )
            .scaleEffect(isHovered && !reduceMotion ? 1.01 : 1.0)
            .onHover { hovering in
                if reduceMotion {
                    isHovered = hovering
                } else {
                    withAnimation(VaizorAnimations.subtleSpring) {
                        isHovered = hovering
                    }
                }
            }
    }
}

extension View {
    /// Adds premium hover lift effect with shadow increase
    func hoverLift(baseRadius: CGFloat = 2, hoverRadius: CGFloat = 8) -> some View {
        modifier(HoverLiftModifier(baseRadius: baseRadius, hoverRadius: hoverRadius))
    }
}

// MARK: - Panel Transition Modifier

/// Smooth slide + fade transition for panels
struct PanelTransition: ViewModifier {
    let edge: Edge

    func body(content: Content) -> some View {
        content
            .transition(
                .asymmetric(
                    insertion: .move(edge: edge).combined(with: .opacity),
                    removal: .move(edge: edge).combined(with: .opacity)
                )
            )
    }
}

extension View {
    /// Applies premium panel transition
    func panelTransition(from edge: Edge = .trailing) -> some View {
        modifier(PanelTransition(edge: edge))
    }
}

// MARK: - Content Crossfade Modifier

/// Smooth crossfade for skeleton -> content transitions
struct ContentCrossfadeModifier: ViewModifier {
    let isLoading: Bool

    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 1 : contentOpacity)
            .offset(y: reduceMotion ? 0 : contentOffset)
            .onChange(of: isLoading) { _, newValue in
                if !newValue {
                    // Content is now ready, animate in
                    withAnimation(VaizorAnimations.contentCrossfade) {
                        contentOpacity = 1
                        contentOffset = 0
                    }
                } else {
                    // Reset for next load
                    contentOpacity = 0
                    contentOffset = 8
                }
            }
            .onAppear {
                if !isLoading {
                    if reduceMotion {
                        contentOpacity = 1
                        contentOffset = 0
                    } else {
                        withAnimation(VaizorAnimations.contentCrossfade) {
                            contentOpacity = 1
                            contentOffset = 0
                        }
                    }
                }
            }
    }
}

extension View {
    /// Applies smooth crossfade from loading to content state
    func contentCrossfade(isLoading: Bool) -> some View {
        modifier(ContentCrossfadeModifier(isLoading: isLoading))
    }
}

// MARK: - Glow Pulse Modifier

/// Subtle pulsing glow effect
struct GlowPulseModifier: ViewModifier {
    let color: Color
    let intensity: CGFloat

    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(isPulsing && !reduceMotion ? intensity : intensity * 0.3),
                radius: isPulsing && !reduceMotion ? 12 : 4
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    /// Adds subtle pulsing glow effect
    func glowPulse(color: Color = ThemeColors.accent, intensity: CGFloat = 0.5) -> some View {
        modifier(GlowPulseModifier(color: color, intensity: intensity))
    }
}

// MARK: - Border Glow Modifier

/// Subtle border highlight that glows on hover
struct BorderGlowModifier: ViewModifier {
    let color: Color
    let cornerRadius: CGFloat

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        color.opacity(isHovered ? 0.5 : 0),
                        lineWidth: isHovered ? 1.5 : 1
                    )
                    .shadow(
                        color: color.opacity(isHovered && !reduceMotion ? 0.3 : 0),
                        radius: 4
                    )
            )
            .onHover { hovering in
                if reduceMotion {
                    isHovered = hovering
                } else {
                    withAnimation(VaizorAnimations.colorTransition) {
                        isHovered = hovering
                    }
                }
            }
    }
}

extension View {
    /// Adds subtle border glow on hover
    func borderGlow(color: Color = ThemeColors.accent, cornerRadius: CGFloat = 12) -> some View {
        modifier(BorderGlowModifier(color: color, cornerRadius: cornerRadius))
    }
}

// MARK: - New Messages Indicator Modifier

/// Smooth slide-up animation for "new messages" indicator
struct NewMessagesIndicatorModifier: ViewModifier {
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: isVisible ? 0 : 50)
            .opacity(isVisible ? 1 : 0)
            .animation(reduceMotion ? .none : VaizorAnimations.quickBounce, value: isVisible)
    }
}

extension View {
    /// Applies new messages indicator animation
    func newMessagesIndicator(isVisible: Bool) -> some View {
        modifier(NewMessagesIndicatorModifier(isVisible: isVisible))
    }
}

// MARK: - Typing Dot Animation

/// Individual animated typing dot
struct TypingDot: View {
    let index: Int
    let color: Color

    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.0 : 0.5)
            .offset(y: isAnimating ? -4 : 2)
            .opacity(isAnimating ? 1.0 : 0.4)
            .shadow(color: color.opacity(isAnimating ? 0.6 : 0.2), radius: isAnimating ? 4 : 1)
            .onAppear {
                guard !reduceMotion else {
                    isAnimating = true
                    return
                }

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

// MARK: - Premium Typing Indicator

/// Enhanced typing indicator with staggered bounce animation and glow
struct PremiumTypingIndicator: View {
    let color: Color

    @State private var glowOpacity: Double = 0.3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(color: Color = ThemeColors.accent) {
        self.color = color
    }

    var body: some View {
        ZStack {
            // Subtle glow background
            if !reduceMotion {
                Capsule()
                    .fill(color.opacity(glowOpacity * 0.3))
                    .blur(radius: 8)
                    .frame(width: 50, height: 24)
            }

            // Dots container
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    TypingDot(index: index, color: color)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(ThemeColors.surface)
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(reduceMotion ? 0.2 : glowOpacity * 0.5), lineWidth: 1)
                    )
            )
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                glowOpacity = 0.6
            }
        }
    }
}

// MARK: - Smooth Scroll Button Style

/// Animated scroll button that appears/disappears smoothly
struct SmoothScrollButtonModifier: ViewModifier {
    let shouldShow: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(shouldShow ? 1 : 0.8)
            .opacity(shouldShow ? 1 : 0)
            .animation(reduceMotion ? .none : VaizorAnimations.quickBounce, value: shouldShow)
    }
}

extension View {
    /// Applies smooth scroll button appearance animation
    func smoothScrollButton(shouldShow: Bool) -> some View {
        modifier(SmoothScrollButtonModifier(shouldShow: shouldShow))
    }
}

// MARK: - Icon Button Modifier

/// Premium icon button with hover and press states
struct PremiumIconButtonModifier: ViewModifier {
    let isActive: Bool
    let activeColor: Color

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isActive ? activeColor : (isHovered ? .primary : .secondary))
            .scaleEffect(isPressed && !reduceMotion ? 0.92 : 1.0)
            .background(
                Circle()
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                    .scaleEffect(isHovered ? 1.2 : 1.0)
            )
            .onHover { hovering in
                withAnimation(VaizorAnimations.colorTransition) {
                    isHovered = hovering
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            withAnimation(VaizorAnimations.buttonPress) {
                                isPressed = true
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(VaizorAnimations.buttonPress) {
                            isPressed = false
                        }
                    }
            )
    }
}

extension View {
    /// Applies premium icon button styling
    func premiumIconButton(isActive: Bool = false, activeColor: Color = ThemeColors.accent) -> some View {
        modifier(PremiumIconButtonModifier(isActive: isActive, activeColor: activeColor))
    }
}

// MARK: - Card Hover Modifier

/// Adds premium hover effect to cards with lift and border glow
struct CardHoverModifier: ViewModifier {
    let cornerRadius: CGFloat

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .shadow(
                color: Color.black.opacity(isHovered ? 0.12 : 0.06),
                radius: isHovered ? 8 : 3,
                y: isHovered ? 4 : 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        ThemeColors.accent.opacity(isHovered ? 0.3 : 0),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovered && !reduceMotion ? 1.005 : 1.0)
            .onHover { hovering in
                withAnimation(VaizorAnimations.colorTransition) {
                    isHovered = hovering
                }
            }
    }
}

extension View {
    /// Applies premium card hover effect
    func cardHover(cornerRadius: CGFloat = VaizorSpacing.radiusLg) -> some View {
        modifier(CardHoverModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Sheet Transition Modifier

/// Smooth sheet presentation animation
struct SheetTransitionModifier: ViewModifier {
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(hasAppeared || reduceMotion ? 1.0 : 0.95)
            .opacity(hasAppeared || reduceMotion ? 1.0 : 0)
            .onAppear {
                guard !reduceMotion else {
                    hasAppeared = true
                    return
                }
                withAnimation(VaizorAnimations.panelSlide) {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    /// Applies smooth sheet appearance animation
    func sheetTransition() -> some View {
        modifier(SheetTransitionModifier())
    }
}

// MARK: - Send Button Animation

/// Animated send button with press and streaming states
struct SendButtonStyle: ButtonStyle {
    let isStreaming: Bool
    let isEmpty: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1.0)
            .animation(VaizorAnimations.buttonPress, value: configuration.isPressed)
    }
}

// MARK: - Input Focus Animation

/// Subtle animation for input field focus states
struct InputFocusModifier: ViewModifier {
    let isFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .animation(VaizorAnimations.colorTransition, value: isFocused)
    }
}

extension View {
    /// Applies input focus animation
    func inputFocusAnimation(_ isFocused: Bool) -> some View {
        modifier(InputFocusModifier(isFocused: isFocused))
    }
}

// MARK: - Pulse Animation

/// Subtle pulsing animation for attention-grabbing elements
struct PulseModifier: ViewModifier {
    let isActive: Bool

    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing && isActive && !reduceMotion ? 1.03 : 1.0)
            .opacity(isPulsing && isActive && !reduceMotion ? 0.9 : 1.0)
            .onAppear {
                guard !reduceMotion && isActive else { return }
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                if !newValue {
                    isPulsing = false
                } else if !reduceMotion {
                    withAnimation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true)
                    ) {
                        isPulsing = true
                    }
                }
            }
    }
}

extension View {
    /// Applies subtle pulse animation when active
    func pulse(when active: Bool) -> some View {
        modifier(PulseModifier(isActive: active))
    }
}
