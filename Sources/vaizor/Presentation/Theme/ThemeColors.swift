import SwiftUI

// MARK: - Adaptive Theme Colors

/// Adaptive theme colors that respond to system color scheme
/// Provides comprehensive light and dark mode support for Vaizor
struct AdaptiveColors {
    let colorScheme: ColorScheme

    // MARK: - Base Colors

    var background: Color {
        colorScheme == .dark ? Color(hex: "1c1d1f") : Color(hex: "ffffff")
    }

    var backgroundSecondary: Color {
        colorScheme == .dark ? Color(hex: "171819") : Color(hex: "fafafa")
    }

    var surface: Color {
        colorScheme == .dark ? Color(hex: "232426") : Color(hex: "f5f5f7")
    }

    var surfaceHover: Color {
        colorScheme == .dark ? Color(hex: "2a2b2d") : Color(hex: "ebebed")
    }

    var surfacePressed: Color {
        colorScheme == .dark ? Color(hex: "303133") : Color(hex: "e0e0e2")
    }

    var elevated: Color {
        colorScheme == .dark ? Color(hex: "2a2b2d") : Color(hex: "ffffff")
    }

    var border: Color {
        colorScheme == .dark ? Color(hex: "2d2e30") : Color(hex: "e5e5e5")
    }

    var borderSubtle: Color {
        colorScheme == .dark ? Color(hex: "252628") : Color(hex: "eeeeee")
    }

    // MARK: - Text Colors

    var textPrimary: Color {
        colorScheme == .dark ? Color.white : Color(hex: "1d1d1f")
    }

