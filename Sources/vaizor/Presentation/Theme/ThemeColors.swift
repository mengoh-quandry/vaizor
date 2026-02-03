import SwiftUI

// MARK: - macOS Tahoe Design System
// Following Apple Human Interface Guidelines for macOS 26+
// Emphasizes: Liquid glass effects, continuous corners, refined materials, semantic colors

// MARK: - Provider Colors (AI Model Providers)

/// Standardized colors for AI provider branding
enum ProviderColors {
    static let claude = Color(hex: "d4a017")      // Amber/Gold
    static let anthropic = Color(hex: "d4a017")   // Same as Claude
    static let openai = Color(hex: "10a37f")      // Green
    static let gemini = Color(hex: "5a9bd5")      // Blue
    static let ollama = Color(hex: "9c7bea")      // Purple

    /// Get color for a provider by name
    static func color(for provider: String) -> Color {
        switch provider.lowercased() {
        case "claude", "anthropic":
            return claude
        case "openai", "gpt", "chatgpt":
            return openai
        case "gemini", "google":
            return gemini
        case "ollama", "local":
            return ollama
        default:
            return Color.gray
        }
    }
}

// MARK: - Code Syntax Colors

/// Standardized colors for code syntax highlighting
enum CodeSyntaxColors {
    static let command = Color(hex: "61afef")     // Blue - commands/functions
    static let string = Color(hex: "98c379")      // Green - string literals
    static let variable = Color(hex: "e06c75")    // Red - variables
    static let comment = Color(hex: "7f848e")     // Gray - comments
    static let keyword = Color(hex: "c678dd")     // Purple - keywords
    static let flag = Color(hex: "d19a66")        // Orange - flags/options
    static let `operator` = Color(hex: "56b6c2")  // Cyan - operators
    static let number = Color(hex: "d19a66")      // Orange - numbers
    static let type = Color(hex: "e5c07b")        // Yellow - types
    static let property = Color(hex: "e06c75")    // Red - properties
    static let constant = Color(hex: "56b6c2")    // Cyan - constants
}

// MARK: - Adaptive Theme Colors

/// Adaptive theme colors that respond to system color scheme
/// Provides comprehensive light and dark mode support following macOS Tahoe design language
struct AdaptiveColors {
    let colorScheme: ColorScheme

    // MARK: - Base Colors (System-aligned)

    var background: Color {
        colorScheme == .dark ? Color(hex: "161617") : Color(hex: "f5f5f7")
    }

    var backgroundSecondary: Color {
        colorScheme == .dark ? Color(hex: "1c1c1e") : Color(hex: "ffffff")
    }

    var surface: Color {
        colorScheme == .dark ? Color(hex: "2c2c2e") : Color(hex: "ffffff")
    }

    var surfaceHover: Color {
        colorScheme == .dark ? Color(hex: "3a3a3c") : Color(hex: "f2f2f7")
    }

    var surfacePressed: Color {
        colorScheme == .dark ? Color(hex: "48484a") : Color(hex: "e5e5ea")
    }

    var elevated: Color {
        colorScheme == .dark ? Color(hex: "2c2c2e") : Color(hex: "ffffff")
    }