    var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "808080") : Color(hex: "6e6e73")
    }

    var textMuted: Color {
        colorScheme == .dark ? Color(hex: "606060") : Color(hex: "8e8e93")
    }

    var textPlaceholder: Color {
        colorScheme == .dark ? Color(hex: "505050") : Color(hex: "aeaeb2")
    }

    var textDisabled: Color {
        colorScheme == .dark ? Color(hex: "404040") : Color(hex: "c7c7cc")
    }

    // MARK: - Accent Colors

    var accent: Color {
        colorScheme == .dark ? Color(hex: "00976d") : Color(hex: "00875f")
    }

    var accentLight: Color {
        colorScheme == .dark ? Color(hex: "00b386") : Color(hex: "00a878")
    }

    var accentDark: Color {
        colorScheme == .dark ? Color(hex: "007a58") : Color(hex: "006b4d")
    }

    var accentBackground: Color {
        colorScheme == .dark ? Color(hex: "00976d").opacity(0.15) : Color(hex: "00976d").opacity(0.08)
    }

    // MARK: - Status Colors

    var success: Color {
        colorScheme == .dark ? Color(hex: "00976d") : Color(hex: "00875f")
    }

    var successBackground: Color {
        colorScheme == .dark ? Color(hex: "00976d").opacity(0.15) : Color(hex: "00976d").opacity(0.08)
    }

    var warning: Color {
        colorScheme == .dark ? Color(hex: "d4a017") : Color(hex: "c59000")
    }

    var warningBackground: Color {
        colorScheme == .dark ? Color(hex: "d4a017").opacity(0.12) : Color(hex: "d4a017").opacity(0.08)
    }

    var error: Color {
        colorScheme == .dark ? Color(hex: "c75450") : Color(hex: "d93025")
    }

    var errorBackground: Color {
        colorScheme == .dark ? Color(hex: "c75450").opacity(0.12) : Color(hex: "c75450").opacity(0.06)
    }

    var info: Color {
        colorScheme == .dark ? Color(hex: "5a9bd5") : Color(hex: "0066cc")
    }

    var infoBackground: Color {
        colorScheme == .dark ? Color(hex: "5a9bd5").opacity(0.12) : Color(hex: "5a9bd5").opacity(0.08)
    }

    // MARK: - Tool/Code Colors

    var toolAccent: Color {
        colorScheme == .dark ? Color(hex: "d4a017") : Color(hex: "b58900")
    }

    var toolBackground: Color {
        colorScheme == .dark ? Color(hex: "d4a017").opacity(0.08) : Color(hex: "d4a017").opacity(0.06)
    }

    var codeAccent: Color {
        colorScheme == .dark ? Color(hex: "9c7bea") : Color(hex: "8b5cf6")
    }

    var codeBackground: Color {
        colorScheme == .dark ? Color(hex: "9c7bea").opacity(0.1) : Color(hex: "9c7bea").opacity(0.06)
    }

    // MARK: - Interactive States

    var hoverBackground: Color {
        colorScheme == .dark ? Color(hex: "2d2e30") : Color(hex: "f0f0f2")
    }

    var selectedBackground: Color {
        colorScheme == .dark ? Color(hex: "00976d").opacity(0.2) : Color(hex: "00976d").opacity(0.12)
    }

    // MARK: - Message Bubble Colors

    var userBubble: Color {
        colorScheme == .dark ? Color(hex: "00976d").opacity(0.15) : Color(hex: "00976d").opacity(0.08)
    }

    var userBubbleBorder: Color {
        colorScheme == .dark ? Color(hex: "00976d").opacity(0.3) : Color(hex: "00976d").opacity(0.2)
    }

    var assistantBubble: Color {
        colorScheme == .dark ? Color(hex: "232426") : Color(hex: "ffffff")
    }

    var systemBubble: Color {
        colorScheme == .dark ? Color(hex: "2d2e30") : Color(hex: "f0f0f2")
    }

    // MARK: - Input Field Colors

    var inputBackground: Color {
        colorScheme == .dark ? Color(hex: "252628") : Color(hex: "ffffff")
    }

    var inputBorder: Color {
        colorScheme == .dark ? Color(hex: "3a3b3d") : Color(hex: "d1d1d6")
    }

    var inputFocusBorder: Color {
        accent
    }

    // MARK: - Sidebar Colors

    var sidebarBackground: Color {
        colorScheme == .dark ? Color(hex: "1c1d1f") : Color(hex: "f5f5f7")
    }

    var sidebarItemHover: Color {
        colorScheme == .dark ? Color(hex: "2a2b2d") : Color(hex: "e8e8ea")
    }

    var sidebarItemSelected: Color {
        colorScheme == .dark ? Color(hex: "00976d").opacity(0.2) : Color(hex: "00976d").opacity(0.12)
    }

    // MARK: - Code Block Colors

    var codeBlockBackground: Color {
        colorScheme == .dark ? Color(hex: "1a1b1d") : Color(hex: "f5f5f7")
    }

    var codeBlockHeaderBackground: Color {
        colorScheme == .dark ? Color(hex: "2d2e30").opacity(0.5) : Color(hex: "eaeaec")
    }

    // MARK: - Skeleton/Loading Colors

    var skeletonBase: Color {
        colorScheme == .dark ? Color(hex: "2d2e30") : Color(hex: "e5e5e7")
    }

    var skeletonHighlight: Color {
        colorScheme == .dark ? Color(hex: "3a3b3d") : Color(hex: "f5f5f7")
    }

    // MARK: - Shadow Colors

    var shadowLight: Color {
        colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.05)
    }

    var shadowMedium: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
    }

    var shadowStrong: Color {
        colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.15)
    }

    // MARK: - Divider Colors

    var divider: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }

    // MARK: - Gradients

    var surfaceGradient: LinearGradient {
        colorScheme == .dark
        ? LinearGradient(colors: [Color(hex: "1e1f21"), Color(hex: "1a1b1d")], startPoint: .top, endPoint: .bottom)
        : LinearGradient(colors: [Color(hex: "ffffff"), Color(hex: "fafafa")], startPoint: .top, endPoint: .bottom)
    }

    var cardGradient: LinearGradient {
        colorScheme == .dark
        ? LinearGradient(colors: [Color(hex: "282a2c"), Color(hex: "232426")], startPoint: .top, endPoint: .bottom)
        : LinearGradient(colors: [Color(hex: "ffffff"), Color(hex: "f8f8fa")], startPoint: .top, endPoint: .bottom)
    }
}

/// Environment key for adaptive colors
private struct AdaptiveColorsKey: EnvironmentKey {
    static let defaultValue = AdaptiveColors(colorScheme: .dark)
}

extension EnvironmentValues {
    var adaptiveColors: AdaptiveColors {
        get { self[AdaptiveColorsKey.self] }
        set { self[AdaptiveColorsKey.self] = newValue }
    }
}

/// View modifier to inject adaptive colors based on color scheme
struct AdaptiveColorsModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.adaptiveColors, AdaptiveColors(colorScheme: colorScheme))
    }
}

extension View {
    /// Apply adaptive theming to a view hierarchy
    func withAdaptiveColors() -> some View {
        modifier(AdaptiveColorsModifier())
    }
}

// MARK: - Legacy Static API (backwards compatibility)

/// Centralized theme colors - static variants for legacy code
/// These work alongside AdaptiveColors for gradual migration
enum ThemeColors {
    // MARK: - Base Colors (Dark Mode defaults)
    static let darkBase = Color(hex: "1c1d1f")
    static let darkSurface = Color(hex: "232426")
    static let darkBorder = Color(hex: "2d2e30")
    static let darkElevated = Color(hex: "2a2b2d")

    // MARK: - Light Mode Base Colors
    static let lightBase = Color(hex: "ffffff")
    static let lightSurface = Color(hex: "f5f5f7")
    static let lightBorder = Color(hex: "e5e5e5")
    static let lightElevated = Color(hex: "ffffff")

    // MARK: - Text Colors (Dark Mode)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "808080")
    static let textMuted = Color(hex: "606060")
    static let textPlaceholder = Color(hex: "606060").opacity(0.7)

    // MARK: - Light Mode Text Colors
    static let textPrimaryLight = Color(hex: "1d1d1f")
    static let textSecondaryLight = Color(hex: "6e6e73")
    static let textMutedLight = Color(hex: "8e8e93")

    // MARK: - Accent Colors
    static let accent = Color(hex: "00976d")
    static let accentLight = Color(hex: "00b386")
    static let accentDark = Color(hex: "007a58")

    // MARK: - Status Colors (theme-consistent)
    static let success = Color(hex: "00976d")
    static let successBackground = Color(hex: "00976d").opacity(0.15)

    static let warning = Color(hex: "d4a017")
    static let warningBackground = Color(hex: "d4a017").opacity(0.12)

    static let error = Color(hex: "c75450")
    static let errorBackground = Color(hex: "c75450").opacity(0.12)

    static let info = Color(hex: "5a9bd5")
    static let infoBackground = Color(hex: "5a9bd5").opacity(0.12)

    // MARK: - Tool/Code Colors
    static let toolAccent = Color(hex: "d4a017")
    static let toolBackground = Color(hex: "d4a017").opacity(0.08)

    static let codeAccent = Color(hex: "9c7bea")
    static let codeBackground = Color(hex: "9c7bea").opacity(0.1)

    // MARK: - Interactive States
    static let hoverBackground = Color(hex: "2d2e30")
    static let selectedBackground = Color(hex: "00976d").opacity(0.2)
    static let disabledText = Color(hex: "505050")

    // MARK: - Message Bubble Colors
    static let userBubble = Color(hex: "00976d").opacity(0.15)
    static let userBubbleBorder = Color(hex: "00976d").opacity(0.3)
    static let assistantBubble = Color(hex: "232426")
    static let systemBubble = Color(hex: "2d2e30")

    // MARK: - Surface Colors
    static let surface = Color(hex: "252628")
    static let surfaceHover = Color(hex: "2a2b2d")

    // MARK: - Skeleton/Loading Colors
    static let skeletonBase = Color(hex: "2d2e30")
    static let skeletonHighlight = Color(hex: "3a3b3d")