    var border: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
    }

    var borderSubtle: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    // MARK: - Text Colors (Semantic)

    var textPrimary: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color(hex: "1d1d1f")
    }

    var textSecondary: Color {
        colorScheme == .dark ? Color.white.opacity(0.60) : Color(hex: "86868b")
    }

    var textMuted: Color {
        colorScheme == .dark ? Color.white.opacity(0.40) : Color(hex: "aeaeb2")
    }

    var textPlaceholder: Color {
        colorScheme == .dark ? Color.white.opacity(0.30) : Color(hex: "c7c7cc")
    }

    var textDisabled: Color {
        colorScheme == .dark ? Color.white.opacity(0.20) : Color(hex: "d1d1d6")
    }

    // MARK: - Accent Colors (Teal/Emerald)

    var accent: Color {
        Color(hex: "30d158") // Apple's system green
    }

    var accentLight: Color {
        colorScheme == .dark ? Color(hex: "32d74b") : Color(hex: "28cd41")
    }

    var accentDark: Color {
        colorScheme == .dark ? Color(hex: "28a745") : Color(hex: "1e8e3e")
    }

    var accentBackground: Color {
        colorScheme == .dark ? accent.opacity(0.18) : accent.opacity(0.10)
    }

    // MARK: - Status Colors (System-aligned)

    var success: Color {
        Color(hex: "30d158") // System green
    }

    var successBackground: Color {
        colorScheme == .dark ? success.opacity(0.18) : success.opacity(0.10)
    }

    var warning: Color {
        Color(hex: "ffd60a") // System yellow
    }

    var warningBackground: Color {
        colorScheme == .dark ? warning.opacity(0.15) : warning.opacity(0.12)
    }

    var error: Color {
        Color(hex: "ff453a") // System red
    }

    var errorBackground: Color {
        colorScheme == .dark ? error.opacity(0.15) : error.opacity(0.10)
    }

    var info: Color {
        Color(hex: "0a84ff") // System blue
    }

    var infoBackground: Color {
        colorScheme == .dark ? info.opacity(0.15) : info.opacity(0.10)
    }

    // MARK: - Tool/Code Colors

    var toolAccent: Color {
        Color(hex: "ff9f0a") // System orange
    }

    var toolBackground: Color {
        colorScheme == .dark ? toolAccent.opacity(0.12) : toolAccent.opacity(0.08)
    }

    var codeAccent: Color {
        Color(hex: "bf5af2") // System purple
    }

    var codeBackground: Color {
        colorScheme == .dark ? codeAccent.opacity(0.12) : codeAccent.opacity(0.08)
    }

    // MARK: - Interactive States

    var hoverBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    var selectedBackground: Color {
        colorScheme == .dark ? accent.opacity(0.20) : accent.opacity(0.12)
    }

    // MARK: - Message Bubble Colors (Liquid Glass)

    var userBubble: Color {
        colorScheme == .dark ? accent.opacity(0.20) : accent.opacity(0.12)
    }

    var userBubbleBorder: Color {
        colorScheme == .dark ? accent.opacity(0.35) : accent.opacity(0.25)
    }

    var assistantBubble: Color {
        colorScheme == .dark ? Color(hex: "2c2c2e") : Color(hex: "ffffff")
    }

    var systemBubble: Color {
        colorScheme == .dark ? Color(hex: "3a3a3c") : Color(hex: "f2f2f7")
    }

    // MARK: - Input Field Colors

    var inputBackground: Color {
        colorScheme == .dark ? Color(hex: "1c1c1e") : Color(hex: "ffffff")
    }

    var inputBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
    }

    var inputFocusBorder: Color {
        accent
    }

    // MARK: - Sidebar Colors (Translucent)

    var sidebarBackground: Color {
        colorScheme == .dark ? Color(hex: "1c1c1e").opacity(0.85) : Color(hex: "f5f5f7").opacity(0.90)
    }

    var sidebarItemHover: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    var sidebarItemSelected: Color {
        colorScheme == .dark ? accent.opacity(0.22) : accent.opacity(0.14)
    }

    // MARK: - Code Block Colors

    var codeBlockBackground: Color {
        colorScheme == .dark ? Color(hex: "1c1c1e") : Color(hex: "f5f5f7")
    }

    var codeBlockHeaderBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    // MARK: - Skeleton/Loading Colors

    var skeletonBase: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    var skeletonHighlight: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.03)
    }

    // MARK: - Shadow Colors (Subtle for Tahoe)

    var shadowLight: Color {
        colorScheme == .dark ? Color.black.opacity(0.30) : Color.black.opacity(0.04)
    }

    var shadowMedium: Color {
        colorScheme == .dark ? Color.black.opacity(0.40) : Color.black.opacity(0.08)
    }

    var shadowStrong: Color {
        colorScheme == .dark ? Color.black.opacity(0.50) : Color.black.opacity(0.12)
    }

    // MARK: - Divider Colors

    var divider: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }

    // MARK: - Gradients (Subtle for Tahoe)

    var surfaceGradient: LinearGradient {
        colorScheme == .dark
        ? LinearGradient(colors: [Color(hex: "1c1c1e"), Color(hex: "161617")], startPoint: .top, endPoint: .bottom)
        : LinearGradient(colors: [Color(hex: "ffffff"), Color(hex: "f5f5f7")], startPoint: .top, endPoint: .bottom)
    }

    var cardGradient: LinearGradient {
        colorScheme == .dark
        ? LinearGradient(colors: [Color(hex: "2c2c2e"), Color(hex: "28282a")], startPoint: .top, endPoint: .bottom)
        : LinearGradient(colors: [Color(hex: "ffffff"), Color(hex: "fafafa")], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Glass Effects (New for Tahoe)

    var glassBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.70)
    }

    var glassBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.50)
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

// MARK: - Shadow Elevation System

/// Native macOS shadow elevation levels
enum ShadowElevation {
    case none
    case subtle     // Buttons, small elements
    case medium     // Cards, dropdowns
    case high       // Floating panels, modals