    // MARK: - Gradients
    static let surfaceGradient = LinearGradient(
        colors: [Color(hex: "1e1f21"), Color(hex: "1a1b1d")],
        startPoint: .top, endPoint: .bottom
    )
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "00a67d"), Color(hex: "008f6b")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let cardGradient = LinearGradient(
        colors: [Color(hex: "282a2c"), Color(hex: "232426")],
        startPoint: .top, endPoint: .bottom
    )
    static let headerGradient = LinearGradient(
        colors: [Color(hex: "232426"), Color(hex: "1e1f21")],
        startPoint: .top, endPoint: .bottom
    )
    static let sidebarGradient = LinearGradient(
        colors: [Color(hex: "1a1b1d"), Color(hex: "18191b")],
        startPoint: .top, endPoint: .bottom
    )

    // MARK: - Glows
    static let accentGlow = Color(hex: "00976d").opacity(0.3)
    static let subtleGlow = Color.white.opacity(0.05)
    static let focusGlow = Color(hex: "00976d").opacity(0.4)
    static let selectedGlow = Color(hex: "00976d").opacity(0.25)

    // MARK: - Shadows
    static let shadowLight = Color.black.opacity(0.1)
    static let shadowMedium = Color.black.opacity(0.2)
    static let shadowHeavy = Color.black.opacity(0.4)
    static let innerShadow = Color.black.opacity(0.15)
    static let dropShadow = Color.black.opacity(0.25)

    // MARK: - Depth Layers
    static let elevated = Color(hex: "262729")
    static let recessed = Color(hex: "18191b")
    static let floatingCard = Color(hex: "2a2c2e")
    static let sunkenInput = Color(hex: "1a1b1d")

    // MARK: - Dividers & Borders
    static let dividerSolid = Color(hex: "2d2e30")
    static let dividerSubtle = Color(hex: "2d2e30").opacity(0.5)
    static let borderSubtle = Color.white.opacity(0.06)
    static let borderHighlight = Color.white.opacity(0.1)

    // MARK: - Adaptive Color Functions

    /// Get background color for current color scheme
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkBase : lightBase
    }

    /// Get surface color for current color scheme
    static func surface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkSurface : lightSurface
    }

    /// Get border color for current color scheme
    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkBorder : lightBorder
    }

    /// Get elevated color for current color scheme
    static func elevated(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkElevated : lightElevated
    }

    /// Get primary text color for current color scheme
    static func textPrimary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textPrimary : textPrimaryLight
    }

    /// Get secondary text color for current color scheme
    static func textSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textSecondary : textSecondaryLight
    }

    /// Get muted text color for current color scheme
    static func textMuted(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? textMuted : textMutedLight
    }

    /// Get hover background for current color scheme
    static func hoverBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? hoverBackground : Color(hex: "f0f0f2")
    }

    /// Get user bubble color for current color scheme
    static func userBubble(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? userBubble : Color(hex: "00976d").opacity(0.08)
    }

    /// Get assistant bubble color for current color scheme
    static func assistantBubble(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? assistantBubble : lightElevated
    }

    /// Get input background for current color scheme
    static func inputBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "252628") : Color(hex: "ffffff")
    }

    /// Get input border for current color scheme
    static func inputBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "3a3b3d") : Color(hex: "d1d1d6")
    }

    /// Get code block background for current color scheme
    static func codeBlockBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "1a1b1d") : Color(hex: "f5f5f7")
    }

    /// Get shadow color for current color scheme
    static func shadow(for colorScheme: ColorScheme, intensity: ShadowIntensity = .medium) -> Color {
        switch intensity {
        case .light:
            return colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.05)
        case .medium:
            return colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
        case .strong:
            return colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.15)
        }
    }

    enum ShadowIntensity {
        case light, medium, strong
    }

    // MARK: - Gradient Dividers
    static func gradientDivider(horizontal: Bool = true) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.clear,
                Color(hex: "2d2e30").opacity(0.6),
                Color(hex: "2d2e30").opacity(0.8),
                Color(hex: "2d2e30").opacity(0.6),
                Color.clear
            ],
            startPoint: horizontal ? .leading : .top,
            endPoint: horizontal ? .trailing : .bottom
        )
    }
}

// MARK: - Themed Components

/// A themed surface container that adapts to light/dark mode
struct ThemedSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let padding: CGFloat
    let showBorder: Bool
    let shadowStyle: ShadowStyle
    @ViewBuilder let content: () -> Content

    enum ShadowStyle {
        case none
        case subtle
        case medium
        case elevated
    }

    init(
        cornerRadius: CGFloat = 12,
        padding: CGFloat = 16,
        showBorder: Bool = false,
        shadow: ShadowStyle = .none,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.showBorder = showBorder
        self.shadowStyle = shadow
        self.content = content
    }

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    private var shadowColor: Color {
        switch shadowStyle {
        case .none: return .clear
        case .subtle: return colors.shadowLight
        case .medium: return colors.shadowMedium
        case .elevated: return colors.shadowStrong
        }
    }

    private var shadowRadius: CGFloat {
        switch shadowStyle {
        case .none: return 0
        case .subtle: return colorScheme == .light ? 6 : 4
        case .medium: return colorScheme == .light ? 12 : 8
        case .elevated: return colorScheme == .light ? 20 : 16
        }
    }

    var body: some View {
        content()
            .padding(padding)
            .background(colors.surface)
            .cornerRadius(cornerRadius)
            .overlay(
                showBorder ?
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(colors.border, lineWidth: 1)
                : nil
            )
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowStyle == .none ? 0 : (colorScheme == .light ? 3 : 2))
    }
}

/// A themed card with optional hover state and enhanced shadows in light mode
struct ThemedCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    let cornerRadius: CGFloat
    let padding: CGFloat
    let isInteractive: Bool
    @ViewBuilder let content: () -> Content

    init(
        cornerRadius: CGFloat = 12,
        padding: CGFloat = 16,
        isInteractive: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.isInteractive = isInteractive
        self.content = content
    }

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        content()
            .padding(padding)
            .background(isHovered && isInteractive ? colors.surfaceHover : colors.elevated)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(colors.border, lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .light ? colors.shadowMedium : colors.shadowLight,
                radius: colorScheme == .light ? (isHovered ? 12 : 8) : (isHovered ? 6 : 4),
                y: colorScheme == .light ? (isHovered ? 4 : 2) : (isHovered ? 2 : 1)
            )
            .onHover { hovering in
                if isInteractive {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                }
            }
    }
}

/// A themed input field container with focus state
struct ThemedInputField<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let isFocused: Bool
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        isFocused: Bool = false,
        cornerRadius: CGFloat = 10,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isFocused = isFocused
        self.cornerRadius = cornerRadius
        self.content = content
    }

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        content()
            .padding(12)
            .background(colors.inputBackground)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isFocused ? colors.accent : colors.inputBorder,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .shadow(
                color: isFocused && colorScheme == .light ? colors.accent.opacity(0.2) : .clear,
                radius: 4,
                y: 0
            )
    }
}

// MARK: - Button Styles