    /// Layered shadow configuration for native macOS feel
    struct ShadowConfig {
        let tightRadius: CGFloat
        let tightY: CGFloat
        let tightOpacity: Double
        let diffuseRadius: CGFloat
        let diffuseY: CGFloat
        let diffuseOpacity: Double
    }

    func config(for colorScheme: ColorScheme) -> ShadowConfig {
        let isDark = colorScheme == .dark
        switch self {
        case .none:
            return ShadowConfig(tightRadius: 0, tightY: 0, tightOpacity: 0,
                              diffuseRadius: 0, diffuseY: 0, diffuseOpacity: 0)
        case .subtle:
            return ShadowConfig(
                tightRadius: isDark ? 1 : 2,
                tightY: isDark ? 1 : 1,
                tightOpacity: isDark ? 0.25 : 0.08,
                diffuseRadius: isDark ? 3 : 4,
                diffuseY: isDark ? 2 : 2,
                diffuseOpacity: isDark ? 0.15 : 0.04
            )
        case .medium:
            return ShadowConfig(
                tightRadius: isDark ? 2 : 3,
                tightY: isDark ? 1 : 2,
                tightOpacity: isDark ? 0.30 : 0.10,
                diffuseRadius: isDark ? 8 : 12,
                diffuseY: isDark ? 4 : 6,
                diffuseOpacity: isDark ? 0.20 : 0.06
            )
        case .high:
            return ShadowConfig(
                tightRadius: isDark ? 3 : 4,
                tightY: isDark ? 2 : 3,
                tightOpacity: isDark ? 0.35 : 0.12,
                diffuseRadius: isDark ? 16 : 24,
                diffuseY: isDark ? 8 : 12,
                diffuseOpacity: isDark ? 0.25 : 0.10
            )
        }
    }
}

/// View modifier for native layered shadows
struct NativeShadowModifier: ViewModifier {
    let elevation: ShadowElevation
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let config = elevation.config(for: colorScheme)
        content
            // Tight shadow (close to element)
            .shadow(
                color: Color.black.opacity(config.tightOpacity),
                radius: config.tightRadius,
                x: 0,
                y: config.tightY
            )
            // Diffuse shadow (ambient)
            .shadow(
                color: Color.black.opacity(config.diffuseOpacity),
                radius: config.diffuseRadius,
                x: 0,
                y: config.diffuseY
            )
    }
}

extension View {
    /// Apply native macOS layered shadow
    func nativeShadow(elevation: ShadowElevation) -> some View {
        modifier(NativeShadowModifier(elevation: elevation))
    }
}

// MARK: - Native Panel Modifier

/// Panel styles following macOS material guidelines
struct NativePanelModifier: ViewModifier {
    enum PanelStyle {
        case floating   // .regularMaterial, high shadow (popovers, modals)
        case dropdown   // .thinMaterial, medium shadow (menus, dropdowns)
        case sidebar    // .thinMaterial, no shadow (sidebars)
        case toolbar    // .ultraThinMaterial, no shadow (toolbars)
        case card       // Solid surface, subtle shadow (cards)
    }

    let style: PanelStyle
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    func body(content: Content) -> some View {
        switch style {
        case .floating:
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(colors.border, lineWidth: 0.5)
                )
                .nativeShadow(elevation: .high)

        case .dropdown:
            content
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(colors.border, lineWidth: 0.5)
                )
                .nativeShadow(elevation: .medium)

        case .sidebar:
            content
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

        case .toolbar:
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

        case .card:
            content
                .background(colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(colors.border, lineWidth: 1)
                )
                .nativeShadow(elevation: .subtle)
        }
    }
}

extension View {
    /// Apply native macOS panel styling
    func nativePanel(_ style: NativePanelModifier.PanelStyle, cornerRadius: CGFloat = VaizorSpacing.radiusLg) -> some View {
        modifier(NativePanelModifier(style: style, cornerRadius: cornerRadius))
    }
}

// MARK: - Native Focus Ring Modifier

/// Focus ring following macOS accessibility guidelines
struct NativeFocusRingModifier: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat
    let isCircular: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    init(isFocused: Bool, cornerRadius: CGFloat = VaizorSpacing.radiusMd, isCircular: Bool = false) {
        self.isFocused = isFocused
        self.cornerRadius = cornerRadius
        self.isCircular = isCircular
    }

    func body(content: Content) -> some View {
        content
            .overlay(focusOverlay)
    }

    @ViewBuilder
    private var focusOverlay: some View {
        if isFocused {
            if isCircular {
                Circle()
                    .stroke(colors.accent, lineWidth: 2)
                    .padding(-4) // Offset outward from element
                    .shadow(color: colors.accent.opacity(0.4), radius: 4, x: 0, y: 0)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                    .stroke(colors.accent, lineWidth: 2)
                    .padding(-4)
                    .shadow(color: colors.accent.opacity(0.4), radius: 4, x: 0, y: 0)
            }
        }
    }
}