/// Primary button with gradient and shadow - adapts to color scheme
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let colors = AdaptiveColors(colorScheme: colorScheme)

        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isEnabled ? ThemeColors.accentGradient : LinearGradient(colors: [ThemeColors.disabledText], startPoint: .top, endPoint: .bottom))
            )
            .shadow(
                color: isEnabled ? colors.shadowMedium : .clear,
                radius: configuration.isPressed ? 2 : (colorScheme == .light ? 6 : 4),
                y: configuration.isPressed ? 1 : 2
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary button with border - adapts to color scheme
struct SecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let colors = AdaptiveColors(colorScheme: colorScheme)

        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(colors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isHovered ? colors.hoverBackground : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(colors.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

/// Ghost button with no border - adapts to color scheme
struct GhostButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let colors = AdaptiveColors(colorScheme: colorScheme)

        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isHovered ? colors.textPrimary : colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isHovered ? colors.hoverBackground : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Card View Modifiers

/// Polished card modifier with depth and hover effects - adapts to color scheme
struct PolishedCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let isSelected: Bool
    let cornerRadius: CGFloat
    @State private var isHovered = false

    init(isSelected: Bool = false, cornerRadius: CGFloat = 12) {
        self.isSelected = isSelected
        self.cornerRadius = cornerRadius
    }

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colors.cardGradient)
            )
            // Inner highlight at top (light source from above) - subtle in light mode
            .overlay(
                colorScheme == .dark ?
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(ThemeColors.borderHighlight, lineWidth: 0.5)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                : nil
            )
            // Border
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(colors.border, lineWidth: 1)
            )
            // Selected state glow
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isSelected ? colors.accent : Color.clear, lineWidth: 1.5)
                    .shadow(color: isSelected ? ThemeColors.accentGlow : .clear, radius: 6)
            )
            // Drop shadow - more prominent in light mode
            .shadow(
                color: colors.shadowLight,
                radius: colorScheme == .light ? (isHovered ? 12 : 8) : (isHovered ? 8 : 4),
                y: colorScheme == .light ? (isHovered ? 4 : 2) : (isHovered ? 4 : 2)
            )
            .offset(y: isHovered ? -2 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// Sunken input field modifier - adapts to color scheme
struct SunkenInputModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let isFocused: Bool
    let cornerRadius: CGFloat

    init(isFocused: Bool = false, cornerRadius: CGFloat = 10) {
        self.isFocused = isFocused
        self.cornerRadius = cornerRadius
    }

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colors.inputBackground)
            )
            // Inner shadow (recessed effect) - subtle in light mode
            .overlay(
                colorScheme == .dark ?
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(ThemeColors.innerShadow, lineWidth: 1)
                    .blur(radius: 1)
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius)
                    )
                : nil
            )
            // Border
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isFocused ? colors.accent : colors.inputBorder, lineWidth: isFocused ? 1.5 : 1)
            )
            // Focus glow - more visible in light mode
            .shadow(
                color: isFocused ? (colorScheme == .light ? colors.accent.opacity(0.25) : ThemeColors.focusGlow) : .clear,
                radius: colorScheme == .light ? 6 : 8,
                y: 0
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

/// Sidebar item with selection and hover states - adapts to color scheme
struct SidebarItemModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let isSelected: Bool
    @State private var isHovered = false

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            // Selection glow
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? colors.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .shadow(
                color: isSelected ? ThemeColors.selectedGlow : (isHovered ? colors.shadowLight : .clear),
                radius: isHovered ? 4 : 0,
                y: isHovered ? 2 : 0
            )
            .offset(y: isHovered && !isSelected ? -1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private var backgroundColor: Color {
        if isSelected {
            return colors.sidebarItemSelected
        } else if isHovered {
            return colors.sidebarItemHover
        }
        return Color.clear
    }
}

// MARK: - View Extensions

extension View {
    /// Apply polished card styling
    func polishedCard(isSelected: Bool = false, cornerRadius: CGFloat = 12) -> some View {
        modifier(PolishedCardModifier(isSelected: isSelected, cornerRadius: cornerRadius))
    }

    /// Apply sunken input field styling
    func sunkenInput(isFocused: Bool = false, cornerRadius: CGFloat = 10) -> some View {
        modifier(SunkenInputModifier(isFocused: isFocused, cornerRadius: cornerRadius))
    }

    /// Apply sidebar item styling
    func sidebarItem(isSelected: Bool = false) -> some View {
        modifier(SidebarItemModifier(isSelected: isSelected))
    }

    /// Apply gradient divider
    @ViewBuilder
    func gradientDivider(horizontal: Bool = true, padding: CGFloat = 16) -> some View {
        self
        Rectangle()
            .fill(ThemeColors.gradientDivider(horizontal: horizontal))
            .frame(height: horizontal ? 1 : nil)
            .frame(width: horizontal ? nil : 1)
            .padding(horizontal ? .horizontal : .vertical, padding)
    }
}

// Note: Color.init(hex:) extension is defined in VaizorApp.swift