extension View {
    /// Apply native macOS focus ring
    func nativeFocusRing(isFocused: Bool, cornerRadius: CGFloat = VaizorSpacing.radiusMd) -> some View {
        modifier(NativeFocusRingModifier(isFocused: isFocused, cornerRadius: cornerRadius))
    }

    /// Apply circular focus ring (for icon buttons)
    func nativeCircularFocusRing(isFocused: Bool) -> some View {
        modifier(NativeFocusRingModifier(isFocused: isFocused, isCircular: true))
    }
}

// MARK: - Native Hover Modifier

/// Hover state modifier following macOS interaction patterns
struct NativeHoverModifier: ViewModifier {
    let cornerRadius: CGFloat
    let includeScale: Bool
    let isCircular: Bool

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    init(cornerRadius: CGFloat = VaizorSpacing.radiusSm, includeScale: Bool = false, isCircular: Bool = false) {
        self.cornerRadius = cornerRadius
        self.includeScale = includeScale
        self.isCircular = isCircular
    }

    func body(content: Content) -> some View {
        content
            .background(backgroundShape)
            .scaleEffect(scaleAmount)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if isCircular {
            Circle()
                .fill(isHovered ? colors.hoverBackground : Color.clear)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isHovered ? colors.hoverBackground : Color.clear)
        }
    }

    private var scaleAmount: CGFloat {
        guard includeScale, !reduceMotion else { return 1.0 }
        return isHovered ? 1.02 : 1.0
    }
}

extension View {
    /// Apply native hover background effect
    func nativeHover(cornerRadius: CGFloat = VaizorSpacing.radiusSm, includeScale: Bool = false) -> some View {
        modifier(NativeHoverModifier(cornerRadius: cornerRadius, includeScale: includeScale))
    }

    /// Apply circular hover effect (for icons)
    func nativeCircularHover(includeScale: Bool = false) -> some View {
        modifier(NativeHoverModifier(cornerRadius: 0, includeScale: includeScale, isCircular: true))
    }
}

// MARK: - Native Input Field Modifier

/// Input field styling following macOS text field guidelines
struct NativeInputFieldModifier: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat
    let hasError: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    init(isFocused: Bool, cornerRadius: CGFloat = VaizorSpacing.radiusMd, hasError: Bool = false) {
        self.isFocused = isFocused
        self.cornerRadius = cornerRadius
        self.hasError = hasError
    }

    func body(content: Content) -> some View {
        content
            .padding(VaizorSpacing.sm)
            .background(colors.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(borderOverlay)
            .shadow(
                color: focusShadowColor,
                radius: isFocused ? 4 : 0,
                x: 0,
                y: 0
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    @ViewBuilder
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(borderColor, lineWidth: isFocused || hasError ? 2 : 1)
    }

    private var borderColor: Color {
        if hasError {
            return colors.error
        }
        if isFocused {
            return colors.accent
        }
        return colors.inputBorder
    }

    private var focusShadowColor: Color {
        if hasError {
            return colors.error.opacity(0.25)
        }
        if isFocused {
            return colors.accent.opacity(0.25)
        }
        return .clear
    }
}

extension View {
    /// Apply native macOS input field styling
    func nativeInputField(isFocused: Bool, cornerRadius: CGFloat = VaizorSpacing.radiusMd, hasError: Bool = false) -> some View {
        modifier(NativeInputFieldModifier(isFocused: isFocused, cornerRadius: cornerRadius, hasError: hasError))
    }
}

// MARK: - Native List Row Modifier

/// List row styling for native selection/hover states
struct NativeListRowModifier: ViewModifier {
    let isSelected: Bool
    let cornerRadius: CGFloat

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, VaizorSpacing.sm)
            .padding(.vertical, VaizorSpacing.xs)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isHovered)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isSelected)
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private var backgroundColor: Color {
        if isSelected {
            return colors.selectedBackground
        }
        if isHovered {
            return colors.hoverBackground
        }
        return .clear
    }
}

extension View {
    /// Apply native list row styling
    func nativeListRow(isSelected: Bool = false, cornerRadius: CGFloat = VaizorSpacing.radiusSm) -> some View {
        modifier(NativeListRowModifier(isSelected: isSelected, cornerRadius: cornerRadius))
    }
}
